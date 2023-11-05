import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat/group_chats.dart';

import 'contact/profile.dart';
import 'contact/search.dart';
import 'contact/strangers.dart';
import 'contact/block_list.dart';
import 'contact/mute_list.dart';


class ContactListPage extends StatefulWidget {
  const ContactListPage({super.key});

  static BottomNavigationBarItem barItem() => const BottomNavigationBarItem(
    icon: _ContactsIconView(icon: Icon(AppIcons.contactsTabIcon)),
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
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      await _reload();
    } else if (name == NotificationNames.kDocumentUpdated) {
      ID? did = userInfo?['ID'];
      Log.info('document updated: $did');
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
        await database.addContact(item, user: user.identifier);
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
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
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
      return 4;
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
        return _groupChatsItem(context);
      } else if (index == 2) {
        return _blockListItem(context);
      } else if (index == 3) {
        return _muteListItem(context);
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
        'Remove ${info.title}',
            () => info.delete(context: context),
      );
    });
  }

  Widget _newFriendsItem(BuildContext context) => CupertinoTableCell(
      leading: Container(
        color: CupertinoColors.systemOrange,
        padding: const EdgeInsets.all(2),
        child: const Icon(AppIcons.newFriendsIcon,
          color: CupertinoColors.white,
        ),
      ),
      title: const Text('New Friends'),
      additionalInfo: _NewFriendCounter(),
      trailing: const CupertinoListTileChevron(),
      onTap: () => StrangerListPage.open(context),
  );

  Widget _groupChatsItem(BuildContext context) => CupertinoTableCell(
    leading: Container(
      color: CupertinoColors.systemGreen,
      padding: const EdgeInsets.all(2),
      child: const Icon(AppIcons.groupChatsIcon,
        color: CupertinoColors.white,
      ),
    ),
    title: const Text('Group Chats'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => GroupChatsPage.open(context),
  );

  Widget _blockListItem(BuildContext context) => CupertinoTableCell(
      leading: Container(
        color: CupertinoColors.systemGrey,
        padding: const EdgeInsets.all(2),
        child: const Icon(AppIcons.blockListIcon,
          color: CupertinoColors.white,
        ),
      ),
      title: const Text('Blocked List'),
      trailing: const CupertinoListTileChevron(),
      onTap: () => BlockListPage.open(context),
  );

  Widget _muteListItem(BuildContext context) => CupertinoTableCell(
    leading: Container(
      color: CupertinoColors.systemGrey,
      padding: const EdgeInsets.all(2),
      child: const Icon(AppIcons.muteListIcon,
        color: CupertinoColors.white,
      ),
    ),
    title: const Text('Muted List'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => MuteListPage.open(context),
  );

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


///
///   Greeting State
///
abstract class _GreetingState<T extends StatefulWidget> extends State<T> implements lnc.Observer {
  _GreetingState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kConversationUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  int _count = 0;

  int get count => _count;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kConversationUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kConversationUpdated) {
      ID? chat = userInfo?['ID'];
      Log.info('conversation updated: $chat');
      await _reload();
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      await _reload();
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      await _reload();
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      Log.info('muted contact updated: $contact');
      await _reload();
    }
  }

  Future<void> _reload() async {
    Amanuensis clerk = Amanuensis();
    List<Conversation> strangers = clerk.strangers;
    int count = 0;
    for (Conversation item in strangers) {
      await item.reloadData();
      if (item is ContactInfo && item.isNewFriend) {
          // ok
      } else {
        continue;
      }
      if (item.isMuted) {
        Log.warning('muted stranger: $item');
        continue;
      }
      Log.warning('stranger: $item');
      if (item.unread > 0) {
        count += 1;
      }
    }
    if (mounted) {
      setState(() {
        _count = count;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

}

///
///   New Friend Counter
///
class _NewFriendCounter extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _NewFriendState();

}

class _NewFriendState extends _GreetingState<_NewFriendCounter> {

  @override
  Widget build(BuildContext context) {
    Log.warning('greeting count: $count');
    Widget? bubble = NumberBubble.fromInt(count);
    return bubble ?? Container();
  }

}

///
///   Contacts Tab Item
///
class _ContactsIconView extends StatefulWidget {
  const _ContactsIconView({required this.icon});

  final Widget icon;

  @override
  State<StatefulWidget> createState() => _ContactsIconState();

}

class _ContactsIconState extends _GreetingState<_ContactsIconView> {

  @override
  Widget build(BuildContext context) {
    Log.warning('greeting count: $count');
    return IconView.fromSpot(widget.icon, count);
  }

}
