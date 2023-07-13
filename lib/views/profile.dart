import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_box.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage(this.info, this.fromChat, {super.key});

  final ContactInfo info;
  final ID? fromChat;

  static void open(BuildContext context, ID identifier, {ID? fromChat}) {
    ContactInfo info = ContactInfo.fromID(identifier);
    info.reloadData().then((value) {
      showCupertinoDialog(
        context: context,
        builder: (context) => ProfilePage(info, fromChat),
      );
    }).onError((error, stackTrace) {
      Alert.show(context, 'Error', '$error');
    });
    // query for update
    GlobalVariable shared = GlobalVariable();
    shared.messenger?.queryDocument(identifier);
    if (identifier.isGroup) {
      shared.messenger?.queryMembers(identifier);
    }
  }

  static Widget cell(ContactInfo info, {GestureLongPressCallback? onLongPress}) =>
      _ProfileTableCell(info, onLongPress: onLongPress);

  @override
  State<StatefulWidget> createState() => _ProfileState();

}

class _ProfileState extends State<ProfilePage> implements lnc.Observer {
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
        Log.info('document updated: $identifier');
        if (mounted) {
          setState(() {
            // update name in title
          });
        }
      }
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      if (contact == widget.info.identifier) {
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
      Log.error('notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    var colors = Facade.of(context).colors;
    var styles = Facade.of(context).styles;
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
              style: styles.titleTextStyle,
            ),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: SingleChildScrollView(
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
            title: Text('Remark', style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 160,
              child: _remarkTextField(context),
            ),
          ),
        ],
      ),

      if (widget.info.identifier.type != EntityType.kStation)
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
            leading: Icon(Styles.blockListIcon, color: primaryTextColor),
            title: Text('Block Messages', style: TextStyle(color: primaryTextColor)),
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
            leading: Icon(Styles.muteListIcon, color: primaryTextColor),
            title: Text('Mute Notifications', style: TextStyle(color: primaryTextColor)),
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
          if (!widget.info.isFriend)
            _addButton(context, backgroundColor: backgroundColor, textColor: primaryTextColor),
          /// send message
          if (widget.info.isFriend/* && !widget.info.isBlocked*/)
            _sendButton(context, backgroundColor: backgroundColor, textColor: primaryTextColor),
          /// clear history
          if (widget.info.isFriend && widget.fromChat != null)
            _clearButton(context, backgroundColor: backgroundColor, textColor: dangerousTextColor),
          /// delete contact
          if (widget.info.isFriend && widget.fromChat == null)
            _deleteButton(context, backgroundColor: backgroundColor, textColor: dangerousTextColor),
        ],
      ),

      const SizedBox(height: 64,),

    ],
  );

  Widget _avatarImage(BuildContext context) =>
      widget.info.getImage(width: 256, height: 256, onTap: () {
        GlobalVariable shared = GlobalVariable();
        shared.facebook.getAvatar(widget.info.identifier).then((pair) {
          String? path = pair.first;
          if (path == null) {
            Log.error('avatar image not found: ${widget.info.identifier}');
          } else {
            previewImage(context, path);
          }
        });
      });

  Widget _idLabel(BuildContext context) => Expanded(
    flex: 9,
    child: SelectableText(widget.info.identifier.toString(),
      textAlign: TextAlign.right,
      minLines: 1,
      maxLines: 2,
      style: Facade.of(context).styles.identifierTextStyle,
    ),
  );

  Widget _remarkTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: TextEditingController(text: widget.info.remark.alias),
    placeholder: 'Please input alias.',
    decoration: Facade.of(context).styles.textFieldDecoration,
    style: Facade.of(context).styles.textFieldStyle,
    focusNode: _focusNode,
    onChanged: (value) => _alias = value,
    onTapOutside: (event) => _changeAlias(context),
    onSubmitted: (value) => _changeAlias(context),
  );

  void _changeAlias(BuildContext context) {
    _focusNode.unfocus();
    // get alias value
    String? text = _alias;
    if (text == null) {
      // nothing input
      return;
    } else {
      text = text.trim();
    }
    ContactRemark remark = widget.info.remark;
    if (remark.alias == text) {
      Log.warning('alias not change: $remark');
      return;
    }
    setState(() {
      widget.info.setRemark(context: context, alias: text);
    });
  }

  Widget _addButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Add Contact', Styles.addFriendIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => widget.info.add(context: context),
      );

  Widget _sendButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Send Message', Styles.sendMsgIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _sendMessage(context, widget.info, widget.fromChat),
      );

  Widget _clearButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Clear History', Styles.clearChatIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _clearHistory(context, widget.info),
      );

  Widget _deleteButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Delete Contact', Styles.deleteIcon, textColor: textColor, backgroundColor: backgroundColor,
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
    Navigator.pop(ctx);
  } else {
    ChatBox.open(ctx, info);
  }
}

void _clearHistory(BuildContext ctx, ContactInfo info) {
  String name = info.identifier.isUser ? 'this friend' : 'this group';
  String msg = 'Are you sure want to clear chat history of $name?'
      ' This action cannot be restored.';
  Alert.confirm(ctx, 'Confirm', msg,
    okAction: () => _doClear(ctx, info.identifier),
  );
}
void _doClear(BuildContext ctx, ID chat) {
  Amanuensis clerk = Amanuensis();
  clerk.clearConversation(chat).then((ok) {
    if (ok) {
      Navigator.pop(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to clear chat history');
    }
  });
}

//
//  Profile Table Cell
//

class _ProfileTableCell extends StatefulWidget {
  const _ProfileTableCell(this.info, {this.onLongPress});

  final ContactInfo info;
  final GestureLongPressCallback? onLongPress;

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
      ID? did = userInfo?['ID'];
      assert(did != null, 'notification error: $notification');
      if (did == widget.info.identifier) {
        Log.info('document updated: $did');
        await _reload();
      }
    } else if (name == NotificationNames.kRemarkUpdated) {
      ID? cid = userInfo?['contact'];
      assert(cid != null, 'notification error: $notification');
      if (cid == widget.info.identifier) {
        Log.info('remark updated: $cid');
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
    title: Text(widget.info.title),
    subtitle: Text(widget.info.identifier.toString()),
    onTap: () => ProfilePage.open(context, widget.info.identifier),
    onLongPress: widget.onLongPress,
  );

}
