import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../service/report.dart';
import 'detail_participants.dart';
import 'group_admins.dart';
import 'group_invitations.dart';
import 'group_members.dart';


class GroupChatDetailPage extends StatefulWidget {
  const GroupChatDetailPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, ID identifier) {
    assert(identifier.isGroup, 'ID error: $identifier');
    GroupInfo? info = GroupInfo.fromID(identifier);
    info?.reloadData().then((value) {
      if (context.mounted) {
        showPage(
          context: context,
          builder: (context) => GroupChatDetailPage(info),
        );
      }
    }).onError((error, stackTrace) {
      if (context.mounted) {
        Alert.show(context, 'Error', '$error');
      }
    });
  }

  @override
  State<StatefulWidget> createState() => _ChatDetailState();

}

class _ChatDetailState extends State<GroupChatDetailPage> implements lnc.Observer {
  _ChatDetailState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
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
    nc.removeObserver(this, NotificationNames.kAdministratorsUpdated);
    nc.removeObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
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
        await _reload();
      }
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? identifier = userInfo?['ID'];
      if (identifier == widget.info.identifier) {
        Log.info('group members updated: $identifier');
        await _reload();
      }
    } else if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('group history updated: $identifier');
        await _reload();
      }
    } else if (name == NotificationNames.kAdministratorsUpdated) {
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
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: Styles.colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Styles.colors.appBardBackgroundColor,
        middle: Text('Group Chat Details (@count)'.trParams({
          'count': widget.info.members.length.toString(),
        }), style: Styles.titleTextStyle),
      ),
      body: buildScrollView(
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
    );
  }

  bool _hasMoreMembers() {
    GroupInfo info = widget.info;
    bool canInvite = info.isMember;
    bool canExpel = info.isOwner || info.isAdmin;
    int count = info.members.length;
    if (canExpel) {
      count += 2;
    } else if (canInvite) {
      count += 1;
    }
    return 0 < _maxItems && _maxItems < count;
  }

  final int _maxItems = 20;

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
        child: ParticipantsWidget(widget.info, maxItems: _maxItems),
      ),
      if (_hasMoreMembers())
        Container(
          color: backgroundColor,
          padding: const EdgeInsets.only(bottom: 16),
          child: GestureDetector(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('View More Members'.tr),
                const CupertinoListTileChevron(),
              ],
            ),
            onTap: () => MembersPage.open(context, widget.info),
          ),
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
            title: Text('Group Name'.tr, style: TextStyle(color: primaryTextColor)),
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
            title: Text('Remark'.tr, style: TextStyle(color: primaryTextColor)),
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
            leading: Icon(AppIcons.adminIcon, color: primaryTextColor),
            title: Text('Administrators'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: null,
            trailing: const CupertinoListTileChevron(),
            onTap: () => AdministratorsPage.open(context, widget.info),
          ),
          /// Invitations
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            leading: Icon(AppIcons.invitationIcon, color: primaryTextColor),
            title: Text('Invitations'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: NumberBubble.fromInt(widget.info.invitations.length),
            trailing: const CupertinoListTileChevron(),
            onTap: () => InvitationsPage.open(context, widget.info),
          ),
        ],
      ),

      // if (widget.info.identifier.type != EntityType.STATION)
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
          /// clear history
          _clearButton(context, backgroundColor: backgroundColor, textColor: dangerousTextColor),
          /// report
          _reportButton(context, textColor: dangerousTextColor, backgroundColor: backgroundColor),
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
    placeholder: 'Please input group name'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
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
    placeholder: 'Please input alias'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
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
      _button('Clear History'.tr, AppIcons.clearChatIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _clearHistory(context, widget.info),
      );

  Widget _reportButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Report'.tr, AppIcons.reportIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _reportGroupChat(context, widget.info),
      );

  Widget _quitButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Quit Group'.tr, AppIcons.quitIcon, textColor: textColor, backgroundColor: backgroundColor,
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

void _reportGroupChat(BuildContext context, GroupInfo info) {
  String text = 'Report Object: "@title"\n'
      'Group ID: @gid\n'
      '\n'
      'Reason: ...\n'
      '(Screenshots will be attached below)'.trParams({
    'title': info.title,
    'gid': info.identifier.toString(),
  });
  // open chat box to report
  CustomerService.report(context, text);
}

void _clearHistory(BuildContext ctx, GroupInfo info) {
  Alert.confirm(ctx, 'Confirm', 'Sure to clear chat history of this group?'.tr,
    okAction: () => _doClear(ctx, info.identifier),
  );
}
void _doClear(BuildContext ctx, ID chat) {
  Amanuensis clerk = Amanuensis();
  clerk.clearConversation(chat).then((ok) {
    if (!ctx.mounted) {
      Log.warning('context unmounted: $ctx');
    } else if (ok) {
      closePage(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to clear chat history'.tr);
    }
  });
}
