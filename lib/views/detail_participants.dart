import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_associates.dart';

class ParticipantsWidget extends StatefulWidget {
  const ParticipantsWidget(this.info, {super.key});

  final GroupInfo info;

  @override
  State<StatefulWidget> createState() => _ParticipantsState();

}

class _ParticipantsState extends State<ParticipantsWidget> implements lnc.Observer {
  _ParticipantsState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kParticipantsUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kAdministratorsUpdated);
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
        await _reload();
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
      onTap() => Alert.show(context, 'Notice', 'Please review invitations first.');
      GroupInfo info = widget.info;
      if (index == plusIndex) {
        bool canReview = info.isOwner || info.isAdmin;
        return plusCard(context, widget.info,
          onTap: canReview && info.invitations.isNotEmpty ? onTap : null,
          onPicked: (members) => _addMembers(context, widget.info, members),
        );
      } else if (index == minusIndex) {
        bool canReview = info.isOwner || info.isAdmin;
        return minusCard(context, widget.info,
          onTap: canReview && info.invitations.isNotEmpty ? onTap : null,
          onPicked: (members) => _removeMembers(context, widget.info, members),
        );
      }
      List<ContactInfo> members = ContactInfo.fromList(widget.info.members);
      return contactCard(ctx, members[index]);
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

void _addMembers(BuildContext ctx, GroupInfo groupInfo, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> newMembers = members.toList();
  _getNames(newMembers).then((names) {
    Alert.confirm(ctx, 'Confirm', 'Are you sure want to invite $names into this group?',
      okAction: () => _doAddMembers(ctx, groupInfo, newMembers),
    );
  });
}
void _doAddMembers(BuildContext ctx, GroupInfo groupInfo, List<ID> newMembers) {
  ID group = groupInfo.identifier;
  SharedGroupManager man = SharedGroupManager();
  man.inviteGroupMembers(group, newMembers).then((ok) {
    if (!ok) {
      Log.error('failed to add new members: $newMembers => $group');
    } else if (groupInfo.isOwner || groupInfo.isAdmin) {
      Log.warning('added new members: $newMembers => $group');
    } else {
      Alert.show(ctx, 'Success', 'A new invitation is sent to all administrators, now is waiting for review.');
    }
  }).catchError((error, stackTrace) {
    Log.error('failed to invite members: $groupInfo, $error');
    Alert.show(ctx, 'Error', error.toString());
  });
}

void _removeMembers(BuildContext ctx, GroupInfo groupInfo, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> expelMembers = members.toList();
  _getNames(expelMembers).then((names) {
    Alert.confirm(ctx, 'Confirm', 'Are you sure want to expel $names from this group?',
      okAction: () => _doRemoveMembers(ctx, groupInfo, expelMembers),
    );
  });
}
void _doRemoveMembers(BuildContext ctx, GroupInfo groupInfo, List<ID> expelMembers) {
  ID group = groupInfo.identifier;
  SharedGroupManager man = SharedGroupManager();
  man.expelGroupMembers(group, expelMembers).then((ok) {
    if (ok) {
      Log.warning('removed members: $expelMembers => $group');
    } else {
      Log.error('failed to remove members: $expelMembers => $group');
    }
  }).catchError((error, stackTrace) {
    Log.error('failed to remove members: $groupInfo, $error');
    Alert.show(ctx, 'Error', error.toString());
  });
}
