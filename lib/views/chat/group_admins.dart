import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../contact/profile.dart';


class AdministratorsPage extends StatefulWidget {
  const AdministratorsPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, GroupInfo info) => showPage(
    context: context,
    builder: (context) => AdministratorsPage(info),
  );

  @override
  State<StatefulWidget> createState() => _AdministratorsState();
}

class _AdministratorsState extends State<AdministratorsPage> implements lnc.Observer {
  _AdministratorsState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kAdministratorsUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kAdministratorsUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    // update when leaved this page
    _updateAdmin(widget.info);
    super.dispose();
  }

  late final _ContactDataSource _dataSource = _ContactDataSource();
  late final _ContactListAdapter _adapter = _ContactListAdapter(widget.info, dataSource: _dataSource);

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group document updated: $chat');
        await _reload();
      }
    } else if (name == NotificationNames.kAdministratorsUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group administrators updated: $chat');
        await _reload();
      }
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    List<ContactInfo> admins = ContactInfo.fromList(widget.info.admins);
    _dataSource.refresh(admins);
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
      middle: StatedTitleView.from(context, () => 'Administrators'.tr),
      trailing: widget.info.isOwner ? _plusButton(context) : null,
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

  Widget _plusButton(BuildContext context) => IconButton(
    iconSize: 16,
    onPressed: () {
      List<ID> members = widget.info.members;
      Set<ID> candidates = members.toSet();
      // remove owner
      ID? owner = widget.info.owner;
      if (owner != null) {
        candidates.remove(owner);
      }
      // remove administrators
      List<ID> admins = widget.info.admins;
      for (ID item in admins) {
        candidates.remove(item);
      }
      if (members.isEmpty) {
        Alert.show(context, 'Error', 'Failed to add administrators'.tr);
      } else {
        Log.info('candidates: $candidates');
        MemberPicker.open(context, candidates,
          onPicked: (users) => _addAdmin(context, users.toList(), widget.info),
        );
      }
    },
    icon: const Icon(AppIcons.plusIcon),
  );

}

void _addAdmin(BuildContext context, List<ID> newAdmins, GroupInfo groupInfo) {
  if (newAdmins.isEmpty) {
    Log.warning('new administrators empty');
    return;
  }
  List<ID> oldAdmins = groupInfo.admins;
  List<ID> allAdmins = [];
  int removed = 0;
  int added = 0;
  // old admins
  for (ID item in oldAdmins) {
    if (allAdmins.contains(item)) {
      removed += 1;
      continue;
    }
    allAdmins.add(item);
  }
  // new admins
  for (ID item in newAdmins) {
    if (allAdmins.contains(item)) {
      continue;
    }
    added += 1;
    allAdmins.add(item);
  }
  // check changed
  GlobalVariable shared = GlobalVariable();
  AccountDBI db = shared.database;
  if (added == 0 && removed == 0) {
    assert(false, 'duplicated administrators: $oldAdmins');
    db.saveAdministrators(allAdmins, group: groupInfo.identifier);
    return;
  }
  // confirm to save
  previewMembers(newAdmins).then((body) {
    if (context.mounted) {
      Alert.confirm(context, 'Confirm Add',
        body,
        okAction: () => db.saveAdministrators(allAdmins, group: groupInfo.identifier),
      );
    }
  });
}
void _removeAdmin(BuildContext context, ContactInfo adminInfo, GroupInfo groupInfo) {
  List<ID> oldAdmins = groupInfo.admins;
  List<ID> allAdmins = [];
  // old admins
  for (ID item in oldAdmins) {
    if (allAdmins.contains(item)) {
      continue;
    }
    allAdmins.add(item);
  }
  // remove admin
  if (allAdmins.contains(adminInfo.identifier)) {
    allAdmins.remove(adminInfo.identifier);
  }
  // check changed
  GlobalVariable shared = GlobalVariable();
  AccountDBI db = shared.database;
  // confirm to save new administrators
  Alert.confirm(context, 'Confirm Delete',
      previewEntity(adminInfo),
      okAction: () => db.saveAdministrators(allAdmins, group: groupInfo.identifier)
  );
}
void _updateAdmin(GroupInfo groupInfo) async {
  GlobalVariable shared = GlobalVariable();
  ID group = groupInfo.identifier;
  List<ID> admins = await shared.facebook.getAdministrators(group);
  SharedGroupManager man = SharedGroupManager();
  bool ok = await man.updateAdministrators(admins, group: group);
  if (!ok) {
    // not owner?
    return;
  }
  // check 'reset' command
  var pair = groupInfo.reset;
  ReliableMessage? msg = pair.second;
  ID? sender = msg?.sender;
  if (sender == null) {
    assert(false, 'failed to get "reset" command message for group: $group');
  } else if (sender == groupInfo.owner) {
    // last 'reset' command was sent by the owner,
    // shall we create a new one here while group document is updated?
    // TODO: reset new members when no waiting invitation
  } else if (admins.contains(sender)) {
    // last 'reset' command was sent by an admin,
    // shall we create a new one here while group document is updated?
    // TODO: reset new members when no waiting invitation
  } else if (groupInfo.invitations.isEmpty) {
    // last 'reset' command was sent by an admin, but not it's removed,
    // to avoid confused, we must create a new 'reset' command here.
    List<ID> members = await shared.facebook.getMembers(group);
    List<ID> newMembers = [...members];
    ok = await man.resetGroupMembers(newMembers, group: group);
    assert(ok, 'failed to reset group: $group, members: $members');
  } else {
    assert(false, 'should not remove current admin: $sender, group: $group');
  }
}

