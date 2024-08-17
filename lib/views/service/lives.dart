import 'package:flutter/cupertino.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/share_video.dart';


class LiveSourceListPage extends StatefulWidget {
  const LiveSourceListPage(this.chat, this.title, {super.key});

  final Conversation chat;
  final String title;

  static void open(BuildContext context, Conversation chat, String title) => showPage(
    context: context,
    builder: (context) => LiveSourceListPage(chat, title),
  );

  @override
  State<StatefulWidget> createState() => _LiveSourceListState();

}

class _LiveSourceListState extends State<LiveSourceListPage> implements lnc.Observer {
  _LiveSourceListState() {
    _dataSource = _LiveDataSource();
    _adapter = _LiveSourceAdapter(this, dataSource: _dataSource);

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kLiveSourceUpdated);
  }

  late final _LiveDataSource _dataSource;
  late final _LiveSourceAdapter _adapter;

  int _searchTag = 9527;  // show CupertinoActivityIndicator
  String? _description;

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
    Map? info = notification.userInfo;
    if (name == NotificationNames.kLiveSourceUpdated) {
      Log.info('live source updated: $name, $info');
      var content = info?['cmd'];
      if (content is Content) {
        await _refreshLives(content, isRefresh: true);
      }
    }
  }

  Future<void> _refreshLives(Content content, {required bool isRefresh}) async {
    List? lives = content['lives'];
    int? tag = content['tag'];
    String? desc = content['description'];
    if (!isRefresh) {
      // update from local
      Log.info('refresh lives from old record: ${lives?.length}, $desc');
      assert(lives != null, 'old record error: $context');
      _searchTag = 0;
      _description = desc;
    } else if (tag == _searchTag) {
      // update from remote
      Log.info('respond with search tag: $tag, ${lives?.length}, $desc');
      _searchTag = 0;
      _description = desc;
    } else {
      // expired response
      Log.warning('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    }
    // refresh if not empty
    if (lives != null && lives.isNotEmpty) {
      await _dataSource.refresh(lives);
    }
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  Future<Content?> _loadLives() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.chat.identifier,
        limit: 32);
    List<InstantMessage> messages = pair.first;
    Log.info('checking lives from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      var mod = content['mod'];
      var lives = content['lives'];
      if (mod == 'lives') {
        // got last one
        if (lives is List && lives.isNotEmpty) {
          return content;
        }
      }
    }
    return null;
  }

  Future<void> _load() async {
    //
    //  check old records
    //
    var content = await _loadLives();
    if (content != null) {
      await _refreshLives(content, isRefresh: false);
      var time = content.time;
      if (time != null) {
        var expired = time.millisecondsSinceEpoch + kLiveQueryExpires.inMilliseconds;
        var now = DateTime.now().millisecondsSinceEpoch;
        if (now < expired) {
          Log.info('last message not expired yet');
          return;
        }
      }
    }
    //
    //  query for new records
    //
    Log.warning('query for "${widget.title}"');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set, not connect yet?');
      return;
    }
    // build command
    content = TextContent.create(widget.title);
    _searchTag = content.sn;
    content['tag'] = _searchTag;
    content['hidden'] = true;
    // check visa.key
    ID bot = widget.chat.identifier;
    Log.info('query lives with tag: $_searchTag');
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
      middle: Text(widget.title,
        style: Styles.titleTextStyle,
      ),
    ),
    child: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

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
  bool shouldExistSectionHeader(int section) => state._searchTag > 0;

  @override
  bool shouldExistSectionFooter(int section) => state._description != null;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Center(
    child: Container(
      padding: const EdgeInsets.all(8),
      child: const CupertinoActivityIndicator(),
    ),
  );

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = state._description ?? '';
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

class _LiveDataSource {

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
        Log.error('live item error: $item');
        continue;
      }
      if (url == null) {
        Log.error('live url error: $item');
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
      List<ChannelGroup> groups = widget.tvBox.lives ?? [];
      for (var grp in groups) {
        cnt += grp.sources.length;
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
