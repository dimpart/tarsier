import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'pick_contacts.dart';
import 'profile.dart';


class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage(this.info, this.fromChat, {super.key});

  final ContactInfo info;
  final ID? fromChat;

  static void open(BuildContext context, ID identifier, {ID? fromChat}) {
    ContactInfo info = ContactInfo.fromID(identifier);
    info.reloadData().then((value) {
      showCupertinoDialog(
        context: context,
        builder: (context) => ChatDetailPage(info, fromChat),
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

  @override
  State<StatefulWidget> createState() => _ChatDetailState();

}

class _ChatDetailState extends State<ChatDetailPage> implements lnc.Observer {
  _ChatDetailState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  final FocusNode _focusNode = FocusNode();

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
    return Scaffold(
      backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
        middle: const Text('Chat Details'),
      ),
      body: _body(context,
        backgroundColor: colors.sectionItemBackgroundColor,
        backgroundColorActivated: colors.sectionItemDividerColor,
        dividerColor: colors.sectionItemDividerColor,
        primaryTextColor: colors.primaryTextColor,
        secondaryTextColor: colors.tertiaryTextColor,
        dangerousTextColor: CupertinoColors.systemRed,
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
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: _participantList(context),
      ),
      const SizedBox(height: 16,),

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
        ],
      ),

      const SizedBox(height: 64,),

    ],
  );

  Widget _participantList(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 32),
    child: Row(
      children: [
        _contactCard(context, widget.info),
        const SizedBox(width: 16,),
        _plushCard(context, widget.info.identifier),
      ],
    ),
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
        const Text(''),
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
          child: Text(info.name,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  Widget _clearButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('  Clear History', Styles.clearChatIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _clearHistory(context, widget.info),
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
  members.add(contact);
  GroupManager man = GroupManager();
  man.createGroup(members: members).then((group) {
    if (group == null) {
      Alert.show(ctx, 'Error', 'Failed to create group');
    } else {
      Alert.show(ctx, 'Success', 'New group: $group');
    }
  });
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
