import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:flutter_section_list/flutter_section_list.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/share_video.dart';


class LiveSourceListPage extends StatefulWidget {
  const LiveSourceListPage(this.info, {super.key});

  final Conversation info;

  static void open(BuildContext context, Conversation info) => showPage(
    context: context,
    builder: (context) => LiveSourceListPage(info),
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

  static const Duration kQueryExpires = Duration(hours: 24);

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
    if (lives == null) {
      Log.error('lives not found in live stream response');
      return;
    }
    int? tag = content['tag'];
    if (tag == _searchTag) {
      Log.info('respond with search tag: $tag');
      _searchTag = 0;
    } else if (isRefresh) {
      Log.warning('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    } else {
      Log.info('refresh lives from old record: $lives');
      _searchTag = 0;
    }
    await _dataSource.refresh(lives, forceQuery: isRefresh);
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  Future<Content?> _loadLives() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.info.identifier,
        limit: 1024);
    var messages = pair.first;
    Log.info('checking lives from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      var lives = content['lives'];
      if (lives is List) {
        // got last one
        return content;
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
        var expired = time.millisecondsSinceEpoch + kQueryExpires.inMilliseconds;
        var now = DateTime.now().millisecondsSinceEpoch;
        if (now < expired) {
          Log.info('last message not expired yet: $content');
          return;
        }
      }
    }
    //
    //  query for new records
    //
    Log.warning('query for "Live Stream Sources"');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set, not connect yet?');
      return;
    }
    // build command
    content = TextContent.create('Live Stream Sources');
    _searchTag = content.sn;
    content['tag'] = _searchTag;
    // check visa.key
    ID bot = widget.info.identifier;
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
      middle: Text('Live Stream Sources'.tr,
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
  Widget getSectionHeader(BuildContext context, int section) => Center(
    child: Container(
      padding: const EdgeInsets.all(8),
      child: const CupertinoActivityIndicator(),
    ),
  );

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

  Future<void> refresh(Iterable array, {required bool forceQuery}) async {
    List<TVBox> lives = [];
    TVBox box;
    Uri? url;
    for (var item in array) {
      // get live url
      if (item is Uri) {
        url = item;
      } else if (item is String) {
        url = HtmlUri.parseUri(item);
      }
      if (url == null) {
        Log.error('live url error: $item');
        continue;
      }
      // create tv box
      box = TVBox(url);
      if (forceQuery) {
        await box.refresh();
      }
      lives.add(box);
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

  @override
  void initState() {
    super.initState();
    _loadLives();
  }

  Future<void> _loadLives() async {
    await widget.tvBox.refresh();
    if (mounted) {
      setState(() {});
    }
  }

  String get title {
    int count = 0;
    List<ChannelGroup> groups = widget.tvBox.lives ?? [];
    for (var grp in groups) {
      count += grp.sources.length;
    }
    if (count == 0) {
      TVBox tvBox = widget.tvBox;
      return 'Querying "${tvBox.livesUrl.host}"';
    } else if (count == 1) {
      return 'Only 1 channel';
    } else {
      return '$count channels';
    }
  }

  String get subtitle => widget.tvBox.livesUrl.toString();

  @override
  Widget build(BuildContext context) {
    Uri url = widget.tvBox.livesUrl;
    return CupertinoTableCell(
      leading: _leading(),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const CupertinoListTileChevron(),
      onTap: () => VideoPlayerPage.openLivePlayer(context, url,
        onShare: (playingItem) => ShareVideo.shareVideo(context, playingItem),
      ),
    );
  }

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
