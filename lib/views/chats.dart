import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_box.dart';
import 'search.dart';


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
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
    super.dispose();
  }

  final Amanuensis _clerk;

  late final _ChatListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    // Map? info = notification.userInfo;
    if (name == NotificationNames.kConversationUpdated) {
      await _reload();
      Log.warning('conversation updated');
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

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Secure Chat'),
      trailing: SearchPage.searchButton(context),
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
  int numberOfItems(int section) => _dataSource.numberOfConversation;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    Conversation info = _dataSource.conversationAtIndex(indexPath.item);
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
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    ID? cid = userInfo?['ID'];
    if (cid == null) {
      Log.error('notification error: $notification');
    }
    if (name == NotificationNames.kDocumentUpdated) {
      if (cid == widget.info.identifier) {
        await _reload();
      } else {
        // TODO: check members for group chat?
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
    title: Text(widget.info.name),
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
        'Remove ${widget.info.name}',
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

  Widget _leading(Conversation info) => BadgeView(info.getImage(), info.unread);

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
