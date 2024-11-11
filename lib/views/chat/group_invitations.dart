import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../contact/profile.dart';


class InvitationsPage extends StatefulWidget {
  const InvitationsPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, GroupInfo info) => showPage(
    context: context,
    builder: (context) => InvitationsPage(info),
  );

  @override
  State<StatefulWidget> createState() => _InvitationsState();
}

class _InvitationsState extends State<InvitationsPage> implements lnc.Observer {
  _InvitationsState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kGroupHistoryUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kAdministratorsUpdated);
    nc.removeObserver(this, NotificationNames.kGroupHistoryUpdated);
    super.dispose();
  }

  late final _InvitationsAdapter _adapter = _InvitationsAdapter(widget.info);

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kGroupHistoryUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group history updated: $chat');
        await _reload();
      }
    } else if (name == NotificationNames.kAdministratorsUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('administrators updated: $chat');
        await _reload();
      }
    } else {
      assert(false, 'notification error: $name');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Invitations'.tr),
      trailing: _confirmButton(context),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

  Widget? _confirmButton(BuildContext context) {
    GroupInfo info = widget.info;
    if (!_adapter.canReview) {
      Log.info('only group owner/administrator can review invitations: $info');
      return null;
    } else if (info.invitations.isEmpty) {
      Log.info('invitation not found: $info');
      return null;
    }
    return TextButton(
      child: Text('Confirm'.tr, style: const TextStyle(
        fontWeight: FontWeight.bold,
        color: CupertinoColors.systemRed,
      ),),
      onPressed: () {
        List<ID> newMembers = _getNewMembers(info.invitations, _adapter.denied);
        // check members
        if (newMembers.isEmpty) {
          Widget body = Text('Are you sure want to reject all these invitations?'.tr);
          Alert.confirm(context, 'Confirm Delete', body,
            okAction: () => _refreshMembers(newMembers, info).then((ok) {
              if (ok) {
                closePage(context);
              }
            }),
          );
        } else {
          previewMembers(newMembers).then((body) => Alert.confirm(context, 'Confirm Add',
            body,
            okAction: () => _refreshMembers(newMembers, info).then((ok) {
              if (ok) {
                closePage(context);
              }
            }),
          ));
        }
      },
    );
  }
}

List<ID> _getNewMembers(List<Invitation> invitations, Set<ID> denied) {
  List<ID> newMembers = [];
  for (Invitation item in invitations) {
    if (denied.contains(item.member) || newMembers.contains(item.member)) {
      continue;
    }
    newMembers.add(item.member);
  }
  return newMembers;
}
Future<bool> _refreshMembers(List<ID> newMembers, GroupInfo groupInfo) async {
  ID group = groupInfo.identifier;
  assert(group.isGroup, 'group ID error: $group');
  SharedGroupManager man = SharedGroupManager();
  List<ID> members = await man.getMembers(group);
  if (members.isEmpty) {
    throw Exception('failed to get members for group: $group');
  }
  List<ID> allMembers = [...members];
  for (ID item in newMembers) {
    if (allMembers.contains(item)) {
      Log.warning('skip member: $item');
      continue;
    }
    allMembers.add(item);
  }
  return await man.resetGroupMembers(group, allMembers);
}

class _InvitationsAdapter with SectionAdapterMixin {
  _InvitationsAdapter(this.info);

  final GroupInfo info;

  final Set<ID> denied = HashSet();

  bool setAccepted(ID user) => denied.remove(user);
  bool setDenied(ID user) => denied.add(user);

  bool isAccepted(ID user) => !denied.contains(user);
  bool isDenied(ID user) => denied.contains(user);

  bool get canReview => info.isOwner || info.isAdmin;

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'Invitations::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(prompt,
            style: Styles.sectionFooterTextStyle,
          )),
        ],
      ),
    );
  }

  @override
  int numberOfItems(int section) => info.invitations.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Invitation> invitations = info.invitations;
    if (indexPath.item >= invitations.length) {
      Log.error('out of range: ${invitations.length}, $indexPath');
      return const Text('');
    }
    Invitation item = invitations[indexPath.item];
    Log.warning('show item: $item');
    return _InvitationCell(item, this);
  }

}

/// TableCell for Invitation
class _InvitationCell extends StatefulWidget {
  const _InvitationCell(this.invitation, this.adapter);

  final Invitation invitation;
  final _InvitationsAdapter adapter;

  bool setAccepted() => adapter.setAccepted(invitation.member);
  bool setDenied() => adapter.setDenied(invitation.member);

  bool get isAccepted => adapter.isAccepted(invitation.member);
  bool get isDenied => adapter.isDenied(invitation.member);

  bool get canReview => adapter.canReview;

  @override
  State<StatefulWidget> createState() => _InvitationCellState();

}

const String _kInvitationStatusRefresh = 'InvitationStatusRefresh';

class _InvitationCellState extends State<_InvitationCell> implements lnc.Observer {
  _InvitationCellState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, _kInvitationStatusRefresh);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, _kInvitationStatusRefresh);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    if (name == _kInvitationStatusRefresh) {
      Log.info('invitation status refresh: ${widget.invitation}');
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    // decoration: BoxDecoration(
    //   border: Border.all(color: CupertinoColors.systemGrey, width: 1),
    // ),
    child: _body(),
  );

  Widget _body() {
    ContactInfo? senderInfo = ContactInfo.fromID(widget.invitation.sender);
    ContactInfo? memberInfo = ContactInfo.fromID(widget.invitation.member);
    DateTime? time = widget.invitation.time;
    return Row(
      children: [
        /// new member
        if (memberInfo != null)
          _avatar(context, memberInfo),
        if (memberInfo != null)
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              memberInfo.getNameLabel(true),
              // Text(memberInfo.identifier.toString(),
              //   maxLines: 1,
              //   overflow: TextOverflow.ellipsis,
              //   style: const TextStyle(
              //     color: CupertinoColors.systemGrey,
              //   ),
              // ),
            ],
          )),
        /// invite time
        Container(
          padding: const EdgeInsets.only(left: 8, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (time != null)
                Text(TimeUtils.getTimeString(time), style: const TextStyle(
                    color: CupertinoColors.systemGrey
                ),),
              Text('Invited by'.tr),
            ],
          ),
        ),
        /// sender
        if (senderInfo != null)
          _avatar(context, senderInfo),
        /// switch
        if (widget.canReview)
        CupertinoSwitch(
          value: widget.isAccepted,
          onChanged: widget.canReview ? (bool value) {
            if (value) {
              widget.setAccepted();
            } else {
              widget.setDenied();
            }
            var nc = lnc.NotificationCenter();
            nc.postNotification(_kInvitationStatusRefresh, this);
          } : null,
        ),
      ],
    );
  }

  Widget _avatar(BuildContext context, ContactInfo info, {
    double width = 48, double height = 48, BoxFit? fit,
  }) => GestureDetector(
    onTap: () => ProfilePage.open(context, info.identifier,),
    child: Container(
      padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
      child: info.getImage(width: width, height: height, fit: fit),
    ),
  );

}
