import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/chat_box.dart';


class StrangerListPage extends StatefulWidget {
  const StrangerListPage({super.key});

  static void open(BuildContext context) => showPage(
    context: context,
    builder: (context) => const StrangerListPage(),
  );

  @override
  State<StatefulWidget> createState() => _StrangerListState();
}

class _StrangerListState extends State<StrangerListPage> implements lnc.Observer {
  _StrangerListState() : _clerk = Amanuensis() {
    _adapter = _StrangerListAdapter(dataSource: _clerk);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kConversationUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
    super.dispose();
  }

  final Amanuensis _clerk;

  late final _StrangerListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kConversationUpdated) {
      ID? chat = userInfo?['ID'];
      Log.info('conversation updated: $chat');
      await _reload();
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      await _reload();
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      await _reload();
    }
  }

  Future<void> _reload() async {
    List<Conversation> chats = await _clerk.loadConversations();
    for (Conversation item in chats) {
      await item.reloadData();
    }
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  Future<void> _load() async {
    List<Conversation> chats = await _clerk.loadConversations();
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
    for (Conversation item in chats) {
      await item.reloadData();
    }
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'New Friends'.tr),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );
}

class _StrangerListAdapter with SectionAdapterMixin {
  _StrangerListAdapter({required Amanuensis dataSource}) : _dataSource = dataSource;

  final Amanuensis _dataSource;

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'Strangers::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(prompt,
            style: Styles.sectionFooterTextStyle,
          )),
        ],
      ),
    );
  }

  @override
  int numberOfItems(int section) => _dataSource.strangers.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Conversation> conversations = _dataSource.strangers;
    if (indexPath.item >= conversations.length) {
      Log.error('out of range: ${conversations.length}, $indexPath');
      return const Text('');
    }
    Conversation info = conversations[indexPath.item];
    Log.warning('show item: $info');
    return _ChatTableCell(info);
  }

}

/// TableCell for Conversations
class _ChatTableCell extends StatefulWidget {
  const _ChatTableCell(this.info);

  final Conversation info;

  @override
  State<StatefulWidget> createState() => _ChatTableCellState();

}

class _ChatTableCellState extends State<_ChatTableCell> implements lnc.Observer {
  _ChatTableCellState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kRemarkUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? did = userInfo?['ID'];
      assert(did != null, 'notification error: $notification');
      if (did == widget.info.identifier) {
        await _reload();
      } else {
        // TODO: check members for group chat?
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? cid = userInfo?['contact'];
      assert(cid != null, 'notification error: $notification');
      if (cid == widget.info.identifier) {
        Log.info('remark updated: $cid');
        await _reload();
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      Log.info('muted contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else {
      assert(false, 'notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: _leading(widget.info),
    title: widget.info.getNameLabel(true),
    subtitle: _lastMessage(widget.info.lastMessage),
    additionalInfo: _additional(context, widget.info, widget.info.lastMessageTime),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      Log.warning('tap: ${widget.info}');
      ChatBox.open(context, widget.info, null);
    },
    onLongPress: () {
      Log.warning('long press: ${widget.info}');
      Alert.confirm(context, 'Confirm Delete',
        previewEntity(widget.info, width: 128, height: 128),
        okAction: () => _removeConversation(context, widget.info.identifier),
      );
    },
  );

  void _removeConversation(BuildContext context, ID chat) {
    Log.warning('removing $chat');
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(chat).onError((error, stackTrace) {
      if (context.mounted) {
        Alert.show(context, 'Error', 'Failed to remove friend'.tr);
      }
      return false;
    });
  }

  Widget _leading(Conversation info) {
    if (info.isMuted) {
      return IconView.fromSpot(info.getImage(), info.unread);
    } else {
      return IconView.fromNumber(info.getImage(), info.unread);
    }
  }

  Widget? _lastMessage(String? last) {
    if (last == null) {
      return null;
    }
    return Text(last);
  }

  Widget _additional(BuildContext context, Conversation info, DateTime? time) => Row(
    children: [
      if (time != null)
      Text(TimeUtils.getTimeString(time)),
      if (info is ContactInfo)
      Container(
        // height: 24,
        margin: const EdgeInsets.only(left: 8),
        child: OutlinedButton(
          // style: ButtonStyle(
          //   backgroundColor: MaterialStateProperty.all<Color>(
          //       Styles.colors.importantButtonColor),
          // ),
          onPressed: () => Alert.confirm(context, 'Confirm Add',
            previewEntity(info, width: 128, height: 128),
            okAction: () => info.add(context: context),
          ),
          child: Text('Accept'.tr),
        ),
      ),
    ],
  );

}
