import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../contact/profile.dart';

import 'chat_flag.dart';
import 'chat_title.dart';
import 'chat_tray.dart';
import 'detail.dart';
import 'detail_group.dart';
import 'share_image.dart';
import 'share_contact.dart';
import 'share_page.dart';
import 'share_video.dart';


///
///  Chat Box
///
class ChatBox extends StatefulWidget {
  const ChatBox(this.info, {super.key});

  final Conversation info;

  static int maxCountOfMessages = 2048;

  static void open(BuildContext context, Conversation info) => showPage(
    context: context,
    builder: (context) => ChatBox(info),
  );

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> implements lnc.Observer {
  _ChatBoxState() {
    _dataSource = _HistoryDataSource();

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMessageUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  void _init() async {
    await _reload();
    // set opened widget for disable updating unread count
    widget.info.widget = widget;
    // clear badge
    Amanuensis clerk = Amanuensis();
    await clerk.clearUnread(widget.info);
  }

  void _reset() async {
    // clear badge
    Amanuensis clerk = Amanuensis();
    await clerk.clearUnread(widget.info);
    // remove opened widget for enable updating unread count
    widget.info.widget = null;
  }

  @override
  void dispose() {
    _reset();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kMessageUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kMessageUpdated) {
      ID? cid = userInfo?['ID'];
      assert(cid != null, 'notification error: $notification');
      if (cid == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      if (contact == null) {
        // block-list updated
        await _reload();
      } else if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? gid = userInfo?['ID'];
      assert(gid != null, 'notification error: $notification');
      if (gid == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group history updated: $chat');
        await widget.info.reloadData();
        await _reload();
      }
    } else {
      assert(false, 'notification error: $notification');
    }
  }

  late final _HistoryDataSource _dataSource;

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    ContentViewUtils.currentUser = await shared.facebook.currentUser;
    Conversation info = widget.info;
    var pair = await shared.database.getInstantMessages(info.identifier,
        limit: ChatBox.maxCountOfMessages);
    Log.warning('message updated: ${pair.first.length}');
    if (mounted) {
      setState(() {
        _dataSource.refresh(pair.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: ChatTitleView.from(context, widget.info),
      trailing: _detailButton(context, widget.info),
    ),
    body: _body(context),
  );

  Widget? _detailButton(BuildContext context, Conversation info) {
    if (info is GroupInfo && info.isNotMember) {
      return null;
    }
    Widget icon = IconButton(
      iconSize: Styles.navigationBarIconSize,
      icon: const Icon(AppIcons.chatDetailIcon),
      onPressed: () => _openDetail(context, widget.info),
    );
    if (info is GroupInfo) {
      bool canReview = info.isOwner || info.isAdmin;
      int count = info.invitations.length;
      if (canReview && count > 0) {
        Log.warning('invitations count: $count');
        return IconView.fromSpot(icon, count,
          alignment: const AlignmentDirectional(0.8, -0.8),
        );
      }
    }
    return icon;
  }

  Widget _body(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Expanded(
        flex: 1,
        child: buildSectionListView(
          enableScrollbar: true,
          reverse: true,
          adapter: _HistoryAdapter(widget.info,
            dataSource: _dataSource,
          ),
        ),
      ),
      Container(
        color: Styles.colors.inputTrayBackgroundColor,
        padding: const EdgeInsets.only(bottom: 16),
        child: _inputTray(context),
      ),
    ],
  );

  Widget _inputTray(BuildContext context) {
    Conversation info = widget.info;
    if (info.isBlocked) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Text('Blocked'.tr,
            style: TextStyle(
              color: Styles.colors.primaryTextColor,
            ),
          ),
        ),
      );
    } else if (info is GroupInfo && info.isNotMember) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Text('Non-Member'.tr,
            style: TextStyle(
              color: Styles.colors.primaryTextColor,
            ),
          ),
        ),
      );
    }
    // normally
    return ChatInputTray(info);
  }

}

class _HistoryAdapter with SectionAdapterMixin {
  _HistoryAdapter(Conversation conversation, {required _HistoryDataSource dataSource})
      : _conversation = conversation, _dataSource = dataSource;

