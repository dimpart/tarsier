import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_box.dart';
import 'pick_contacts.dart';
import 'profile.dart';


class GroupChatDetailPage extends StatefulWidget {
  const GroupChatDetailPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, ID identifier) {
    assert(identifier.isGroup, 'ID error: $identifier');
    GroupInfo info = GroupInfo.fromID(identifier);
    info.reloadData().then((value) {
      showCupertinoDialog(
        context: context,
        builder: (context) => GroupChatDetailPage(info),
      );
    }).onError((error, stackTrace) {
      Alert.show(context, 'Error', '$error');
    });
    // query for update
    GroupManager man = GroupManager();
    // man.dataSource.getDocument(identifier);
    man.dataSource.getMembers(identifier);
  }

  @override
  State<StatefulWidget> createState() => _ChatDetailState();

}

class _ChatDetailState extends State<GroupChatDetailPage> implements lnc.Observer {
  _ChatDetailState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  final FocusNode _focusNode = FocusNode();
  String? _title;  // group name
  String? _alias;

  @override
  void dispose() {
    _focusNode.dispose();
    var nc = lnc.NotificationCenter();
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
        middle: const Text('Chat Details'),
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
        child: _participantList(context),
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
              child: _nameTextField(context),
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

      if (widget.info.identifier.type != EntityType.kStation)
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

  Widget _participantList(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 64,
      mainAxisExtent: 85,
      crossAxisSpacing: 16,
      mainAxisSpacing: 0,
    ),
    itemCount: 50,
    itemBuilder: (BuildContext ctx, int index) {
      return _plushCard(ctx, widget.info.identifier);
    },
  );

  Widget _plushCard(BuildContext context, ID fromWhere) => GestureDetector(
    onTap: () => PickContactsPage.open(
      context, fromWhere,
      onPicked: (members) => _createGroupChat(context, fromWhere, members),
    ),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          width: 64,
          height: 64,
          child: const Icon(color: Colors.grey, Styles.plushIcon,),
        ),
        const Text('aaa'),
      ],
    ),
  );

  Widget _contactCard(BuildContext context, ContactInfo info) => GestureDetector(
    onTap: () => ProfilePage.open(context, info.identifier,),
    child: Column(
      children: [
        info.getImage(width: 64, height: 64,
        ),
        SizedBox(
          width: 64,
          child: Text(info.title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _nameTextField(BuildContext context) => CupertinoTextField(
    textAlign: TextAlign.end,
    controller: TextEditingController(text: widget.info.title),
    placeholder: 'Please input group name.',
    decoration: Facade.of(context).styles.textFieldDecoration,
    style: Facade.of(context).styles.textFieldStyle,
    readOnly: !widget.info.isOwner,
    focusNode: _focusNode,
    onChanged: (value) => _title = value,
    onTapOutside: (event) => _changeName(context),
    onSubmitted: (value) => _changeName(context),
  );

  void _changeName(BuildContext context) {
    _focusNode.unfocus();
    // get alias value
    String? text = _title;
    if (text == null) {
      // nothing input
      return;
    } else {
      text = text.trim();
    }
    String title = widget.info.title;
    if (title == text) {
      Log.warning('group name not change: $title');
      return;
    }
    setState(() {
      widget.info.setRemark(context: context, alias: text);
    });
  }

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

void _createGroupChat(BuildContext ctx, ID contact, Set<ID> members) {
  // Navigator.pop(ctx);
  _doCreateGroup(contact, members).then((group) {
    if (group == null) {
      Alert.show(ctx, 'Error', 'Failed to create group');
      return;
    }
    Navigator.pop(ctx);
    Log.warning('new group: $group');
    Conversation chat = Conversation.fromID(group);
    ChatBox.open(ctx, chat);
  });
}
Future<ID?> _doCreateGroup(ID contact, Set<ID> members) async {
  GroupManager man = GroupManager();
  User? user = await man.currentUser;
  if (user == null) {
    assert(false, 'failed to get current user');
    return null;
  }
  ID me = user.identifier;
  // 1. build all members
  List<ID> allMembers = [me];
  if (contact == me) {
    assert(false, 'should not happen');
  } else {
    allMembers.add(contact);
  }
  for (ID item in members) {
    if (allMembers.contains(item)) {
      assert(false, 'should not happen');
    } else {
      allMembers.add(item);
    }
  }
  // 2. create group
  return await man.createGroup(members: allMembers);
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
