import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../../sharing/pick_chat.dart';
import '../../sharing/share_contact.dart';
import '../../widgets/text.dart';
import '../chat/chat_box.dart';
import '../service/base.dart';


class ProfilePage extends StatefulWidget {
  ProfilePage(this.info, this.fromChat, {super.key});

  final ContactInfo info;
  final ID? fromChat;

  final List<ServiceInfo> _services = [];
  List<ServiceInfo> get services {
    if (_services.isEmpty) {
      var array = info.visa?.getProperty('services');
      if (array is List) {
        _services.addAll(ServiceInfo.convert(array));
      }
    }
    return _services;
  }

  static void open(BuildContext context, ID identifier, {ID? fromChat}) {
    ContactInfo? info = ContactInfo.fromID(identifier);
    info?.reloadData().then((value) {
      if (context.mounted) {
        showPage(
          context: context,
          builder: (context) => ProfilePage(info, fromChat),
        );
      }
    }).onError((error, stackTrace) {
      if (context.mounted) {
        Alert.show(context, 'Error', '$error');
      }
    });
  }

  static Widget cell(ContactInfo info, {Widget? trailing, GestureLongPressCallback? onLongPress}) =>
      _ProfileTableCell(info, trailing: trailing, onLongPress: onLongPress);

  @override
  State<StatefulWidget> createState() => _ProfileState();

}

class _ProfileState extends State<ProfilePage> with Logging implements lnc.Observer {
  _ProfileState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  final FocusNode _focusNode = FocusNode();
  String? _alias;