  final Conversation _conversation;
  final _HistoryDataSource _dataSource;

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'ChatBox::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(AppIcons.encryptedIcon,
            size: 24,
            color: CupertinoColors.systemGrey,
          ),
          const SizedBox(width: 8,),
          Expanded(child: Text(prompt,
            style: Styles.sectionFooterTextStyle,
          )),
        ],
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    return _dataSource.getItemCount();
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    InstantMessage iMsg = _dataSource.getItem(indexPath.item);
    ID sender = iMsg.sender;
    Content content = iMsg.content;
    Widget? timeLabel = _getTimeLabel(context, iMsg, indexPath);
    String? commandText = _getCommandText(content, sender, indexPath);
    Widget? commandLabel;
    Widget? contentView;
    if (commandText == null) {
      Widget? nameLabel = _getNameLabel(context, sender);
      int mainFlex = 3;
      // show content
      if (content is PageContent) {
        mainFlex = 2;
      } else if (content is FileContent) {
        mainFlex = 1;
      } else if (content is TextContent) {
        mainFlex = 6;
      }
      bool isMine = sender == ContentViewUtils.currentUser?.identifier;
      const radius = Radius.circular(12);
      const borderRadius = BorderRadius.all(radius);
      BoxConstraints? constraints;
      if (content is ImageContent) {
        constraints = const BoxConstraints(maxHeight: 256);
      } else if (content is VideoContent) {
        constraints = const BoxConstraints(maxHeight: 256);
      }
      // create content view
      contentView = Container(
        margin: Styles.messageContentMargin,
        constraints: constraints,
        child: ClipRRect(
          borderRadius: isMine
              ? borderRadius.subtract(
              const BorderRadius.only(topRight: radius))
              : borderRadius.subtract(
              const BorderRadius.only(topLeft: radius)),
          child: _getContentView(context, content, iMsg.envelope),
        ),
      );
      // create content frame
      contentView = _getContentFrame(context, sender, mainFlex, isMine,
        image: AvatarFactory().getAvatarView(sender),
        name: nameLabel,
        body: contentView,
        flag: isMine ? ChatSendFlag(iMsg) : null,
      );
    } else if (commandText.isEmpty) {
      // hidden command
      return Container();
    } else {
      // show command
      commandLabel = _getCommandLabel(context, commandText);
    }
    return Container(
      margin: Styles.messageItemMargin,
      child: Column(
        children: [
          if (timeLabel != null)
            timeLabel,
          if (commandLabel != null)
            commandLabel,
          if (contentView != null)
            contentView,
        ],
      ),
    );
  }

  Widget? _getTimeLabel(BuildContext context, InstantMessage iMsg, IndexPath indexPath) {
    DateTime? time = iMsg.time;
    if (time == null) {
      assert(false, 'message time not found: $iMsg');
      return null;
    }
    int total = _dataSource.getItemCount();
    if (indexPath.item < total - 1) {
      DateTime? prev = _dataSource.getItem(indexPath.item + 1).time;
      if (prev != null) {
        int delta = time.millisecondsSinceEpoch - prev.millisecondsSinceEpoch;
        if (-120000 < delta && delta < 120000) {
          // it is too close to the previous message,
          // hide this time label to reduce noises.
          return null;
        }
      }
    }
    return Text(TimeUtils.getTimeString(time),
      style: Styles.messageTimeTextStyle,
    );
  }

  Widget? _getNameLabel(BuildContext context, ID sender) {
    if (sender == ContentViewUtils.currentUser?.identifier) {
      // no need to show my name in chat box
      return null;
    } else if (sender == _conversation.identifier) {
      // no need to show friend's name if your are in a personal chat box
      return null;
    }
    return ContentViewUtils.getNameLabel(context, sender);
  }

  String? _getCommandText(Content content, ID sender, IndexPath? indexPath) {
    String? text = ContentViewUtils.getCommandText(content, sender, _conversation);
    if (text != null && text.isNotEmpty && indexPath != null) {
      // if it's a command, check duplicate with next one
      if (indexPath.item > 0) {
        InstantMessage iMsg = _dataSource.getItem(indexPath.item - 1);
        String? next = _getCommandText(iMsg.content, iMsg.sender, null);
        if (next == text) {
          // duplicated, just keep the last one
          text = '';
        }
      }
    }
    return text;
  }
  Widget? _getCommandLabel(BuildContext context, String text) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Expanded(flex: 1, child: Container()),
      Expanded(flex: 2,
        child: ContentViewUtils.getCommandLabel(context, text),
      ),
      Expanded(flex: 1, child: Container()),
    ],
  );

  Widget _getContentView(BuildContext ctx, Content content, Envelope envelope) {
    ID sender = envelope.sender;
    if (content is ImageContent) {
      return ContentViewUtils.getImageContentView(ctx,
        content, sender, _dataSource.allMessages,
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          Alert.action(AppIcons.shareIcon, 'Forward Image'),
              () => ShareImage.forwardImage(ctx, content, sender),
          Alert.action(AppIcons.saveFileIcon, 'Save to Album'),
              () => saveImageContent(ctx, content),
          _canRecall(content) ? Alert.action(AppIcons.recallIcon, 'Recall Message') : null,
              () => _recallImageMessage(ctx, content, envelope),
        ),
      );
    } else if (content is VideoContent) {
      return ContentViewUtils.getVideoContentView(ctx, content, sender,
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          Alert.action(AppIcons.shareIcon, 'Forward Video'),
              () => ShareVideo.forwardVideo(ctx, content, sender),
          _canRecall(content) ? Alert.action(AppIcons.recallIcon, 'Recall Message') : null,
              () => _recallVideoMessage(ctx, content, envelope),
        ),
        onVideoShare: (playingItem) =>
            ShareVideo.forwardVideo(ctx, content, sender),
      );
    } else if (content is AudioContent) {
      return ContentViewUtils.getAudioContentView(ctx, content, sender,
        onLongPress: !_canRecall(content) ? null : () => Alert.actionSheet(ctx, null, null,
          Alert.action(AppIcons.recallIcon, 'Recall Message'),
              () => _recallAudioMessage(ctx, content, envelope),
        ),
      );
    } else if (content is PageContent) {
      return ContentViewUtils.getPageContentView(ctx, content, sender,
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          Alert.action(AppIcons.shareIcon, 'Forward Web Page'),
              () => ShareWebPage.forwardWebPage(ctx, content, sender),
          // 'Save Image', () { },
        ),
        onWebShare: (url, {required title, required desc, required icon}) =>
            ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),);
    } else if (content is NameCard) {
      return ContentViewUtils.getNameCardView(ctx, content,
        onTap: () => ProfilePage.open(ctx, content.identifier),
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          Alert.action(AppIcons.shareIcon, 'Forward Name Card'),
              () => ShareNameCard.forwardNameCard(ctx, content, sender),
        ),
      );
    } else {
      return ContentViewUtils.getTextContentView(ctx, content, sender,
        onWebShare: (url, {required title, required desc, required icon}) =>
            ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
        onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
      );
    }
  }

  Widget _getContentFrame(BuildContext context, ID sender, int mainFlex, bool isMine,
      {required Widget image, Widget? name, required Widget body, required Widget? flag}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMine)
            Expanded(flex: 1, child: Container()),
          if (!isMine)
            GestureDetector(
              child: Container(
                padding: Styles.messageSenderAvatarPadding,
                child: image,
              ),
              onTap: () => _openProfile(context, sender, _conversation),
              onLongPress: () => _onMentioned(sender),
            ),
          Expanded(flex: mainFlex, child: Column(
            crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (name != null)
                name,
              body,
              if (flag != null)
                flag,
            ],
          )),
          if (isMine)
            Container(
              padding: Styles.messageSenderAvatarPadding,
              child: image,
            ),
          if (!isMine)
            Expanded(flex: 1, child: Container()),
        ],
      );

}

