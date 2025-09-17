import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import 'chat/associates.dart';
import 'chat/chat_box.dart';


class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  static const String title = 'Chats';
  static const IconData icon = AppIcons.chatsTabIcon;

  static BottomNavigationBarItem barItem() => BottomNavigationBarItem(
    icon: const _ChatsIconView(icon: Icon(icon)),
    label: title.tr,
  );

  static Tab tab() => Tab(
    icon: const _ChatsIconView(icon: Icon(icon, size: 32)),
    text: title.tr,
    // height: 64,
    iconMargin: EdgeInsets.zero,
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
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
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
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      await _reload();
    } else if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? chat = userInfo?['ID'];
      Log.info('group history updated: $chat');
      await _reload();
    } else {
      assert(false, 'notification error: $notification');
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
    // burn expired messages
    BurnAfterReadingDataSource bar = BurnAfterReadingDataSource();
    bool ok = await bar.burnAll();
    Log.info('burned: $ok');
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
  Widget build(BuildContext context) {
    // var checker = PermissionChecker();
    // checker.checkNotificationPermissions(context);
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: colors.appBardBackgroundColor,
        middle: StatedTitleView.from(context, () => 'Secure Chat'.tr),
        trailing: plusButton(context),
      ),
      body: buildSectionListView(
        enableScrollbar: true,
        adapter: _adapter,
      ),
    );
  }
}

class _ChatListAdapter with SectionAdapterMixin {
  _ChatListAdapter({required Amanuensis dataSource}) : _dataSource = dataSource;

  final Amanuensis _dataSource;

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'ChatList::Description'.tr;
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
  int numberOfItems(int section) => _dataSource.conversations.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Conversation> conversations = _dataSource.conversations;
    if (indexPath.item >= conversations.length) {
      Log.error('out of range: ${conversations.length}, $indexPath');
      return const Text('');
    }
    Conversation info = conversations[indexPath.item];
    Log.debug('show item: $info');
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
    nc.addObserver(this, NotificationNames.kMessageTyping);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kMessageTyping);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kMessageTyping) {
      ID? cid = userInfo?['ID'];
      if (cid == widget.info.identifier) {
        Log.info('message updated: $cid');
        if (mounted) {
          setState(() {
            //
          });
        }
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      Log.info('muted contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
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
    leadingSize: 72,
    leading: _leading(widget.info),
    title: widget.info.getNameLabel(true),
    subtitle: _lastMessage(widget.info),
    additionalInfo: _timeLabel(widget.info),
    // trailing: const CupertinoListTileChevron(),
    onTap: () {
      Log.warning('tap: ${widget.info}');
      ChatBox.open(context, widget.info, null);
      },
    onLongPress: () {
      Log.warning('long press: ${widget.info}');
      Alert.confirm(context, 'Confirm Delete',
        previewEntity(widget.info),
        okAction: () => _removeConversation(context, widget.info.identifier),
      );
      },
  );

  void _removeConversation(BuildContext context, ID chat) {
    Log.warning('removing $chat');
    Amanuensis clerk = Amanuensis();
    Alert.confirm(context, 'Confirm Delete', 'Sure to remove this conversation?'.tr,
      okAction: () => clerk.removeConversation(chat).onError((error, stackTrace) {
        if (context.mounted) {
          Alert.show(context, 'Error', 'Failed to remove conversation'.tr);
        }
        return false;
      })
    );
  }

  Widget _leading(Conversation info) {
    int unread = info.unread;
    int others = 0;
    if (unread == 0 && info is GroupInfo) {
      bool canReview = info.isOwner || info.isAdmin;
      if (canReview) {
        others = info.invitations.length;
      }
    }
    if (info.isMuted) {
      // this conversation is muted,
      // show spot when unread messages or invitations exist.
      return IconView.fromSpot(info.getImage(width: 48, height: 48), unread + others);
    } else if (unread == 0) {
      // unread messages not exist,
      // show spot when invitations exist.
      return IconView.fromSpot(info.getImage(width: 48, height: 48), others);
    } else {
      // show unread number
      return IconView.fromNumber(info.getImage(width: 48, height: 48), unread);
    }
  }

  Widget? _lastMessage(Conversation info) {
    var shared = SharedEditingText();
    String? text = shared.getConversationEditingText(info);
    if (text != null && text.isNotEmpty) {
      return _richMessage('[${'Draft'.tr}] ', text);
    }
    text = info.lastMessage ?? '';
    if (info is GroupInfo && info.mentionedSerialNumber > 0) {
      return _richMessage('[${'Mentioned'.tr}] ', text);
    }
    return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,);
  }

  Widget? _timeLabel(Conversation info) {
    DateTime? time = info.lastMessageTime;
    bool? isMuted = info.isMuted;
    if (time == null && isMuted != true) {
      return null;
    } else if (time == null) {
      return const Icon(AppIcons.mutedIcon, size: 12,);
    } else if (isMuted != true) {
      return Text(TimeUtils.getTimeString(time));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
      Text(TimeUtils.getTimeString(time)),
      const Icon(AppIcons.mutedIcon, size: 12,),
    ],);
  }

}


Widget? _richMessage(String head, String body) => RichText(
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
  text: TextSpan(children: [
    TextSpan(text: head, style: const TextStyle(color: CupertinoColors.systemRed),),
    TextSpan(text: body, style: const TextStyle(color: CupertinoColors.systemGrey),),
  ]),
);


///
///   Chats Tab Item
///
class _ChatsIconView extends StatefulWidget {
  const _ChatsIconView({required this.icon});

  final Widget icon;

  @override
  State<StatefulWidget> createState() => _ChatsIconState();

}

class _ChatsIconState extends State<_ChatsIconView> implements lnc.Observer {
  _ChatsIconState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kConversationUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    await UnreadCounter().load();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    int count = UnreadCounter().count;
    Log.warning('new message count: $count');
    return IconView.fromNumber(widget.icon, count);
  }

}


class UnreadCounter {
  factory UnreadCounter() => _instance;
  static final UnreadCounter _instance = UnreadCounter._internal();
  UnreadCounter._internal();

  late final Amanuensis _clerk = Amanuensis();

  int _count = 0;

  int get count => _count;

  Future<int> load() async {
    List<Conversation> all = await _clerk.loadConversations();
    for (Conversation item in all) {
      await item.reloadData();
    }
    int count = 0;
    for (Conversation chat in all) {
      if (chat is ContactInfo) {
        if (chat.isMuted) {
          // Log.warning('skip muted chat: $chat');
          continue;
        } else if (chat.isBlocked) {
          // Log.warning('skip blocked chat: $chat');
          continue;
        } else if (chat.isNotFriend) {
          // Log.warning('skip stranger chat: $chat');
          continue;
        }
      }
      // Log.warning('chat: $chat');
      count += chat.unread;
    }
    return _count = count;
  }

}
