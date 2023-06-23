import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'profile.dart';
import 'search.dart';
import 'block_list.dart';


class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  static BottomNavigationBarItem barItem() => const BottomNavigationBarItem(
    icon: Icon(Styles.contactsTabIcon),
    label: 'Contacts',
  );

  @override
  State<StatefulWidget> createState() => _ContactListState();
}

class _ContactListState extends State<ContactListPage> implements lnc.Observer {
  _ContactListState() {
    _dataSource = _ContactDataSource();
    _adapter = _ContactListAdapter(dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    super.dispose();
  }

  late final _ContactDataSource _dataSource;
  late final _ContactListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    // Map? info = notification.userInfo;
    if (name == NotificationNames.kContactsUpdated) {
      await _reload();
    } else if (name == NotificationNames.kDocumentUpdated) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    // 0. check current user
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('current user not set');
      return;
    }
    // 1. get contacts for current user
    SharedDatabase database = shared.database;
    List<ID> contacts = await database.getContacts(user: user.identifier);
    if (contacts.isEmpty) {
      // check default contacts
      List<ID> candidates = await Config().contacts;
      Log.warning('default contacts: $candidates');
      for (ID item in candidates) {
        database.addContact(item, user: user.identifier);
      }
      if (candidates.isNotEmpty) {
        contacts = await database.getContacts(user: user.identifier);
      }
    }
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Contacts'),
      trailing: SearchPage.searchButton(context),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _ContactListAdapter with SectionAdapterMixin {
  _ContactListAdapter({required _ContactDataSource dataSource})
      : _dataSource = dataSource;

  final _ContactDataSource _dataSource;

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount() + 1;  // includes fixed section

  @override
  bool shouldExistSectionHeader(int section) => section > 0;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) {
    if (section == 0) {
      // fixed section
      return const Text('...');
    }
    String title = _dataSource.getSection(section - 1);
    return Container(
      color: Facade.of(context).colors.sectionHeaderBackgroundColor,
      padding: Styles.sectionHeaderPadding,
      child: Text(title,
        style: Facade.of(context).styles.sectionHeaderTextStyle,
      ),
    );
  }

  @override
  int numberOfItems(int section) {
    if (section == 0) {
      // fixed section
      return 2;
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
        return _newFriendsItem(context);
      } else if (index == 1) {
        return _blockListIcon(context);
      } else {
        // error
        return const Text('error');
      }
    }
    ContactInfo info = _dataSource.getItem(section - 1, index);
    return ProfilePage.cell(info, onLongPress: () {
      Log.warning('long press: $info');
      Alert.actionSheet(context,
        'Confirm', 'Are you sure to remove this contact?',
        'Remove ${info.name}',
            () => info.delete(context: context),
      );
    });
  }

  Widget _newFriendsItem(BuildContext context) => CupertinoTableCell(
      leading: Container(
        color: Colors.orange,
        padding: const EdgeInsets.all(2),
        child: const Icon(Styles.newFriendsIcon,
          color: Colors.white,
        ),
      ),
      title: const Text('New Friends'),
      trailing: const CupertinoListTileChevron(),
      onTap: () {
        Alert.show(context, 'Coming soon', 'Requests from new friends.');
      }
  );

  Widget _blockListIcon(BuildContext context) => CupertinoTableCell(
      leading: Container(
        color: Colors.black,
        padding: const EdgeInsets.all(2),
        child: const Icon(Styles.blockListIcon,
          color: Colors.white,
        ),
      ),
      title: const Text('Blocked'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => BlockListPage.open(context),
  );

  /*
  Widget _groupChatsItem(BuildContext context) => CupertinoTableCell(
      leading: Container(
        color: Colors.green,
        padding: const EdgeInsets.all(2),
        child: const Icon(Styles.groupChatsIcon,
          color: Colors.white,
        ),
      ),
      title: const Text('Group Chats'),
      trailing: const CupertinoListTileChevron(),
      onTap: () {
        Alert.show(context, 'Coming soon', 'Conversations for groups.');
      }
  );
   */

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
