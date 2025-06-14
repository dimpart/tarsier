import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/chat_box.dart';
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
    nc.addObserver(this, NotificationNames.kChatBoxClosed);
  }

  late final _PlaylistSource _dataSource;

  bool _refreshing = false;

  int _queryTag = 9527;  // show CupertinoActivityIndicator

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kChatBoxClosed);
    nc.removeObserver(this, NotificationNames.kPlaylistUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kPlaylistUpdated) {
      logInfo('playlist updated: $name');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshPlaylist(content, isRefresh: true);
      }
    } else if (name == NotificationNames.kChatBoxClosed) {
      var bot = userInfo?['ID'];
      if (bot == widget.chat.identifier) {
        // query to update playlist
        _query(null, isRefresh: true);
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
      logInfo('refresh playlist from old record, size: ${playlist.length}');
      _queryTag = 0;
    } else if (tag == _queryTag) {
      // update from remote
      logInfo('respond with query tag: $tag, playlist size: ${playlist.length}');
      _queryTag = 0;
    } else {
      // expired response
      logWarning('query tag not match: $tag <> $_queryTag, size: ${playlist.length}');
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
    var pm = PlaylistManager();
    var content = await pm.getPlaylistContent(widget.title, widget.chat.identifier);
    if (content == null) {
      // query for new records
      logInfo('query playlist first: ${widget.title}');
      await _query(null, isRefresh: true);
    } else {
      logInfo('query playlist again: ${widget.title}');
      await _query(content, isRefresh: false);
      // refresh with content loaded
      await _refreshPlaylist(content, isRefresh: false);
    }
  }
  // query for new records
  Future<Content?> _query(Content? content, {required bool isRefresh}) async {
    String title = widget.title;
    String? keywords = widget.keywords;
    Map extra = {
      'title': title,
      'keywords': keywords,
    };
    var pm = PlaylistManager();
    var query = await pm.queryPlaylist(content, extra, widget.chat.identifier, isRefresh: isRefresh);
    if (query != null) {
      _queryTag = query.sn;
      if (mounted) {
        setState(() {
        });
      }
    }
    return query;
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
      int axisCount = width ~/ 192;
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
        trailing: _trailing(_refreshBtn(), _searchBtn(context)),
      ),
      child: body,
    );
  }

  Widget _trailing(Widget btn1, Widget btn2) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      btn1,
      btn2,
    ],
  );

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
    _query(null, isRefresh: true);
  }

  Widget _searchBtn(BuildContext context) => IconButton(
    icon: const Icon(AppIcons.searchIcon, size: 16),
    onPressed: () => ChatBox.open(context, widget.chat, widget.info),
  );

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
