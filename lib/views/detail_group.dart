import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'detail_participants.dart';
import 'group_admins.dart';
import 'group_invitations.dart';


class GroupChatDetailPage extends StatefulWidget {
  const GroupChatDetailPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, ID identifier) {
    assert(identifier.isGroup, 'ID error: $identifier');
    GroupInfo? info = GroupInfo.fromID(identifier);
    info?.reloadData().then((value) {
      showCupertinoDialog(
        context: context,
        builder: (context) => GroupChatDetailPage(info),
      );
    }).onError((error, stackTrace) {
      Alert.show(context, 'Error', '$error');
    });
    // query for update
    GlobalVariable shared = GlobalVariable();
    shared.messenger?.queryDocument(identifier);
    shared.messenger?.queryMembers(identifier);
  }

  @override
  State<StatefulWidget> createState() => _ChatDetailState();

}

class _ChatDetailState extends State<GroupChatDetailPage> implements lnc.Observer {
  _ChatDetailState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
  }

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _remarkFocusNode = FocusNode();
  String? _name;  // group name
  String? _alias;

  @override
  void dispose() {
    _nameFocusNode.dispose();
    _remarkFocusNode.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kGroupHistoryUpdated);
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
    } else if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('group history updated: $identifier');
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
    return Scaffold(
      backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
        middle: const Text('Group Chat Details'),
      ),
      body: SingleChildScrollView(
        child: _body(context,
          backgroundColor: colors.sectionItemBackgroundColor,
          backgroundColorActivated: colors.sectionItemDividerColor,
          dividerColor: colors.sectionItemDividerColor,
          primaryTextColor: colors.primaryTextColor,
          secondaryTextColor: colors.tertiaryTextColor,
          dangerousTextColor: CupertinoColors.systemRed,
        ),
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

      Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(16),
        child: ParticipantsWidget(widget.info),
      ),
      const SizedBox(height: 16,),

      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Group Name
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Group Name', style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 240,
              child: widget.info.isOwner ? _nameTextField(context) : Container(
                margin: const EdgeInsets.only(right: 8),
                child: Text(widget.info.name,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ),
          ),
          /// Remark
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Remark', style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 240,
              child: _remarkTextField(context),
            ),
          ),
        ],
      ),

      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Administrators
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            leading: Icon(Styles.adminIcon, color: primaryTextColor),
            title: Text('Administrators', style: TextStyle(color: primaryTextColor)),
            additionalInfo: null,
            trailing: const CupertinoListTileChevron(),
            onTap: () => AdministratorsPage.open(context, widget.info),
          ),
          /// Invitations
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            leading: Icon(Styles.invitationIcon, color: primaryTextColor),
            title: Text('Invitations', style: TextStyle(color: primaryTextColor)),
            additionalInfo: NumberBubble.fromInt(widget.info.invitations.length),
            trailing: const CupertinoListTileChevron(),
            onTap: () => InvitationsPage.open(context, widget.info),
          ),
        ],
      ),

      // if (widget.info.identifier.type != EntityType.kStation)
        CupertinoListSection(
          backgroundColor: dividerColor,
          topMargin: 0,
          additionalDividerMargin: 32,
          children: [
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
          /// clear history
          _clearButton(context, backgroundColor: backgroundColor, textColor: dangerousTextColor),
          /// quit group
          if (widget.info.isNotOwner && widget.info.isNotAdmin/* && widget.info.isMember*/)
            _quitButton(context, backgroundColor: backgroundColor, textColor: dangerousTextColor),
        ],
      ),

      const SizedBox(height: 64,),

    ],
  );

  Widget _nameTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: TextEditingController(text: widget.info.name),
    placeholder: 'Please input group name.',
    decoration: Facade.of(context).styles.textFieldDecoration,
    style: Facade.of(context).styles.textFieldStyle,
    readOnly: !widget.info.isOwner,
    focusNode: _nameFocusNode,
    onChanged: (value) => _name = value,
    onTapOutside: (event) => _changeName(context),
    onSubmitted: (value) => _changeName(context),
  );

  void _changeName(BuildContext context) {
    _nameFocusNode.unfocus();
    // get group name
    String? text = _name;
    String name = widget.info.name;
    if (text == null) {
      // nothing input
      return;
    } else if (text == name) {
      Log.warning('group name not change: $name');
      return;
    }
    setState(() {
      widget.info.setGroupName(context: context, name: text);
    });
  }

  Widget _remarkTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: TextEditingController(text: widget.info.remark.alias),
    placeholder: 'Please input alias.',
    decoration: Facade.of(context).styles.textFieldDecoration,
    style: Facade.of(context).styles.textFieldStyle,
    focusNode: _remarkFocusNode,
    onChanged: (value) => _alias = value,
    onTapOutside: (event) => _changeAlias(context),
    onSubmitted: (value) => _changeAlias(context),
  );

  void _changeAlias(BuildContext context) {
    _remarkFocusNode.unfocus();
    // get alias value
    String? text = _alias;
    ContactRemark remark = widget.info.remark;
    if (text == null) {
      // nothing input
      return;
    } else if (remark.alias == text) {
      Log.warning('group alias not change: $remark');
      return;
    }
    setState(() {
      widget.info.setRemark(context: context, alias: text);
    });
  }

  Widget _clearButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Clear History', Styles.clearChatIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _clearHistory(context, widget.info),
      );

  Widget _quitButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Quit Group', Styles.quitIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => widget.info.quit(context: context),
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

void _clearHistory(BuildContext ctx, GroupInfo info) {
  String msg = 'Are you sure want to clear chat history of this group?'
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
