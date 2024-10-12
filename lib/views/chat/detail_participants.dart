import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import 'associates.dart';


class ParticipantsWidget extends StatefulWidget {
  const ParticipantsWidget(this.info, {super.key, required this.maxItems});

  final GroupInfo info;
  final int maxItems;

  @override
  State<StatefulWidget> createState() => _ParticipantsState();

}

class _ParticipantsState extends State<ParticipantsWidget> with Logging implements lnc.Observer {
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
        logInfo('document updated: $identifier');
        await _reload();
      }
    } else if (name == NotificationNames.kParticipantsUpdated) {
      ID? identifier = userInfo?['ID'];
      List<ID>? members = userInfo?['members'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        logInfo('participants updated: $identifier, $members');
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
        logInfo('members updated: $identifier, $members');
        await _reload();
      }
    } else if (name == NotificationNames.kAdministratorsUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        logInfo('group history updated: $identifier');
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

  // @override
  // void initState() {
  //   super.initState();
  //   _reload();
  // }

  bool get canInvite => widget.info.isMember;
  bool get canExpel => widget.info.isOwner || widget.info.isAdmin;

  int get itemCount {
    int count = widget.info.members.length;
    if (canExpel) {
      count += 2;
    } else if (canInvite) {
      count += 1;
    }
    if (0 < widget.maxItems && widget.maxItems < count) {
      count = widget.maxItems;
    }
    return count;
  }

  int get minusIndex => canExpel ? itemCount - 1 : -1;  // the last item
  int get plusIndex => canExpel ? itemCount - 2         // before last item
      : canInvite ? itemCount - 1 : -1;                 // the last item

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
      onTap() => Alert.show(context, 'Notice', 'Please review invitations'.tr);
      GroupInfo info = widget.info;
      if (index == plusIndex) {
        bool canReview = info.isOwner || info.isAdmin;
        return plusCard(context, info,
          onTap: canReview && info.invitations.isNotEmpty ? onTap : null,
          onPicked: (members) => _addMembers(context, info, members),
        );
      } else if (index == minusIndex) {
        bool canReview = info.isOwner || info.isAdmin;
        return minusCard(context, info,
          onTap: canReview && info.invitations.isNotEmpty ? onTap : null,
          onPicked: (members) => _removeMembers(context, info, members),
        );
      }
      List<ContactInfo> members = ContactInfo.fromList(info.members);
      logInfo('show group members: ${info.identifier}, ${members.length}');
      return contactCard(ctx, members[index]);
    },
  );

}

void _addMembers(BuildContext ctx, GroupInfo groupInfo, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> newMembers = members.toList();
  previewMembers(newMembers).then((body) => Alert.confirm(ctx, 'Confirm Add',
    body,
    okAction: () => _doAddMembers(ctx, groupInfo, newMembers),
  ));
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
      Alert.show(ctx, 'Success', 'Invitation sent'.tr);
    }
  }).catchError((error, stackTrace) {
    Log.error('failed to invite members: $groupInfo, $error');
    Alert.show(ctx, 'Error', '$error');
  });
}

void _removeMembers(BuildContext ctx, GroupInfo groupInfo, Set<ID> members) {
  if (members.isEmpty) {
    return;
  }
  List<ID> expelMembers = members.toList();
  previewMembers(expelMembers).then((body) => Alert.confirm(ctx, 'Confirm Delete',
    body,
    okAction: () => _doRemoveMembers(ctx, groupInfo, expelMembers),
  ));
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
    Alert.show(ctx, 'Error', '$error');
  });
}
