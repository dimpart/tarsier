import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

typedef PickContactsCallback = void Function(Set<ID> contacts);

class PickContactsPage extends StatefulWidget {
  const PickContactsPage({super.key, required this.fromWhere, required this.onPicked});

  final ID fromWhere;
  final PickContactsCallback onPicked;

  static void open(BuildContext context, ID from, {required PickContactsCallback onPicked}) =>
      showCupertinoDialog(
        context: context,
        builder: (context) => PickContactsPage(fromWhere: from, onPicked: onPicked),
      );

  @override
  State<StatefulWidget> createState() => _PickContactsState();
}

class _PickContactsState extends State<PickContactsPage> implements lnc.Observer {
  _PickContactsState() {
    _dataSource = _ContactDataSource();
    _adapter = _ContactListAdapter(this);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  late final _ContactDataSource _dataSource;
  late final _ContactListAdapter _adapter;

  final Set<ID> _fixedContacts = HashSet();
  final Set<ID> _selectedContacts = HashSet();

  Set<ID> get selectedContacts => _selectedContacts;

  bool isFixed(ID user) => _fixedContacts.contains(user);

  _ContactDataSource get dataSource => _dataSource;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? did = userInfo?['ID'];
      Log.info('document updated: $did');
      await _reload();
    }
  }

  Future<Set<ID>> _reloadFixedContacts() async {
    _fixedContacts.clear();
    ID from = widget.fromWhere;
    if (from.isUser) {
      _fixedContacts.add(from);
    } else {
      GlobalVariable shared = GlobalVariable();
      List<ID> members = await shared.facebook.getMembers(from);
      _fixedContacts.addAll(members);
    }
    return _fixedContacts;
  }
  Future<List<ID>> _allContacts() async {
    GlobalVariable shared = GlobalVariable();
    List<ID> contacts;
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not set');
      contacts = [];
    } else {
      contacts = await shared.facebook.getContacts(user.identifier);
      contacts = [...contacts];
    }
    // merge with fixed contacts
    Set<ID> fixed = await _reloadFixedContacts();
    for (ID item in fixed) {
      if (!contacts.contains(item)) {
        contacts.add(item);
      }
    }
    return contacts;
  }
  Future<void> _reload() async {
    // 1. load all contacts (fixed + contacts)
    List<ID> contacts = await _allContacts();
    // 2. load contact info
    List<ContactInfo> array = ContactInfo.fromList(contacts);
    for (ContactInfo item in array) {
      await item.reloadData();
    }
    // 3. refresh contact list
    _dataSource.refresh(array);
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

  void onChanged() {
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Select Contacts'),
      trailing: IconButton(
        icon: const Icon(Styles.groupChatIcon),
        onPressed: _selectedContacts.isEmpty ? null : () {
          Navigator.pop(context);
          widget.onPicked(_selectedContacts);
        },
      ),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _ContactListAdapter with SectionAdapterMixin {
  _ContactListAdapter(_PickContactsState state)
      : _parent = state;

  final _PickContactsState _parent;

  @override
  int numberOfSections() => _parent.dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    String title = _parent.dataSource.getSection(section);
    return Container(
      color: Facade.of(context).colors.sectionHeaderBackgroundColor,
      padding: Styles.sectionHeaderPadding,
      child: Text(title,
        style: Facade.of(context).styles.sectionHeaderTextStyle,
      ),
    );
  }

  @override
  int numberOfItems(int section) => _parent.dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    ContactInfo info = _parent.dataSource.getItem(section, index);
    return _PickContactCell(_parent, info, onTap: () {
      Set<ID> contacts = _parent.selectedContacts;
      if (contacts.contains(info.identifier)) {
        contacts.remove(info.identifier);
      } else {
        contacts.add(info.identifier);
      }
      Log.info('selected contacts: $contacts');
      _parent.onChanged();
    });
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

/// TableCell for Contacts
class _PickContactCell extends StatefulWidget {
  const _PickContactCell(_PickContactsState state, this.info, {this.onTap})
      : _parent = state;

  final _PickContactsState _parent;

  final ContactInfo info;
  final GestureTapCallback? onTap;

  bool get isSelected => _parent.selectedContacts.contains(info.identifier);

  @override
  State<StatefulWidget> createState() => _PickContactCellState();

}

class _PickContactCellState extends State<_PickContactCell> {
  _PickContactCellState();

  Widget? _image;

  Widget? get image {
    _image ??= widget.info.getImage();
    return _image;
  }

  bool get isFixed => widget._parent.isFixed(widget.info.identifier);
  bool get isSelected => widget.isSelected;

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: image,
    title: Text(widget.info.title),
    trailing: _tailingWidget,
    onTap: isFixed ? null : () {
      GestureTapCallback? callback = widget.onTap;
      if (callback != null) {
        callback();
      }
    },
  );

  Widget? get _tailingWidget {
    if (isFixed) {
      return const Icon(Styles.selectedIcon, color: CupertinoColors.inactiveGray,);
    } else if (isSelected) {
      return const Icon(Styles.selectedIcon);
    }
    return null;
  }

}
