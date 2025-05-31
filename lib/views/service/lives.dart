import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../sharing//share_video.dart';


class LiveSourceListPage extends StatefulWidget {
  const LiveSourceListPage(this.chat, this.info, {super.key});

  final Conversation chat;
  final Map info;

  String get title => info['title'] ?? 'Live Stream Sources';
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, Map info) => showPage(
    context: context,
    builder: (context) => LiveSourceListPage(chat, info),
  );

  @override
  State<StatefulWidget> createState() => _LiveSourceListState();

}

class _LiveSourceListState extends State<LiveSourceListPage> with Logging implements lnc.Observer {
  _LiveSourceListState() {
    _dataSource = _LiveDataSource();
    _adapter = _LiveSourceAdapter(this, dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kLiveSourceUpdated);
  }

  late final _LiveDataSource _dataSource;
  late final _LiveSourceAdapter _adapter;

  bool _refreshing = false;

  int _searchTag = 9527;  // show CupertinoActivityIndicator
  String? _description;

  String get description => _description ?? '';

  static const Duration kLiveQueryExpires = Duration(minutes: 32);

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kLiveSourceUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kLiveSourceUpdated) {
      logInfo('live source updated: $name, $userInfo');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshLives(content, isRefresh: true);
      }
    }
  }

  Future<void> _refreshLives(Content content, {required bool isRefresh}) async {
    List lives = content['lives'] ?? [];
    String? desc = content['description'];
    // check tag
    int? tag = content['tag'];
    if (!isRefresh) {
      // update from local
      logInfo('refresh lives from old record: ${lives.length}, $desc');
      _searchTag = 0;
    } else if (tag == _searchTag) {
      // update from remote
      logInfo('respond with search tag: $tag, ${lives.length}, $desc');
      _searchTag = 0;
    } else {
      // expired response
      logWarning('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    }
    // refresh if not empty
    if (lives.isNotEmpty) {
      await _dataSource.refresh(lives);
      logInfo('${lives.length} live sources refreshed');
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
    var content = await handler.getContent(widget.chat.identifier, 'lives', widget.title);
    if (content == null) {
      // query for new records
      logInfo('query lives first');
      await _query();
      return;
    }
    // check record time
    var time = content.time;
    if (time == null) {
      logError('lives content error: $content');
      await _query();
    } else {
      int? expires = content.getInt('expires', null);
      if (expires == null || expires <= 8) {
        expires = kLiveQueryExpires.inSeconds;
      }
      int later = time.millisecondsSinceEpoch + expires * 1000;
      var now = DateTime.now().millisecondsSinceEpoch;
      if (now > later) {
        logInfo('query lives again');
        await _query();
      }
    }
    // refresh with content loaded
    await _refreshLives(content, isRefresh: false);
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
    logInfo('query lives with tag: $_searchTag, keywords: $keywords, title: "$title"');
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


//
//  Section Adapter
//

class _LiveSourceAdapter with SectionAdapterMixin {
  _LiveSourceAdapter(this.state, {required _LiveDataSource dataSource})
      : _dataSource = dataSource;

  final _LiveDataSource _dataSource;
  final _LiveSourceListState state;

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  bool shouldExistSectionHeader(int section) => state._searchTag > 0;

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
    TVBox box = _dataSource.getItem(indexPath.section, indexPath.item);
    return _LiveSourceItem(box);
  }

}

class _LiveDataSource with Logging {

  List<TVBox>? _sources;

  Future<void> refresh(Iterable array) async {
    List<TVBox> lives = [];
    Map info;
    Uri? url;
    for (var item in array) {
      // get live url
      if (item is Uri) {
        url = item;
        info = {
          'url': url.toString(),
        };
      } else if (item is String) {
        url = HtmlUri.parseUri(item);
        info = {
          'url': item,
        };
      } else if (item is Map) {
        url = HtmlUri.parseUri(item['url']);
        info = item;
      } else {
        logError('live item error: $item');
        continue;
      }
      if (url == null) {
        logError('live url error: $item');
        continue;
      }
      // create tv box
      lives.add(TVBox(url, info));
    }
    _sources = lives;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _sources?.length ?? 0;

  TVBox getItem(int sec, int idx) => _sources![idx];

}


//
//  Table Cell
//

class _LiveSourceItem extends StatefulWidget {
  const _LiveSourceItem(this.tvBox);

  final TVBox tvBox;

  @override
  State<StatefulWidget> createState() => _LiveSourceState();

}

class _LiveSourceState extends State<_LiveSourceItem> {

  Uri get livesUrl => widget.tvBox.livesUrl;

  String get title {
    TVBox tvBox = widget.tvBox;
    // get "title"
    String? text = tvBox.getString('title', null);
    if (text != null && text.isNotEmpty) {
      return text;
    }
    // get "name (count/total)"
    String? name = tvBox.getString('name', null);
    String count = _counter(tvBox);
    if (name == null || name.isEmpty) {
      return '$count channels';
    } else {
      return '$name ($count)';
    }
  }

  String _counter(TVBox tvBox) {
    int? total = tvBox['origin']?['channel_total_count'];
    int? count = tvBox['available_channel_count'];
    if (count == null) {
      int cnt = 0;
      var groups = widget.tvBox.lives ?? [];
      for (var grp in groups) {
        cnt += grp.count;
      }
      count = cnt;
    }
    if (total == null) {
      return '$count';
    } else {
      return '$count/$total';
    }
  }

  String get subtitle {
    TVBox tvBox = widget.tvBox;
    // get "subtitle"
    String? text = tvBox.getString('subtitle', null);
    if (text != null && text.isNotEmpty) {
      return text;
    }
    // get "url"
    String? src = tvBox['origin']?['source'];
    if (src != null && src.isNotEmpty) {
      return src;
    }
    String? url = tvBox['origin']?['url'];
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return widget.tvBox.livesUrl.toString();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: _leading(),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const CupertinoListTileChevron(),
    onTap: () => VideoPlayerPage.openLivePlayer(context, livesUrl,
      onShare: (playingItem) => ShareVideo.shareVideo(context, playingItem),
    ),
  );

  Widget _leading() {
    Widget view = Container(
      padding: const EdgeInsets.all(2),
      child: Icon(AppIcons.livesIcon,
        color: Styles.colors.textFieldColor,
      ),
    );
    view = Container(
      width: 48,
      height: 48,
      // color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.all(4),
      child: view,
    );
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.elliptical(8, 8),
      ),
      child: view,
    );
  }

}
