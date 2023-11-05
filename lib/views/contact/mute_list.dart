import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'profile.dart';


class MuteListPage extends StatefulWidget {
  const MuteListPage({super.key});

  static void open(BuildContext context) => showCupertinoDialog(
    context: context,
    builder: (context) => const MuteListPage(),
  );

  @override
  State<StatefulWidget> createState() => _MuteListState();
}

class _MuteListState extends State<MuteListPage> implements lnc.Observer {
  _MuteListState() {
    _dataSource = _MutedDataSource();
    _adapter = _MuteListAdapter(dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    super.dispose();
  }

  late final _MutedDataSource _dataSource;
  late final _MuteListAdapter _adapter;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      Log.info('muted contact updated: $contact');
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
    // 1. get mute-list for current user
    SharedDatabase database = shared.database;
    List<ID> contacts = await database.getMuteList(user: user.identifier);
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
      middle: StatedTitleView.from(context, () => 'Muted List'.tr),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );
}

class _MuteListAdapter with SectionAdapterMixin {
  _MuteListAdapter({required _MutedDataSource dataSource})
      : _dataSource = dataSource;

  final _MutedDataSource _dataSource;

  @override
  int numberOfSections() {
    int sections = _dataSource.getSectionCount();
    return sections > 0 ? sections : 1;
  }

  @override
  bool shouldExistSectionHeader(int section) => _dataSource.getSectionCount() > 0;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Styles.colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text(_dataSource.getSection(section),
      style: Styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) {
    if (_dataSource.getSectionCount() == 0) {
      return 0;
    }
    return _dataSource.getItemCount(section);
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    int section = indexPath.section;
    int index = indexPath.item;
    ContactInfo info = _dataSource.getItem(section, index);
    return ProfilePage.cell(info);
  }

  @override
  bool shouldExistSectionFooter(int section) => section + 1 == numberOfSections();

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'MuteList::Description'.tr;
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

class _MutedDataSource {

  List<String> _sections = [];
  Map<int, List<ContactInfo>> _items = {};

  void refresh(List<ContactInfo> contacts) {
    Log.debug('refreshing ${contacts.length} muted contact(s)');
    ContactSorter sorter = ContactSorter.build(contacts);
    _sections = sorter.sectionNames;
    _items = sorter.sectionItems;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) => _sections[sec];

  int getItemCount(int sec) => _items[sec]?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items[sec]![idx];
}