class _ContactListAdapter with SectionAdapterMixin {
  _ContactListAdapter(this._info, {required _ContactDataSource dataSource})
      : _dataSource = dataSource;

  final GroupInfo _info;
  final _ContactDataSource _dataSource;

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount() + 1;  // includes fixed section

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    String title;
    if (section == 0) {
      // fixed section
      title = '#${'Owner'.tr}';
    } else {
      title = _dataSource.getSection(section - 1);
    }
    return Container(
      color: Styles.colors.sectionHeaderBackgroundColor,
      padding: Styles.sectionHeaderPadding,
      child: Text(title,
        style: Styles.sectionHeaderTextStyle,
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    if (section == 0) {
      // fixed section
      return 1;
    }
    return _dataSource.getItemCount(section - 1);
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    if (section == 0) {
      // fixed section
      if (index == 0) {
        return _ownerItem(context);
      } else {
        // error
        return Text('Error'.tr);
      }
    }
    ContactInfo info = _dataSource.getItem(section - 1, index);
    Widget? trailing;
    if (_canRemove(info, _info)) {
      trailing = IconButton(icon: const Icon(AppIcons.removeIcon, color: CupertinoColors.systemRed,),
        onPressed: () => _removeAdmin(context, info, _info),
      );
    }
    return ProfilePage.cell(info, trailing: trailing);
  }

  bool _canRemove(ContactInfo adminInfo, GroupInfo groupInfo) {
    if (!groupInfo.isOwner) {
      // only owner can remove administrator
      return false;
    }
    var pair = groupInfo.reset;
    ResetCommand? cmd = pair.first;
    ReliableMessage? msg = pair.second;
    assert(cmd != null && msg != null, 'failed to get "reset" command message for group: $groupInfo');
    if (msg?.sender != adminInfo.identifier) {
      // if last "reset" command wasn't sent by this admin, it can be removed
      return true;
    }
    // if last "reset" command sent by this admin, but no invitations waiting review,
    // it can be removed too.
    List invitations = groupInfo.invitations;
    return invitations.isEmpty;
  }

  Widget _ownerItem(BuildContext context) {
    ID? owner = _info.owner;
    ContactInfo? info = owner == null ? null : ContactInfo.fromID(owner);
    if (info == null) {
      // error
      return Text('Owner not found'.tr);
    }
    return ProfilePage.cell(info);
  }

  @override
  bool shouldExistSectionFooter(int section) => section + 1 == numberOfSections();

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'Administrators::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
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

}

class _ContactDataSource {

  List<String> _sections = [];
  Map<int, List<ContactInfo>> _items = {};

  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames;
    _items = sorter.sectionItems;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) => _sections[sec];

  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}