  @override
  void dispose() {
    _focusNode.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        logInfo('document updated: $identifier');
        await _reload();
      }
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      logInfo('contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      logInfo('blocked contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      logInfo('muted contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else {
      logError('notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  Future<void> _refresh() async {
    var shared = GlobalVariable();
    var facebook = shared.facebook;
    ID identifier = widget.info.identifier;
    List<Document> docs = await facebook.getDocuments(identifier);
    logInfo('refreshing ${docs.length} document(s) "${widget.info.name}" $identifier');
    await facebook.entityChecker?.queryDocuments(identifier, docs);
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      body: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            backgroundColor: colors.appBardBackgroundColor,
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text(widget.info.name,
              style: Styles.titleTextStyle,
            ),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: buildScrollView(
              enableScrollbar: true,
              child: _body(context,
                backgroundColor: colors.sectionItemBackgroundColor,
                backgroundColorActivated: colors.sectionItemDividerColor,
                dividerColor: colors.sectionItemDividerColor,
                primaryTextColor: colors.primaryTextColor,
                secondaryTextColor: colors.tertiaryTextColor,
                dangerousTextColor: CupertinoColors.systemRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color dangerousTextColor,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [

      /// Avatar
      const SizedBox(height: 32,),
      _avatarImage(context),
      const SizedBox(height: 32,),

      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// ID
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('ID', style: TextStyle(color: primaryTextColor)),
            additionalInfo: _idLabel(context),
          ),
          /// Remark
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Remark'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 160,
              child: _remarkTextField(context),
            ),
          ),
        ],
      ),

      if (widget.info.language != null || widget.info.clientInfo != null)
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Language
          if (widget.info.language != null)
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Language'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: Text(widget.info.language ?? 'Unknown'.tr),
          ),
          /// App Version
          if (widget.info.clientInfo != null)
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('App'.tr, style: TextStyle(color: primaryTextColor)),
            // additionalInfo: Text(widget.info.clientInfo ?? 'Unknown'.tr),
            additionalInfo: _appInfo(context, widget.info),
          ),
        ],
      ),

      if (widget.services.isNotEmpty)
        CupertinoListSection(
          backgroundColor: dividerColor,
          topMargin: 0,
          additionalDividerMargin: 32,
          children: _serviceList(context, widget.services,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
          ),
        ),

      if (widget.info.identifier.type != EntityType.STATION)
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Block
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            leading: Icon(AppIcons.blockListIcon, color: primaryTextColor),
            title: Text('Block Messages'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: CupertinoSwitch(
              value: widget.info.isBlocked,
              onChanged: (bool value) => setState(() {
                if (value) {
                  widget.info.block(context: context);
                } else {
                  widget.info.unblock(context: context);
                }
              }),
            ),
          ),
          /// Mute
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            leading: Icon(AppIcons.muteListIcon, color: primaryTextColor),
            title: Text('Mute Notifications'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: CupertinoSwitch(
              value: widget.info.isMuted,
              onChanged: (bool value) => setState(() {
                if (value) {
                  widget.info.mute(context: context);
                } else {
                  widget.info.unmute(context: context);
                }
              }),
            ),
          ),
        ],
      ),

      CupertinoListSection(
        backgroundColor: dividerColor,
        dividerMargin: 0,
        additionalDividerMargin: 0,
        children: [
          /// add friend
          if (widget.info.isNotFriend)
            _addButton(context, textColor: primaryTextColor, backgroundColor: backgroundColor),
          /// send message
          if (widget.info.isFriend/* && !widget.info.isBlocked*/)
            _sendButton(context, textColor: primaryTextColor, backgroundColor: backgroundColor),
          /// share contact
          if (widget.info.isFriend)
            _shareButton(context, textColor: primaryTextColor, backgroundColor: backgroundColor),
          /// delete contact
          if (widget.info.isFriend && widget.fromChat == null)
            _deleteButton(context, textColor: dangerousTextColor, backgroundColor: backgroundColor),
        ],
      ),

      const SizedBox(height: 64,),

    ],
  );

  Widget _appInfo(BuildContext context, ContactInfo? info) {
    // get client info - "name (os; store) version"
    String? clientInfo = info?.clientInfo;
    clientInfo ??= 'Unknown'.tr;
    // get app/sys info from visa
    Visa? visa = info?.visa;
    var app = visa?.getProperty('app');
    var sys = visa?.getProperty('sys');
    if (app == null && sys == null) {
      return Text(clientInfo);
    }
    // show for debugging
    return GestureDetector(
      child: Text(clientInfo),
      onDoubleTap: () => _showAppInfo(context, app: app, sys: sys),
    );
  }

  void _showAppInfo(BuildContext context, {dynamic app, dynamic sys}) {
    var text = '';
    // show app info
    if (app is Map) {
      text += '## visa.app\n';
      text += '| Key | Value |\n';
      text += '|-----|-------|\n';
      app.forEach((key, value) {
        text += '| $key | $value |\n';
      });
      text += '\n';
    } else {
      text += 'visa.app: $app\n';
    }
    // show sys info
    if (sys is Map) {
      text += '## visa.sys\n';
      text += '| Key | Value |\n';
      text += '|-----|-------|\n';
      sys.forEach((key, value) {
        text += '| $key | $value |\n';
      });
      text += '\n';
    } else {
      text += 'visa.sys: $sys\n';
    }
    Widget body = RichTextView(text: text,
      sender: ID.FOUNDER, onWebShare: null, onVideoShare: null,
    );
    body = buildScrollView(
      child: body,
    );
    body = SizedBox(
      height: 320,
      child: body,
    );
    return FrostedGlassPage.show(context,
      title: 'Client Info'.tr,
      body: body,
    );
  }

  List<Widget> _serviceList(BuildContext context, List<ServiceInfo> services, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    // required Color dividerColor,
    required Color primaryTextColor,
    // required Color secondaryTextColor,
    // required Color dangerousTextColor,
  }) {
    List<Widget> items = [];
    for (var info in services) {
      var subtitle = info.subtitle ?? info.provider;
      items.add(CupertinoListTile(
        backgroundColor: backgroundColor,
        backgroundColorActivated: backgroundColorActivated,
        padding: Styles.settingsSectionItemPadding,
        title: Text(info.title, style: TextStyle(color: primaryTextColor)),
        additionalInfo: subtitle == null ? null : Text(subtitle),
        trailing: const CupertinoListTileChevron(),
        onTap: () => info.open(context),
      ));
    }
    return items;
  }

  Widget _avatarImage(BuildContext context) => GestureDetector(
    onTap: () {
      GlobalVariable shared = GlobalVariable();
      shared.facebook.getAvatar(widget.info.identifier).then((pnf) {
        if (pnf == null) {
          logError('avatar image not found: ${widget.info.identifier}');
        } else if (context.mounted) {
          logInfo('preview avatar: $pnf');
          previewAvatar(context, widget.info.identifier, pnf);
        }
      });
    },
    child: widget.info.getImage(width: 256, height: 256, ),
  );

  Widget _idLabel(BuildContext context) => Expanded(
    flex: 9,
    child: SelectableText(widget.info.identifier.toString(),
      textAlign: TextAlign.right,
      minLines: 1,
      maxLines: 2,
      style: Styles.identifierTextStyle,
    ),
  );

  Widget _remarkTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: TextEditingController(text: widget.info.remark.alias),
    placeholder: 'Please input alias'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
    focusNode: _focusNode,
    onChanged: (value) => _alias = value,
    onTapOutside: (event) => _changeAlias(context),
    onSubmitted: (value) => _changeAlias(context),
  );

  void _changeAlias(BuildContext context) {
    _focusNode.unfocus();
    // get alias value
    String? text = _alias;
    ContactRemark remark = widget.info.remark;
    if (text == null) {
      // nothing input
      return;
    } else if (remark.alias == text) {
      logWarning('alias not change: $remark');
      return;
    }
    setState(() {
      widget.info.setRemark(context: context, alias: text);
    });
  }

  Widget _addButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Add Contact'.tr, AppIcons.addFriendIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => widget.info.add(context: context),
      );

  Widget _sendButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Send Message'.tr, AppIcons.sendMsgIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _sendMessage(context, widget.info, widget.fromChat),
      );

  Widget _shareButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Share Contact'.tr, AppIcons.shareIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _shareContact(context, widget.info),
      );

  Widget _deleteButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Delete Contact'.tr, AppIcons.deleteIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => widget.info.delete(context: context),
      );

  Widget _button(String title, IconData icon, {required Color textColor, required Color backgroundColor,
    VoidCallback? onPressed}) => Row(
    children: [
      Expanded(child: Container(
        color: backgroundColor,
        child: CupertinoButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor,),
              const SizedBox(width: 12,),
              Text(title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold,),
              ),
            ],
          ),
        ),
      ))
    ],
  );

}

