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

  int _searchTag = 0;

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
      await _reload(info?['cmd']);
    }
  }

  Future<void> _reload(Content? content) async {
    if (content == null) {
      return;
    }
    List? lives = content['lives'];
    if (lives == null) {
      Log.error('lives not found in live stream response');
      return;
    }
    int? tag = content['tag'];
    if (tag == _searchTag) {
      Log.debug('respond with search tag: $tag');
      _searchTag = 0;
    } else {
      Log.error('search tag not match, ignore this response: $tag <> $_searchTag');
      return;
    }
    _dataSource.refresh(lives);
    if (mounted) {
      setState(() {
        _adapter.notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _queryLives('Live Stream Sources');
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    navigationBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      // backgroundColor: Styles.themeBarBackgroundColor,
      middle: Text('Live Stream Sources'.tr),
    ),
    child: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

  Future<void> _queryLives(String keywords) async {
    Log.warning('query with command: $keywords');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      Log.error('messenger not set, not connect yet?');
      return;
    } else {
      if (mounted) {
        setState(() {
          _dataSource.refresh([]);
          _adapter.notifyDataChange();
        });
      }
    }
    // build command
    var content = TextContent.create(keywords);
    _searchTag = content.sn;
    content['tag'] = _searchTag;
    // check visa.key
    ID bot = widget.info.identifier;
    Log.info('query lives with tag: $_searchTag');
    messenger.sendContent(content, sender: null, receiver: bot);
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
    Uri url = _dataSource.getItem(indexPath.section - 1, indexPath.item);
    return _LiveSourceItem(url);
  }

}

class _LiveDataSource {

  List<Uri>? _sources;

  Future<void> refresh(Iterable array) async {
    List<Uri> lives = [];
    for (var item in array) {
      if (item is Uri) {
        lives.add(item);
      } else if (item is String) {
        var url = HtmlUri.parseUri(item);
        if (url != null) {
          lives.add(url);
        }
      } else {
        Log.error('unknown url item: $item');
      }
    }
    _sources = lives;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _sources?.length ?? 0;

  Uri getItem(int sec, int idx) => _sources![idx];

}


//
//  Table Cell
//

class _LiveSourceItem extends StatefulWidget {
  _LiveSourceItem(this.livesUrl);

  final Uri livesUrl;

  final List<ChannelGroup> groups = [];

  @override
  State<StatefulWidget> createState() => _LiveSourceState();

}

class _LiveSourceState extends State<_LiveSourceItem> {

  @override
  void initState() {
    super.initState();
    _loadData(widget.livesUrl);
  }

  Future<void> _loadData(Uri livesUrl) async {
    TVBox tvBox = TVBox(livesUrl);
    List<ChannelGroup> groups = await tvBox.refresh();
    if (mounted) {
      setState(() {
        widget.groups.clear();
        widget.groups.addAll(groups);
      });
    }
  }

  String get title {
    int count = 0;
    List<ChannelGroup> groups = widget.groups;
    for (var grp in groups) {
      count += grp.sources.length;
    }
    if (count == 0) {
      return 'Checking ${widget.livesUrl.host}';
    } else if (count == 1) {
      return 'Only 1 channel';
    } else {
      return '$count channels';
    }
  }

  String get subtitle => widget.livesUrl.toString();

  @override
  Widget build(BuildContext context) {
    Uri url = widget.livesUrl;
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
