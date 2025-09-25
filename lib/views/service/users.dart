import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import '../contact/profile.dart';
import 'base.dart';

class UserListPage extends StatefulWidget {
  const UserListPage(this.chat, this.info, {super.key});

  final Conversation chat;
  final ServiceInfo info;

  String get title => info['title'] ?? 'Users'.tr;
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, ServiceInfo info) => showPage(
    context: context,
    builder: (context) => UserListPage(chat, info),
  );

  @override
  State<StatefulWidget> createState() => _SearchState();

}

class _SearchState extends State<UserListPage> with Logging implements lnc.Observer {
  _SearchState() {
    _dataSource = _SearchDataSource();
    _adapter = _SearchResultAdapter(this, dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kActiveUsersUpdated);
  }

  late final _SearchDataSource _dataSource;
  late final _SearchResultAdapter _adapter;

  bool _refreshing = false;

  int _queryTag = 9527;  // show CupertinoActivityIndicator
  String? _description;

  String get description => _description ?? '';

  /// loading after enter
  bool get isLoading => !(_queryTag == 0 || _refreshing);

  /// waiting for update
  bool get isQuerying => _queryTag != 0; // && _queryTag != 9527;

  /// refreshed or timeout
  bool get isRefreshFinished => _queryTag == 0;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kActiveUsersUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kActiveUsersUpdated) {
      logInfo('active users updated: $name, $userInfo');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshActiveUsers(content, isRefresh: true);
      }
    }
  }

  Future<void> _refreshActiveUsers(Content content, {required bool isRefresh}) async {
    List users = content['users'] ?? [];
    String? desc = content['description'];
    // check tag
    int? tag = content['tag'];
    if (!isRefresh) {
      // update from local
      logInfo('refresh active users from old record: ${users.length}, $desc');
      _queryTag = 0;
    } else if (tag == _queryTag) {
      // update from remote
      logInfo('respond with query tag: $tag, ${users.length}, $desc');
      _queryTag = 0;
    } else {
      // expired response
      logWarning('query tag not match, ignore this response: $tag <> $_queryTag');
      return;
    }
    // refresh if not empty
    if (users.isNotEmpty) {
      List<ContactInfo> array = ContactInfo.fromList(ID.convert(users));
      for (ContactInfo item in array) {
        await item.reloadData();
      }
      _dataSource.refresh(array);
      logInfo('${array.length} contacts refreshed');
    }
    if (mounted) {
      setState(() {
        _description = desc;
        _adapter.notifyDataChange();
      });
    }
  }

  Future<void> _load() async {
    // check old records
    var shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    var content = await handler.getContent(widget.chat.identifier, 'users', widget.title);
    if (content == null) {
      // query for new records
      logInfo('query active users first: "${widget.title}"');
    } else {
      logInfo('query active users again: "${widget.title}"');
      // refresh with content loaded
      await _refreshActiveUsers(content, isRefresh: false);
    }
    // query to update content
    await _query(content);
  }

  // query service bot to refresh content
  Future<void> _query([Content? old]) async {
    var content = await widget.info.request(old);
    if (content == null) {
      // old content not expired yet
      return;
    }
    _queryTag = content.sn;
    logInfo('query active users with tag: $_queryTag');
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    navigationBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      // backgroundColor: Styles.themeBarBackgroundColor,
      middle: StatedTitleView.from(context, () => widget.title),
    ),
    child: RefreshIndicator(
      onRefresh: _refreshList,
      child: buildSectionListView(
        enableScrollbar: true,
        adapter: _adapter,
      ),
    ),
  );

  Future<void> _refreshList() async {
    _refreshing = true;
    // force to refresh
    await _query();
    // waiting for response
    await untilConditionTrue(() => isRefreshFinished);
    _refreshing = false;
  }

}

class _SearchResultAdapter with SectionAdapterMixin {
  _SearchResultAdapter(this.state, {required _SearchDataSource dataSource})
      : _dataSource = dataSource;

  final _SearchDataSource _dataSource;
  final _SearchState state;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  bool shouldExistSectionHeader(int section) => state.isLoading;

  @override
  bool shouldExistSectionFooter(int section) => state.description.isNotEmpty;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Styles.colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    alignment: Alignment.center,
    child: const CupertinoActivityIndicator(),
  );

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = state.description;
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
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    ContactInfo info = _dataSource.getItem(indexPath.section, indexPath.item);
    return ProfilePage.cell(info);
  }

}

class _SearchDataSource with Logging {

  List<ContactInfo>? _items;

  void refresh(List<ContactInfo> array) {
    logDebug('refreshing ${array.length} search result(s)');
    _items = array;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _items?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items![idx];

}

