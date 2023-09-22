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
          child: const Icon(color: CupertinoColors.systemGrey, Styles.plusIcon,),
        ),
      ],
    ),
  );

  static Widget minusCard(BuildContext context, ID fromWhere, {required PickContactsCallback onPicked}) => GestureDetector(
    onTap: () => _getMembers(fromWhere).then((members) {
      if (members == null) {
        Alert.show(context, 'Error', 'Group not ready');
      } else {
        Log.info('candidates: $members');
        MemberPicker.open(context, members, onPicked: onPicked);
      }
    }),
    child: Column(
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: CupertinoColors.systemGrey, width: 1, style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          width: 64,
          height: 64,
          child: const Icon(color: CupertinoColors.systemGrey, Styles.minusIcon,),
        ),
      ],
    ),
  );
  static Future<Set<ID>?> _getMembers(ID group) async {
    GroupManager man = GroupManager();
    ID? owner = await man.dataSource.getOwner(group);
    if (owner == null) {
      return null;
    }
    List<ID> members = await man.dataSource.getMembers(group);
    if (members.isEmpty) {
      return null;
    }
    Set<ID> candidates = members.toSet();
    candidates.remove(owner);
    List<ID> admins = await man.dataSource.getAdministrators(group);
    for (ID item in admins) {
      candidates.remove(item);
    }
    return candidates;
  }

  static Widget contactCard(BuildContext context, ContactInfo info) => GestureDetector(
    onTap: () => ProfilePage.open(context, info.identifier,),
    child: Column(
      children: [
        info.getImage(width: 64, height: 64,),
        SizedBox(
          width: 64,
          child: info.getNameLabel(
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

  bool get canInvite => widget.info.isMember;
  bool get canExpel => widget.info.isOwner || widget.info.isAdmin;

  int get itemCount => widget.info.members.length + (
      canExpel ? 2 : (canInvite ? 1 : 0)
  );

  int get plusIndex => canInvite ? widget.info.members.length : -1;
  int get minusIndex => canExpel ? plusIndex + 1 : -1;

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
    itemCount: itemCount,
    itemBuilder: (BuildContext ctx, int index) {
      if (index == plusIndex) {
        return ParticipantsWidget.plusCard(context, widget.info.identifier,
          onPicked: (members) => _addMembers(context, widget.info.identifier, members),
        );
      } else if (index == minusIndex) {
        return ParticipantsWidget.minusCard(context, widget.info.identifier,
          onPicked: (members) => _removeMembers(context, widget.info.identifier, members),
        );
      }
      List<ContactInfo> members = widget.info.members;
      return ParticipantsWidget.contactCard(ctx, members[index]);
    },
  );

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

void _addMembers(BuildContext ctx, ID group, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> newMembers = members.toList();
  _getNames(newMembers).then((names) {
    Alert.confirm(ctx, 'Confirm', 'Are you sure want to invite $names into this group?',
      okAction: () => _doAddMembers(group, newMembers).catchError((error, stackTrace) {
        Log.error('failed to add members: $group, $error');
        Alert.show(ctx, 'Error', error.toString());
        return false;
      }),
    );
  });
}
Future<bool> _doAddMembers(ID group, List<ID> newMembers) async {
  GroupManager man = GroupManager();
  bool ok = await man.inviteGroupMembers(group, newMembers).catchError((error, stackTrace) {
    throw error;
  });
  if (ok) {
    Log.warning('added new members: $newMembers => $group');
  } else {
    Log.error('failed to add new members: $newMembers => $group');
  }
  return ok;
}

void _removeMembers(BuildContext ctx, ID group, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> expelMembers = members.toList();
  _getNames(expelMembers).then((names) {
    Alert.confirm(ctx, 'Confirm', 'Are you sure want to expel $names from this group?',
      okAction: () => _doRemoveMembers(group, expelMembers).catchError((error, stackTrace) {
        Log.error('failed to remove members: $group, $error');
        Alert.show(ctx, 'Error', error.toString());
        return false;
      }),
    );
  });
}
Future<bool> _doRemoveMembers(ID group, List<ID> expelMembers) async {
  GroupManager man = GroupManager();
  bool ok = await man.expelGroupMembers(group, expelMembers).catchError((error, stackTrace) {
    throw error;
  });
  if (ok) {
    Log.warning('removed members: $expelMembers => $group');
  } else {
    Log.error('failed to remove members: $expelMembers => $group');
  }
  return ok;
}
