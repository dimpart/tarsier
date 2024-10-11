import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../contact/profile.dart';

class UserListPage extends StatefulWidget {
  const UserListPage(this.chat, this.info, {super.key});

  final Conversation chat;
  final Map info;

  String get title => info['title'] ?? 'Users';
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, Map info) => showPage(
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

  int _searchTag = 9394;  // show CupertinoActivityIndicator
  String? _description;

  String get description => _description ?? '';

  static const Duration kActiveUsersQueryExpires = Duration(minutes: 32);

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
    // check customized info
    if (!_checkActiveUsers(content)) {
      assert(false, 'content error: $content');
      return;
    }
    List users = content['users'] ?? [];
    String? desc = content['description'];
    // check tag
    int? tag = content['tag'];
    if (!isRefresh) {
      // update from local
      logInfo('refresh active users from old record: ${users.length}, $desc');
      _searchTag = 0;
    } else if (tag == _searchTag) {
      // update from remote
      logInfo('respond with search tag: $tag, ${users.length}, $desc');
      _searchTag = 0;
    } else {
      // expired response
      logWarning('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    }
    // refresh if not empty
    if (users.isNotEmpty) {
      List<ContactInfo> array = ContactInfo.fromList(ID.convert(users));
      for (ContactInfo item in array) {
        await item.reloadData();
      }
      await _dataSource.refresh(array);
      logInfo('${array.length} contacts refreshed');
    }
    if (mounted) {
      setState(() {
        _description = desc;
        _adapter.notifyDataChange();
      });
    }
  }

  bool _checkActiveUsers(Content content) {
    if (content['app'] != 'chat.dim.search' || content['mod'] != 'users') {
      return false;
    } else if (content['title'] != widget.title) {
      // not for this view
      return false;
    } else {
      assert(content['act'] == 'respond', 'content error: $content');
      return true;
    }
  }

  /// load from local storage
  Future<Content?> _loadActiveUsers() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.chat.identifier,
        limit: 32);
    List<InstantMessage> messages = pair.first;
    logInfo('checking active users from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      // check customized info
      if (_checkActiveUsers(content)) {
        // got last one
        var users = content['users'];
        if (users is List && users.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }

  Future<void> _load() async {
    // check old records
    var content = await _loadActiveUsers();
    if (content == null) {
      // query for new records
      logInfo('query active users first');
      await _query();
      return;
    }
    // check record time
    var time = content.time;
    if (time == null) {
      logError('active users content error: $content');
      await _query();
    } else {
      int? expires = content.getInt('expires', null);
      if (expires == null || expires <= 8) {
        expires = kActiveUsersQueryExpires.inSeconds;
      }
      int later = time.millisecondsSinceEpoch + expires * 1000;
      var now = DateTime.now().millisecondsSinceEpoch;
      if (now > later) {
        logInfo('query active users again');
        await _query();
      }
    }
    // refresh with content loaded
    await _refreshActiveUsers(content, isRefresh: false);
  }
  // query for new records
  Future<void> _query() async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      logError('messenger not set, not connect yet?');
      return;
    }
    String title = widget.title;
    String? keywords = widget.keywords;
    // build command
    var content = TextContent.create(keywords ?? title);
    if (mounted) {
      setState(() {
        _searchTag = content.sn;
      });
    }
    content['tag'] = _searchTag;
    content['title'] = title;
    content['keywords'] = keywords;
    content['hidden'] = true;
    // TODO: check visa.key
    ID bot = widget.chat.identifier;
    logInfo('query active users with tag: $_searchTag, keywords: $keywords, title: "$title"');
    await messenger.sendContent(content, sender: null, receiver: bot);
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
      trailing: _refreshBtn(),
    ),
    child: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

  Widget _refreshBtn() => IconButton(
      icon: const Icon(AppIcons.refreshIcon, size: 16),
      onPressed: _refreshing || _searchTag > 0 ? null : () => _refreshList(),
  );

  void _refreshList() {
    // disable the refresh button to avoid refresh frequently
    if (mounted) {
      setState(() {
        _refreshing = true;
      });
    }
    // enable the refresh button after 5 seconds
    Future.delayed(const Duration(seconds: 5)).then((value) {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    });
    // query
    _query();
  }

}

class _SearchResultAdapter with SectionAdapterMixin {
  _SearchResultAdapter(this.state, {required _SearchDataSource dataSource})
      : _dataSource = dataSource;

  final _SearchDataSource _dataSource;
  final _SearchState state;

  @override
  bool shouldExistSectionHeader(int section) => state._searchTag > 0;

  @override
  bool shouldExistSectionFooter(int section) => state.description.isNotEmpty;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Center(
    child: Container(
      padding: const EdgeInsets.all(8),
      child: const CupertinoActivityIndicator(),
    ),
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

  Future<void> refresh(List<ContactInfo> array) async {
    Log.debug('refreshing ${array.length} search result(s)');
    _items = array;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _items?.length ?? 0;

  ContactInfo getItem(int sec, int idx) => _items![idx];

}

