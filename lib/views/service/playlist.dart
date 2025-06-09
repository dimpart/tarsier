import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import 'play_item.dart';
import 'play_manager.dart';


class PlaylistPage extends StatefulWidget {
  const PlaylistPage(this.chat, this.info, {super.key});

  final Conversation chat;
  final Map info;

  String get title => info['title'] ?? 'Playlist'.tr;
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, Map info) => showPage(
    context: context,
    builder: (context) => PlaylistPage(chat, info),
  );

  @override
  State<StatefulWidget> createState() => _PlaylistState();

}

class _PlaylistState extends State<PlaylistPage> with Logging implements lnc.Observer {
  _PlaylistState() {
    _dataSource = _PlaylistSource();

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kPlaylistUpdated);
  }

  late final _PlaylistSource _dataSource;

  bool _refreshing = false;

  int _queryTag = 9527;  // show CupertinoActivityIndicator

  static const Duration kPlaylistQueryExpires = Duration(minutes: 32);

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kPlaylistUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kPlaylistUpdated) {
      logInfo('playlist updated: $name, $userInfo');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshPlaylist(content, isRefresh: true);
      }
    }
  }

  Future<bool> _refreshPlaylist(Content content, {required bool isRefresh}) async {
    var man = PlaylistManager();
    List? playlist = await man.updatePlaylist(content, widget.chat.identifier);
    if (playlist == null) {
      return false;
    }
    // check tag
    int? tag = content['tag'];
    if (!isRefresh) {
      // update from local
      logInfo('refresh playlist from old record: ${playlist.length}');
      _queryTag = 0;
    } else if (tag == _queryTag) {
      // update from remote
      logInfo('respond with query tag: $tag, ${playlist.length}');
      _queryTag = 0;
    } else {
      // expired response
      logWarning('query tag not match, ignore this response: $tag <> $_queryTag');
      return false;
    }
    // refresh if not empty
    if (playlist.isNotEmpty) {
      _dataSource.refresh(playlist);
      logInfo('playlist (size=${playlist.length}) refreshed');
    }
    if (mounted) {
      setState(() {
        //
      });
    }
    return true;
  }

  Future<void> _load() async {
    // check old records
    var shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    var content = await handler.getContent(widget.chat.identifier, 'playlist', widget.title);
    if (content == null) {
      // query for new records
      logInfo('query playlist first');
      await _query();
      return;
    }
    // check record time
    var time = content.time;
    if (time == null) {
      logError('playlist content error: $content');
      await _query();
    } else {
      int? expires = content.getInt('expires', null);
      if (expires == null || expires <= 8) {
        expires = kPlaylistQueryExpires.inSeconds;
      }
      int later = time.millisecondsSinceEpoch + expires * 1000;
      var now = DateTime.now().millisecondsSinceEpoch;
      if (now > later) {
        logInfo('query playlist again');
        await _query();
      }
    }
    // refresh with content loaded
    await _refreshPlaylist(content, isRefresh: false);
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
    var content = CustomizedContent.create(app: 'chat.dim.video', mod: 'playlist', act: 'request');
    _queryTag = content.sn;
    if (mounted) {
      setState(() {
      });
    }
    content['tag'] = _queryTag;
    content['title'] = title;
    content['keywords'] = keywords;
    content['hidden'] = true;
    // TODO: check visa.key
    ID bot = widget.chat.identifier;
    logInfo('query playlist with tag: $_queryTag, keywords: $keywords, title: "$title"');
    await messenger.sendContent(content, sender: null, receiver: bot);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    Widget? body;
    int itemCount = _dataSource.getItemCount(0);
    if (itemCount == 0) {
      // body empty
    } else {
      double width = MediaQuery.of(context).size.width;
      int axisCount = width ~/ 200;
      body = MasonryGridView.count(
        crossAxisCount: axisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        itemCount: itemCount,
        itemBuilder: (context, index) {
          var item = _dataSource.getItem(0, index);
          return PlaylistItem(widget.chat, item);
        },
      );
    }
    if (body == null) {
      // first loading
      body = const Center(child: CupertinoActivityIndicator());
    } else if (_queryTag > 0) {
      // refreshing
      body = Stack(
        alignment: Alignment.topCenter,
        children: [
          body,
          const CupertinoActivityIndicator(),
        ],
      );
    }
    return CupertinoPageScaffold(
      backgroundColor: Styles.colors.scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Styles.colors.appBardBackgroundColor,
        // backgroundColor: Styles.themeBarBackgroundColor,
        middle: StatedTitleView.from(context, () => widget.title),
        trailing: _refreshBtn(),
      ),
      child: body,
    );
  }

  Widget _refreshBtn() => IconButton(
    icon: const Icon(AppIcons.refreshIcon, size: 16),
    onPressed: _refreshing || _queryTag > 0 ? null : () => _refreshList(),
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


class _PlaylistSource with Logging {

  List<Season>? _videoList;

  void refresh(Iterable array) {
    List<Season> seasons = [];
    Season? item;
    for (var dict in array) {
      item = Season.parse(dict);
      if (item == null) {
        logError('video info error: $dict');
      } else {
        seasons.add(item);
      }
    }
    _videoList = seasons;
  }

  int getSectionCount() => 1;

  int getItemCount(int sec) => _videoList?.length ?? 0;

  Season getItem(int sec, int idx) => _videoList![idx];

}