void _sendMessage(BuildContext ctx, ContactInfo info, ID? fromChat) {
  if (info.identifier == fromChat) {
    // this page is open from a chat box
    closePage(ctx);
  } else {
    ChatBox.open(ctx, info, null);
  }
}

void _shareContact(BuildContext ctx, ContactInfo info) {
  PickChatPage.open(ctx, onPicked: (chat) {
    Log.debug('sharing contact: $info => $chat');
    ID cid = info.identifier;
    if (chat.identifier == cid) {
      Alert.show(ctx, 'Error', 'Cannot share to itself'.tr);
      return;
    }
    Widget from = previewEntity(info);
    Widget to = previewEntity(chat);
    Widget body = forwardPreview(from, to);
    Alert.confirm(ctx, 'Confirm Share', body,
      okAction: () => _sendContact(chat.identifier,
        identifier: info.identifier, name: info.title, avatar: info.avatar,
      ).then((ok) {
        if (!ctx.mounted) {
          Log.warning('context unmounted: $ctx');
        } else if (ok) {
          Alert.show(ctx, 'Shared',
            'Contact @name shared to @chat'.trParams({
              'name': info.title,
              'chat': chat.title,
            }),
          );
        } else {
          Alert.show(ctx, 'Error',
            'Failed to share contact @name with @chat'.trParams({
              'name': info.title,
              'chat': chat.title,
            }),
          );
        }
      }),
    );
  });
}
Future<bool> _sendContact(ID receiver,
    {required ID identifier, required String name, String? avatar}) async {
  NameCard content = NameCard.create(identifier, name, PortableNetworkFile.parse(avatar));
  Log.debug('name card: $content');
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver: receiver);
  return true;
}

//
//  Profile Table Cell
//

class _ProfileTableCell extends StatefulWidget {
  const _ProfileTableCell(this.info, {this.onLongPress, this.trailing});

  final ContactInfo info;
  final GestureLongPressCallback? onLongPress;

  final Widget? trailing;

  @override
  State<StatefulWidget> createState() => _ProfileTableState();

}

class _ProfileTableState extends State<_ProfileTableCell> implements lnc.Observer {
  _ProfileTableState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kRemarkUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kRemarkUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      if (identifier == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? identifier = userInfo?['contact'];
      if (identifier == widget.info.identifier) {
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
    leading: widget.info.getImage(),
    title: _title(),
    subtitle: _subtitle(),
    additionalInfo: _timeLabel(widget.info.lastActiveTime),
    trailing: widget.trailing,
    onTap: () => ProfilePage.open(context, widget.info.identifier),
    onLongPress: widget.onLongPress,
  );

  Widget _title() {
    bool remarks = widget.info.isNotFriend;
    return widget.info.getNameLabel(remarks);
  }

  Widget? _subtitle() {
    String desc;
    if (widget.info.isNotFriend) {
      desc = widget.info.identifier.toString();
    } else {
      ContactRemark cr = widget.info.remark;
      desc = cr.alias;
      if (desc.isEmpty) {
        return null;
      }
    }
    return Text(desc);
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(TimeUtils.getTimeString(time));
  }

}
