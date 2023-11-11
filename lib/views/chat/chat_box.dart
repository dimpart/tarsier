import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import '../contact/profile.dart';

import 'chat_flag.dart';
import 'chat_title.dart';
import 'chat_tray.dart';
import 'detail.dart';
import 'detail_group.dart';
import 'pick_chat.dart';


///
///  Chat Box
///
class ChatBox extends StatefulWidget {
  const ChatBox(this.info, {super.key});

  final Conversation info;

  static int maxCountOfMessages = 2048;

  static void open(BuildContext context, Conversation info) => showCupertinoDialog(
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
    Amanuensis clerk = Amanuensis();
    await clerk.clearUnread(widget.info);
  }

  @override
  void dispose() {
    // remove opened widget for enable updating unread count
    widget.info.widget = null;
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
    if (info is GroupInfo) {
      List<ContactInfo> members = ContactInfo.fromList(info.members);
      if (members.length < 2) {
        await shared.messenger?.queryMembers(info.identifier);
      }
    }
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
        child: SectionListView.builder(
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
          const Icon(CupertinoIcons.padlock_solid,
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
      // create content view
      contentView = Container(
        margin: Styles.messageContentMargin,
        constraints: content is ImageContent ? const BoxConstraints(maxHeight: 256) : null,
        child: ClipRRect(
          borderRadius: isMine
              ? borderRadius.subtract(
              const BorderRadius.only(topRight: radius))
              : borderRadius.subtract(
              const BorderRadius.only(topLeft: radius)),
          child: _getContentView(context, content, sender),
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

  Widget _getContentView(BuildContext ctx, Content content, ID sender) {
    if (content is ImageContent) {
      return ContentViewUtils.getImageContentView(ctx,
        content, sender, _dataSource.allMessages,
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          'Forward Image', () => _forwardImage(ctx, content, sender),
          // 'Save Image', () { },
        ),
      );
    } else if (content is AudioContent) {
      return ContentViewUtils.getAudioContentView(ctx, content, sender);
    } else if (content is VideoContent) {
      return ContentViewUtils.getVideoContentView(ctx, content, sender);
    } else if (content is PageContent) {
      return ContentViewUtils.getPageContentView(ctx, content, sender,
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          'Forward Web Page', () => _forwardWebPage(ctx, content, sender),
          // 'Save Image', () { },
        ),
        onWebShare: (url, {required title, desc, icon}) =>
            _shareWebPage(ctx, url, title: title, desc: desc, icon: icon),);
    } else if (content is NameCard) {
      return ContentViewUtils.getNameCardView(ctx, content,
        onTap: () => ProfilePage.open(ctx, content.identifier),
        onLongPress: () => Alert.actionSheet(ctx, null, null,
          'Forward Name Card', () => _forwardNameCard(ctx, content, sender),
        ),
      );
    } else {
      return ContentViewUtils.getTextContentView(ctx, content, sender,
        onWebShare: (url, {required title, desc, icon}) =>
            _shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
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
            IconButton(
                padding: Styles.messageSenderAvatarPadding,
                onPressed: () => _openProfile(context, sender, _conversation),
                icon: image
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
    Log.debug('refreshing ${history.length} message(s)');
    _messages = history;
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

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);

void _forwardImage(BuildContext ctx, ImageContent content, ID sender) {
  // get local file path, if not exists
  // try to download from file server
  FileTransfer ftp = FileTransfer();
  ftp.getFilePath(content).then((path) {
    if (path == null) {
      Alert.show(ctx, 'Image Not Found',
        'Failed to load image @filename'.trParams({
          'filename': '${content.filename}',
        })
      );
    } else {
      String filename = content.filename ?? Paths.filename(path) ?? 'a.jpeg';
      Uint8List? thumbnail = content.thumbnail;
      List traces = content['traces'] ?? [];
      traces = [...traces, {
        'ID': sender.toString(),
        'time': content.getDouble('time', 0),
      }];
      PickChatPage.open(ctx,
        onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
          _forwardImagePreview(content, chat),
          okAction: () => _sendImage(chat.identifier,
            path: path, filename: filename, thumbnail: thumbnail, traces: traces,
          ).then((ok) {
            if (ok) {
              Alert.show(ctx, 'Forwarded',
                'Image message forwarded to @chat'.trParams({
                  'chat': chat.title,
                }),
              );
            } else {
              Alert.show(ctx, 'Error',
                'Failed to share image with @chat'.trParams({
                  'chat': chat.title,
                }),
              );
            }
          }),
        ),
      );
    }
  });
}
Widget _forwardImagePreview(ImageContent content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from;
  Uint8List? thumbnail = content.thumbnail;
  if (thumbnail != null) {
    from = Image.memory(thumbnail);
    from = SizedBox(width: 64, child: from,);
  } else {
    String? filename = content.filename ??= 'Image';
    from = _previewText(filename);
  }
  Widget body = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      from,
      const SizedBox(width: 32,),
      const Text('~>'),
      const SizedBox(width: 32,),
      to,
    ],
  );
  return body;
}
Future<bool> _sendImage(ID receiver,
    {required String path, required String filename, Uint8List? thumbnail,
      required List traces}) async {
  // load image data
  Uint8List? jpeg = await ExternalStorage.loadBinary(path);
  if (jpeg == null) {
    Log.error('failed to load image: $path');
    return false;
  } else {
    Log.debug('forwarding image to $receiver: "$filename", traces: $traces');
  }
  // send image content with traces
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendImage(jpeg, filename, thumbnail, receiver, {
    'traces': traces,
  });
  return true;
}

void _forwardWebPage(BuildContext ctx, PageContent content, ID sender) {
  String urlString = HtmlUri.getUriString(content);
  Uri? url = HtmlUri.parseUri(urlString);
  if (url == null) {
    Alert.show(ctx, 'URL Error', urlString);
  } else {
    _shareWebPage(ctx, url, title: content.title, desc: content.desc, icon: content.icon);
  }
}
void _shareWebPage(BuildContext ctx, Uri url, {required String title, String? desc, Uint8List? icon}) {
  PickChatPage.open(ctx,
    onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
      _shareWebPagePreview(title, icon, chat),
      okAction: () => _sendWebPage(chat.identifier,
        url, title: title, desc: desc, icon: icon,
      ).then((ok) {
        if (ok) {
          Alert.show(ctx, 'Forwarded',
            'Web Page @title forwarded to @chat'.trParams({
              'title': title,
              'chat': chat.title,
            }),
          );
        } else {
          Alert.show(ctx, 'Error',
            'Failed to share Web Page @title with @chat'.trParams({
              'title': title,
              'chat': chat.title,
            }),
          );
        }
      }),
    ),
  );
}
Widget _shareWebPagePreview(String title, Uint8List? icon, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from;
  if (icon != null) {
    from = Image.memory(icon);
    from = SizedBox(width: 64, child: from,);
  } else if (title.isNotEmpty) {
    from = _previewText(title);
  } else {
    from = const Icon(AppIcons.webpageIcon);
  }
  Widget body = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      from,
      const SizedBox(width: 32,),
      const Text('~>'),
      const SizedBox(width: 32,),
      to,
    ],
  );
  return body;
}
Future<bool> _sendWebPage(ID receiver, Uri url,
    {required String title, String? desc, Uint8List? icon}) async {
  // create web page content
  TransportableData? ted = icon == null ? null : TransportableData.create(icon);
  PageContent content = PageContent.create(url: url,
      title: title, desc: desc, icon: ted);
  // check "data:text/html"
  HtmlUri.setHtmlString(url, content);
  Log.info('share web page to $receiver: "$title", $url');
  // send web page content
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver);
  return true;
}

