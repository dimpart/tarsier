import 'dart:collection';

import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:flutter/material.dart';

import 'chat_box.dart';
import 'profile.dart';

Widget contactCard(BuildContext context, ContactInfo info, {double width = 64, double height = 64}) => GestureDetector(
  onTap: () => ProfilePage.open(context, info.identifier,),
  child: Column(
    children: [
      info.getImage(width: width, height: height,),
      SizedBox(
        width: width,
        child: info.getNameLabel(
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
);

Widget plusButton(BuildContext context) => IconButton(
  iconSize: 16,
  onPressed: () => _getContacts().then((members) {
    if (members == null) {
      Alert.show(context, 'Error', 'Failed to add members');
    } else {
      Log.info('candidates: $members');
      MemberPicker.open(context, members,
        onPicked: (members) => _newChat(context, members.toList()),
      );
    }
  }),
  icon: const Icon(Styles.plusIcon),
);

Widget plusCard(BuildContext context, Conversation fromWhere, {MemberPickerCallback? onPicked}) => GestureDetector(
  onTap: () => _getContacts(fromWhere).then((members) {
    if (members == null) {
      Alert.show(context, 'Error', 'Failed to add members');
    } else if (fromWhere.isUser) {
      Log.info('candidates: $members');
      assert(fromWhere is ContactInfo, 'contact info error: $fromWhere');
      MemberPicker.open(context, members, onPicked: (members) {
        List<ID> array = members.toList();
        array.insert(0, fromWhere.identifier);
        _newChat(context, array);
      });
    } else if (onPicked == null) {
      assert(false, 'params error: $fromWhere');
    } else {
      Log.info('candidates: $members');
      assert(fromWhere is GroupInfo, 'group info error: $fromWhere');
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
        child: const Icon(color: CupertinoColors.systemGrey, Styles.plusIcon,),
      ),
    ],
  ),
);

Widget minusCard(BuildContext context, GroupInfo fromWhere, {required MemberPickerCallback onPicked}) => GestureDetector(
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

Future<Set<ID>?> _getContacts([Conversation? fromWhere]) async {
  GlobalVariable shared = GlobalVariable();
  User? user = await shared.facebook.currentUser;
  if (user == null) {
    assert(false, 'failed to get current user');
    return null;
  }
  List<ID> contacts = await shared.facebook.getContacts(user.identifier);
  if (contacts.isEmpty) {
    assert(false, 'failed to get contacts for user: $user');
    return HashSet();
  }
  // get old members
  List<ID> fixed;
  if (fromWhere == null) {
    fixed = [user.identifier];
  } else if (fromWhere.isUser) {
    fixed = [user.identifier, fromWhere.identifier];
  } else if (fromWhere is GroupInfo) {
    List<ContactInfo> members = ContactInfo.fromList(fromWhere.members);
    if (members.isEmpty) {
      assert(false, 'failed to get members: $fromWhere');
      return null;
    }
    fixed = [];
    for (ContactInfo item in members) {
      fixed.add(item.identifier);
    }
  } else {
    assert(false, 'conversation error: $fromWhere');
    return null;
  }
  Set<ID> candidates = contacts.toSet();
  for (ID item in fixed) {
    candidates.remove(item);
  }
  return candidates;
}
Future<Set<ID>?> _getMembers(GroupInfo info) async {
  // get members
  List<ContactInfo> contacts = ContactInfo.fromList(info.members);
  if (contacts.isEmpty) {
    assert(false, 'group info error: $info');
    return null;
  }
  Set<ID> candidates = HashSet();
  for (ContactInfo item in contacts) {
    candidates.add(item.identifier);
  }
  // get owner, admin
  GroupManager man = GroupManager();
  ID? owner = await man.dataSource.getOwner(info.identifier);
  List<ID> admins = await man.dataSource.getAdministrators(info.identifier);
  if (owner == null) {
    assert(false, 'failed to get group owner: $info');
    return null;
  }
  // remove owner & admin
  candidates.remove(owner);
  for (ID member in admins) {
    candidates.remove(member);
  }
  return candidates;
}

void _newChat(BuildContext context, List<ID> members) {
  if (members.isEmpty) {
    Log.warning('members empty');
  } else if (members.length == 1) {
    ContactInfo? info = ContactInfo.fromID(members.first);
    if (info == null) {
      assert(false, 'failed to get contact info: $members');
    } else {
      ChatBox.open(context, info);
    }
  } else {
    GroupManager man = GroupManager();
    man.createGroup(members: members).then((group) {
      if (group == null) {
        Alert.show(context, 'Error', 'Failed to create group');
        return;
      }
      Log.warning('new group: $group');
      Conversation? chat = Conversation.fromID(group);
      chat?.reloadData().then((nothing) => ChatBox.open(context, chat));
    });
  }
}
