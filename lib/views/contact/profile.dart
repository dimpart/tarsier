import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import '../../sharing/pick_chat.dart';
import '../../widgets/text.dart';
import '../chat/chat_box.dart';
import '../service/base.dart';
import '../service/report.dart';
import '../setting/devices.dart';


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

  /// All visa documents of the contact (each visa may carry an avatar)
  late Future<List<Document>> _documents;

  /// Controller for the avatar carousel (cover-flow style)
  final PageController _avatarController = PageController(viewportFraction: 0.72);

  /// Index of the current avatar page (syncs the large title)
  int _avatarIndex = 0;

  final TextEditingController _aliasTextEditingController = TextEditingController();
  final TextEditingController _memoTextEditingController = TextEditingController();
  final FocusNode _aliasFocusNode = FocusNode();
  final FocusNode _memoFocusNode = FocusNode();
  String? _alias;
  String? _memo;

  @override
  void dispose() {
    _avatarController.dispose();
    _aliasTextEditingController.dispose();
    _memoTextEditingController.dispose();
    _aliasFocusNode.dispose();
    _memoFocusNode.dispose();
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

  Future<void> _reload({bool init = false}) async {
    await widget.info.reloadData();
    // refresh visa documents in case avatars changed
    _documents = GlobalVariable().facebook.getDocuments(widget.info.identifier);
    if (init) {
      _aliasTextEditingController.text = widget.info.remark.alias;
      _memoTextEditingController.text = widget.info.remark.description;
    }
    if (mounted) {
      setState(() {
      });
    }
  }

  Future<bool> _refresh() async {
    var contact = widget.info;
    return await contact.refreshDocuments();
  }

  @override
  void initState() {
    super.initState();
    // load all visa documents for the multi-avatar view
    _documents = GlobalVariable().facebook.getDocuments(widget.info.identifier);
    _reload(init: true);
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
            backgroundColor: colors.appBarBackgroundColor,
            // only show the middle title in the collapsed state, otherwise
            // it would overlap the large title in the expanded state
            alwaysShowMiddle: false,
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            // sync the large title with the current avatar page (visa name)
            largeTitle: _avatarTitle(Styles.titleTextStyle),
            // the bar is permanently collapsed in landscape, so provide a
            // middle title with the same sync logic (fresh instance each build
            // keeps the frozen effectiveMiddle in the SDK updated)
            middle: _avatarTitle(null),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverToBoxAdapter(
            child: _body(context,
              backgroundColor: colors.sectionItemBackgroundColor,
              backgroundColorActivated: colors.sectionItemDividerColor,
              dividerColor: colors.sectionItemDividerColor,
              primaryTextColor: colors.primaryTextColor,
              secondaryTextColor: colors.tertiaryTextColor,
              dangerousTextColor: CupertinoColors.systemRed,
            ),
          ),
        ],
      ),
    );
  }

  /// Title text synced with the current avatar page (visa name).
  /// A null [style] lets the navigation bar apply its own middle style.
  Widget _avatarTitle(TextStyle? style) => FutureBuilder<List<Document>>(
    future: _documents,
    builder: (context, snapshot) {
      List<Visa> visas = _allVisas(snapshot.data);
      if (visas.isEmpty || _avatarIndex >= visas.length) {
        return Text(widget.info.name, style: style);
      }
      return Text(visas[_avatarIndex].name ?? widget.info.name, style: style);
    },
  );

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
          /// Remark: Alias
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Alias'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 160,
              child: _aliasTextField(context),
            ),
          ),
          /// Remark: Memo
          buildAdaptiveListTile(context,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Memo'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: _memoTextField(context),
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
          if (widget.info.isBlocked || !CustomerService.isManager(widget.info.identifier))
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
      onDoubleTap: () => _showAppInfo(context, visa, app: app, sys: sys),
    );
  }

  void _showAppInfo(BuildContext context, Visa? visa, {dynamic app, dynamic sys}) {
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
    // show registered/updated time
    var regTime = Converter.getDateTime(visa?.getProperty('created_time'));
    var updatedTime = visa?.time;
    if (regTime != null || updatedTime != null) {
      text += '\n';
      text += '* created: $regTime\n';
      text += '* updated: $updatedTime\n';
    }
    Widget body = RichTextView(text: text,
      sender: ID.FOUNDER, onWebShare: null, onVideoShare: null,
    );
    body = buildScrollView(
      child: body,
    );
    body = SizedBox(
      height: 400,
      child: body,
    );
    return FrostedGlassPage.show(context,
      title: 'Client Info'.tr,
      body: body,
      width: 308,
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

  /// All visa documents of the contact, sorted by update time (latest first)
  List<Visa> _allVisas(List<Document>? documents) {
    List<Visa> visas = documents?.whereType<Visa>().toList() ?? [];
    // sort by update time, latest first
    visas.sort((a, b) {
      var ta = a.time;
      var tb = b.time;
      if (ta == null) {
        return tb == null ? 0 : 1;
      } else if (tb == null) {
        return -1;
      }
      return tb.compareTo(ta);
    });
    return visas;
  }

  Widget _avatarImage(BuildContext context) => FutureBuilder<List<Document>>(
    future: _documents,
    builder: (context, snapshot) {
      // collect all visa documents (each visa may carry an avatar)
      List<Visa> visas = _allVisas(snapshot.data);
      if (visas.isEmpty) {
        // fallback: keep original view while loading or no visa
        return widget.info.getImage(width: 256, height: 256);
      }
      return SizedBox(
        height: 256,
        child: PageView.builder(
          controller: _avatarController,
          itemCount: visas.length,
          // update the page index to sync the large title
          onPageChanged: (index) => setState(() {
            _avatarIndex = index;
          }),
          itemBuilder: (context, index) {
            Visa visa = visas[index];
            return GestureDetector(
              onTap: () {
                var avatar = visa.avatar;
                if (avatar != null) {
                  previewAvatar(context, widget.info.identifier, avatar);
                }
              },
              // cover-flow style: scale/rotate each page by its distance to the current page
              child: AnimatedBuilder(
                animation: _avatarController,
                child: _avatarView(visa, showBadge: visas.length > 1),
                builder: (context, child) {
                  double page = _avatarController.hasClients
                      ? (_avatarController.page ?? 0.0)
                      : 0.0;
                  double distance = (index - page).clamp(-1.0, 1.0);
                  double scale = 1.0 - distance.abs() * 0.615;
                  double angle = distance * 0.2;
                  double tx = -distance * 0.3 * MediaQuery.of(context).size.width;
                  var transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.005)
                    ..translateByDouble(tx, 0, 0, 1.0)
                    ..rotateY(angle)
                    ..scaleByDouble(scale, scale, scale, 1.0);
                  return Center(
                    child: SizedBox(
                      width: 256,
                      height: 256,
                      child: Opacity(
                        opacity: scale,
                        child: Transform(
                          transform: transform,
                          alignment: Alignment.center,
                          child: child,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    },
  );

  Widget _avatarView(Visa visa, {required bool showBadge}) {
    const double avatarSize = 256;
    // rounded square avatar, same as the original avatar style
    Widget image;
    var avatar = visa.avatar;
    if (avatar == null) {
      // default icon when the visa has no avatar
      image = Icon(AppIcons.userIcon, size: avatarSize, color: Styles.colors.avatarDefaultColor);
    } else {
      image = AvatarFactory().getImageView(widget.info.identifier, avatar,
        width: avatarSize, height: avatarSize);
    }
    // hide the badge for a single visa or when the device type is unknown
    IconData? iconData = visa.deviceIcon;
    if (!showBadge || iconData == null) {
      return roundedRectangle(image, radius: avatarSize / 8);
    }
    // put on device icon
    return applyDeviceIcon(image, iconData,
      radius: avatarSize / 8,
      alignment: const AlignmentDirectional(1.1, 1.0),
    );
  }

  Widget _idLabel(BuildContext context) => Expanded(
    flex: 9,
    child: SelectableText(widget.info.identifier.toString(),
      textAlign: TextAlign.right,
      minLines: 1,
      maxLines: 2,
      style: Styles.identifierTextStyle,
    ),
  );

  Widget _aliasTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: _aliasTextEditingController,
    placeholder: 'Please input alias'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
    focusNode: _aliasFocusNode,
    onChanged: (value) => _alias = value,
    onTapOutside: (event) => _changeAlias(context),
    onSubmitted: (value) => _changeAlias(context),
  );

  Widget _memoTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    textAlignVertical: TextAlignVertical.top,
    controller: _memoTextEditingController,
    placeholder: 'Please input memo'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
    focusNode: _memoFocusNode,
    onChanged: (value) => _memo = value,
    onTapOutside: (event) => _changeMemo(context),
    onSubmitted: (value) => _changeMemo(context),
    maxLines: 10,
    minLines: 1,
    expands: false,
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
  );

  void _changeAlias(BuildContext context) {
    _aliasFocusNode.unfocus();
    _updateRemark(context, _alias?.trim(), _memo?.trim());
  }
  void _changeMemo(BuildContext context) {
    _memoFocusNode.unfocus();
    _updateRemark(context, _alias?.trim(), _memo?.trim());
  }
  void _updateRemark(BuildContext context, String? alias, String? description) {
    ContactRemark remark = widget.info.remark;
    if (alias == null && description == null) {
      // nothing input
      return;
    } else if (alias == remark.alias && description == remark.description) {
      logWarning('alias/memo not change: "$alias", "$description" -> $remark');
      return;
    }
    setState(() {
      widget.info.setRemark(context: context, alias: alias, description: description);
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
  NameCard content = NameCard.create(identifier, name, TransportableFile.parse(avatar));
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

  Future<bool> _refresh() async {
    var contact = widget.info;
    return await contact.refreshDocuments();
  }

  @override
  void initState() {
    super.initState();
    _reload();
    _refresh();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: widget.info.getImage(),
    title: widget.info.getNameLabel(style: _textStyle(highlighted: false)),
    subtitle: _subtitle(),
    additionalInfo: _timeLabel(widget.info.lastActiveTime),
    trailing: widget.trailing,
    onTap: () => ProfilePage.open(context, widget.info.identifier),
    onLongPress: widget.onLongPress,
  );

  TextStyle? _textStyle({bool highlighted = true}) {
    ContactStatus status = widget.info.status;
    Color? color;
    if (status == ContactStatus.invalid) {
      color = Styles.colors.invalidContactColor;
    // } else if (status == ContactStatus.init) {
    //   color = Styles.colors.invalidContactColor;
    } else if (!highlighted) {
      // don't highlight the title
      return null;
    } else if (status == ContactStatus.online) {
      color = Styles.colors.onlineContactColor;
    } else if (status == ContactStatus.active) {
      color = Styles.colors.activeContactColor;
    } else {
      return null;
    }
    return TextStyle(
      color: color,
      decoration: TextDecoration.none,
    );
  }

  Widget? _subtitle() {
    ContactRemark cr = widget.info.remark;
    String desc = cr.description;
    if (desc.isNotEmpty) {
      // show description
      desc = desc.replaceAll(RegExp(r'[\n\r]'), ' ');
      desc = desc.replaceAll(RegExp(r'\s+'), ' ');
      desc = desc.trim();
    } else if (widget.info.isNotFriend) {
      // show ID
      desc = widget.info.identifier.toString();
    } else {
      // show nothing
      return null;
    }
    return Text(desc);
  }

  Widget? _timeLabel(DateTime? time) {
    if (time == null) {
      return null;
    }
    return Text(
      TimeUtils.getTimeString(time),
      style: _textStyle(),
    );
  }

}
