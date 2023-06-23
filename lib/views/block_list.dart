import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'profile.dart';


class BlockListPage extends StatefulWidget {
  const BlockListPage({super.key});

  static void open(BuildContext context) => showCupertinoDialog(
    context: context,
    builder: (context) => const BlockListPage(),
  );

  @override
  State<StatefulWidget> createState() => _BlockListState();
}

class _BlockListState extends State<BlockListPage> implements lnc.Observer {
  _BlockListState() {
    _dataSource = _BlockedDataSource();
    _adapter = _BlockListAdapter(dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    super.dispose();
  }

  late final _BlockedDataSource _dataSource;
  late final _BlockListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kBlockListUpdated) {
      await _reload();
    } else if (name == NotificationNames.kDocumentUpdated) {
      ID? did = userInfo?['ID'];
      Log.warning('document updated: $did');
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
    // 1. get block-list for current user
    SharedDatabase database = shared.database;
    List<ID> contacts = await database.getBlockList(user: user.identifier);
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
      middle: StatedTitleView.from(context, () => 'Blocked'),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _BlockListAdapter with SectionAdapterMixin {
  _BlockListAdapter({required _BlockedDataSource dataSource})
      : _dataSource = dataSource;

  final _BlockedDataSource _dataSource;

  @override
  int numberOfSections() => _dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => true;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Facade.of(context).colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text(_dataSource.getSection(section),
      style: Facade.of(context).styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    ContactInfo info = _dataSource.getItem(section, index);
    return ProfilePage.cell(info, onLongPress: () {
      Log.warning('long press: $info');
      Alert.actionSheet(context,
        'Confirm', 'Are you sure to remove this contact?',
        'Remove ${info.name}',
            () => info.delete(context: context),
      );
    });
  }

}

class _BlockedDataSource {

  List<String> _sections = [];
  Map<int, List<ContactInfo>> _items = {};

  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} blocked contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames;
    _items = sorter.sectionItems;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) => _sections[sec];

  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}
