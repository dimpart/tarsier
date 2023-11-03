import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat/associates.dart';
import 'chat/chat_box.dart';


class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  static BottomNavigationBarItem barItem() => const BottomNavigationBarItem(
    icon: Icon(Styles.chatsTabIcon),
    label: 'Chats',
  );

  @override
  State<StatefulWidget> createState() => _ChatListState();
}

class _ChatListState extends State<ChatHistoryPage> implements lnc.Observer {
  _ChatListState() : _clerk = Amanuensis() {
    _adapter = _ChatListAdapter(dataSource: _clerk);

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

  late final _ChatListAdapter _adapter;

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
    await _clerk.loadConversations();
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }
  Future<void> _testSpeeds() async {
    // wait a while to test all stations
    await Future.delayed(const Duration(seconds: 5));
    StationSpeeder speeder = StationSpeeder();
    await speeder.reload();
    await speeder.testAll();
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _testSpeeds();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Secure Chat'),
      trailing: plusButton(context),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _ChatListAdapter with SectionAdapterMixin {
  _ChatListAdapter({required Amanuensis dataSource}) : _dataSource = dataSource;

  final Amanuensis _dataSource;

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = '* Here shows chat histories of your friends only;\n'
        '* Strangers will be placed in "Contacts -> New Friends".';
    return Container(
      color: Facade.of(context).colors.appBardBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(prompt,
            style: Facade.of(context).styles.sectionFooterTextStyle,
          )),
        ],
      ),
    );
  }

  @override
  int numberOfItems(int section) => _dataSource.conversations.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Conversation> conversations = _dataSource.conversations;
    if (indexPath.item >= conversations.length) {
      Log.error('out of range: ${conversations.length}, $indexPath');
      return const Text('null');
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

class _ChatTableCellState extends State<_ChatTableCell> {
  _ChatTableCellState();

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
    leadingSize: 72,
    leading: _leading(widget.info),
    title: widget.info.getNameLabel(),
    subtitle: _lastMessage(widget.info.lastMessage),
    additionalInfo: _timeLabel(widget.info.lastTime),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      Log.warning('tap: ${widget.info}');
      ChatBox.open(context, widget.info);
      },
    onLongPress: () {
      Log.warning('long press: ${widget.info}');
      Alert.actionSheet(context,
        'Confirm', 'Are you sure to remove this conversation?',
        'Remove ${widget.info.title}',
            () => _removeConversation(context, widget.info.identifier),
      );
      },
  );

  void _removeConversation(BuildContext context, ID chat) {
    Log.warning('removing $chat');
    Amanuensis clerk = Amanuensis();
    clerk.removeConversation(chat).onError((error, stackTrace) {
      Alert.show(context, 'Error', 'Failed to remove conversation');
      return false;
    });
  }

  Widget _leading(Conversation info) {
    if (widget.info.isMuted) {
      return IconView.fromSpot(info.getImage(width: 48, height: 48), info.unread);
    } else {
      return IconView.fromNumber(info.getImage(width: 48, height: 48), info.unread);
    }
  }

  Widget? _lastMessage(String? last) {
    if (last == null) {
      return null;
    }
    return Text(last);
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(TimeUtils.getTimeString(time));
  }
}
