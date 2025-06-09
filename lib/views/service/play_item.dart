import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../sharing/share_page.dart';
import '../sharing/share_video.dart';
import 'play_manager.dart';


class Season extends Dictionary {
  Season(super.dict);

  /// video name
  String get name => getString('name', '')!;

  /// playing page URL
  Uri? get page => HtmlUri.parseUri(this['page']);

  /// create time
  DateTime? get time => getDateTime('time', null);

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz name="$name" url="$page" />';
  }

  static Season? parse(Object? season) {
    if (season == null) {
      return null;
    } else if (season is Season) {
      return season;
    }
    Map? info = Wrapper.getMap(season);
    if (info == null) {
      assert(false, 'video info error: $season');
      return null;
    } else if (info['page'] == null || info['name'] == null) {
      assert(false, 'video info error: $info');
      return null;
    }
    return Season(info);
  }

}


class PlaylistItem extends StatefulWidget {
  const PlaylistItem(this.chat, this.info, {super.key});

  final Conversation chat;
  final Season info;

  @override
  State<StatefulWidget> createState() => _PlayItemState();

}

class _PlayItemState extends State<PlaylistItem> with Logging implements lnc.Observer {
  _PlayItemState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kVideoItemUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kVideoItemUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kVideoItemUpdated) {
      logInfo('video item updated: $name');
      var content = userInfo?['cmd'];
      Map? season = userInfo?['season'];
      if (season?['page'] == widget.info['page']) {
        logInfo('video info updated: $name, ${season?["name"]}');
        assert(content is Content, 'video content error: $content');
        await _refreshPlayInfo(content, isRefresh: true);
      }
    }
  }

  Future<bool> _refreshPlayInfo(Content content, {required bool isRefresh}) async {
    var format = content['format'];
    var text = content['text'];
    logInfo('refreshing play item with format: $format, size: ${text?.length}, name: "${widget.info.name}"');
    if (format != null && text != null) {
      if (mounted) {
        setState(() {
          widget.info['format'] = format;
          widget.info['text'] = text;
        });
      }
    }
    return true;
  }

  Future<void> _load() async {
    Season season = widget.info;
    String? name = season['name'];
    Uri? page = HtmlUri.parseUri(season['page']);
    if (page == null) {
      assert(false, 'season error: $season');
      return;
    }
    // check old records
    var pm = PlaylistManager();
    var content = await pm.getSeasonContent(page, widget.chat.identifier);
    if (content == null) {
      // query for new records
      logInfo('query video info first: "$name" $page');
      await _query(null);
    } else {
      logInfo('query video info again: "$name" $page');
      await _query(content);
      // refresh with content loaded
      await _refreshPlayInfo(content, isRefresh: false);
    }
  }
  // query for new records
  Future<Content?> _query(Content? content) async {
    // check content load from local cache
    ID bot = widget.chat.identifier;
    Uri? page = widget.info.page;
    if (page == null) {
      assert(false, 'season info error: ${widget.info}');
      return null;
    }
    var man = PlaylistManager();
    return await man.queryVideoInfo(content, page, bot);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    Season season = widget.info;
    String? format = season.getString('format', null);
    String? text = season.getString('text', null);
    if (format == 'markdown' && text != null) {
      return _richTextView(context, text);
    } else {
      return _loadingView(widget.info.name);
    }
  }

  Widget _loadingView(String name) {
    Widget view = Text(name,
      style: Styles.sectionItemTitleTextStyle,
    );
    view = Container(
      color: Styles.colors.textMessageBackgroundColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const CupertinoActivityIndicator(),
          const SizedBox(height: 16),
          view,
        ],
      ),
    );
    return view;
  }

  Widget _richTextView(BuildContext ctx, String text) {
    var sender = widget.chat.identifier;
    Widget view = RichTextView(sender: sender, text: text,
      onWebShare: (url, {required title, required desc, required icon}) =>
          ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
      onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
    );
    view = Container(
      color: Styles.colors.textMessageBackgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: view,
    );
    return view;
  }

}
