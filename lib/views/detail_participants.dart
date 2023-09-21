import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'pick_contacts.dart';
import 'profile.dart';

class ParticipantsWidget extends StatefulWidget {
  const ParticipantsWidget(this.info, {super.key});

  final GroupInfo info;

  static Widget plusCard(BuildContext context, ID fromWhere, {required PickContactsCallback onPicked}) => GestureDetector(
    onTap: () => PickContactsPage.open(
      context, fromWhere,
      onPicked: onPicked,
    ),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey, width: 1, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          width: 64,
          height: 64,
          child: const Icon(color: CupertinoColors.systemGrey, Styles.plushIcon,),
        ),
      ],
    ),
  );

  static Widget contactCard(BuildContext context, ContactInfo info) => GestureDetector(
    onTap: () => ProfilePage.open(context, info.identifier,),
    child: Column(
      children: [
        info.getImage(width: 64, height: 64,),
        SizedBox(
          width: 64,
          child: NameLabel(info.identifier,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );

  @override
  State<StatefulWidget> createState() => _ParticipantsState();

}

class _ParticipantsState extends State<ParticipantsWidget> implements lnc.Observer {
  _ParticipantsState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kParticipantsUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
    nc.removeObserver(this, NotificationNames.kParticipantsUpdated);
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
    } else if (name == NotificationNames.kParticipantsUpdated) {
      ID? identifier = userInfo?['ID'];
      List<ID>? members = userInfo?['members'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('participants updated: $identifier, $members');
        if (mounted) {
          setState(() {
            // update name in title
          });
        }
      }
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? identifier = userInfo?['ID'];
      List<ID>? members = userInfo?['members'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('members updated: $identifier, $members');
        if (mounted) {
          setState(() {
            // update name in title
          });
        }
        _reload();
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

  // @override
  // void initState() {
  //   super.initState();
  //   _reload();
  // }

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 64,
      mainAxisExtent: 85,
      crossAxisSpacing: 16,
      mainAxisSpacing: 8,
    ),
    itemCount: widget.info.members.length + 1,
    itemBuilder: (BuildContext ctx, int index) {
      if (index == widget.info.members.length) {
        return ParticipantsWidget.plusCard(context, widget.info.identifier,
          onPicked: (members) => _addMembers(context, widget.info.identifier, members),
        );
      }
      List<ContactInfo> members = widget.info.members;
      return ParticipantsWidget.contactCard(ctx, members[index]);
    },
  );

}

void _addMembers(BuildContext ctx, ID group, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> newMembers = members.toList();
  _getNames(newMembers).then((names) {
    Alert.confirm(ctx, 'Confirm', 'Are you sure want to invite $names into this group?',
      okAction: () => _doAddMembers(group, newMembers),
    );
  });
}
Future<String> _getNames(List<ID> members) async {
  assert(members.isNotEmpty, 'members should not be empty here');
  GlobalVariable shared = GlobalVariable();
  String nickname = await shared.facebook.getName(members.first);
  String text = nickname;
  for (int i = 1; i < members.length; ++i) {
    nickname = await shared.facebook.getName(members[i]);
    text += ', $nickname';
  }
  return text;
}
Future<bool> _doAddMembers(ID group, List<ID> newMembers) async {
  GroupManager man = GroupManager();
  bool ok = await man.inviteGroupMembers(group, newMembers);
  if (ok) {
    Log.warning('added new members: $newMembers => $group');
  } else {
    Log.error('failed to add new members: $newMembers => $group');
  }
  return ok;
}