class _HistoryDataSource {

  List<InstantMessage> _messages = [];

  List<InstantMessage> get allMessages => _messages;

  void refresh(List<InstantMessage> history) {
    Log.debug('sort and refreshing ${history.length} message(s)');
    List<InstantMessage> array = [];
    for (var his in history) {
      if (his.content.getBool('hidden', false) == true) {
        continue;
      }
      array.add(his);
    }
    array.sort((a, b) {
      int ams = a.time?.millisecondsSinceEpoch ?? 0;
      int bms = b.time?.millisecondsSinceEpoch ?? 0;
      return bms - ams;
    });
    _messages = array;
  }

  int getItemCount() => _messages.length;

  InstantMessage getItem(int index) => _messages[index];
}

//--------

void _openDetail(BuildContext ctx, Conversation info) {
  ID identifier = info.identifier;
  if (identifier.isGroup) {
    GroupChatDetailPage.open(ctx, identifier);
  } else {
    ChatDetailPage.open(ctx, identifier);
  }
}

void _openProfile(BuildContext ctx, ID uid, Conversation info) {
  ProfilePage.open(ctx, uid, fromChat: info.identifier);
}

void _onMentioned(ID uid) {
  // post notification async
  var nc = lnc.NotificationCenter();
  nc.postNotification(NotificationNames.kAvatarLongPressed, null, {
    'user': uid,
  });
}

///
///   Recall Messages
///
bool _canRecall(Content content) {
  DateTime? when = content.time;
  if (when == null) {
    return true;
  }
  Duration elapsed = DateTime.now().difference(when);
  return elapsed.inSeconds < 128;
}
void _recallImageMessage(BuildContext ctx, ImageContent content, Envelope envelope) {
  Log.info('recalling image message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
    okAction: () {
      GlobalVariable shared = GlobalVariable();
      shared.emitter.recallImageMessage(content, envelope).then((pair) {
        if (pair.first == null) {
          Log.warning('failed to recall message.');
        } else {
          Log.info('message recalled.');
        }
      });
    }
  );
}
void _recallVideoMessage(BuildContext ctx, VideoContent content, Envelope envelope) {
  Log.info('recalling video message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallVideoMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}
void _recallAudioMessage(BuildContext ctx, AudioContent content, Envelope envelope) {
  Log.info('recalling audio message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallAudioMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}