void _forwardNameCard(BuildContext ctx, NameCard content, ID sender) {
  List traces = content['traces'] ?? [];
  traces = [...traces, {
    'ID': sender.toString(),
    'time': content.getDouble('time', 0),
  }];
  PickChatPage.open(ctx,
    onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
      _forwardNameCardPreview(content, chat),
      okAction: () => _sendContact(chat.identifier,
        identifier: content.identifier, name: content.name, avatar: content.avatar?.url.toString(),
        traces: traces,
      ).then((ok) {
        if (ok) {
          Alert.show(ctx, 'Forwarded',
              'Name Card @name forwarded to @chat'.trParams({
                'name': content.name,
                'chat': chat.title,
              })
          );
        } else {
          Alert.show(ctx, 'Error',
            'Failed to share Name Card @name with @chat'.trParams({
              'name': content.name,
              'chat': chat.title,
            }),
          );
        }
      }),
    ),
  );
}
Widget _forwardNameCardPreview(NameCard content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from;
  PortableNetworkFile? avatar = content.avatar;
  if (avatar != null) {
    from = NameCardView.avatarImage(content);
  } else {
    String name = content.name;
    if (name.isEmpty) {
      name = content.identifier.toString();
    }
    from = _previewText(name);
  }
  Widget body = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      from,
      const SizedBox(width: 32,),
      const Text('~>'),
      const SizedBox(width: 32,),
      to,
    ],
  );
  return body;
}
Future<bool> _sendContact(ID receiver,
    {required ID identifier, required String name, String? avatar,
      required List traces}) async {
  NameCard content = NameCard.create(identifier, name, PortableNetworkFile.parse(avatar));
  content['traces'] = traces;
  Log.debug('forward name card to receiver: $receiver, $content');
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver);
  return true;
}
