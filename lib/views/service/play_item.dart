import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../sharing/share_page.dart';
import '../sharing/share_video.dart';


class Season extends Dictionary {
  Season(super.dict);

  static Duration kExpires = const Duration(minutes: 32);

  /// create time
  DateTime? get time => getDateTime('time', null);

  bool isExpired({DateTime? now}) {
    var lastTime = time;
    if (lastTime == null) {
      return true;
    } else {
      now ??= DateTime.now();
    }
    var expired = lastTime.add(kExpires);
    return now.isAfter(expired);
  }

  @override
  String toString() {
    Type clazz = runtimeType;
    return '<$clazz name="$name" />';
  }

  // playing page URL
  Uri? get page => HtmlUri.parseUri(this['page']);

  // video name
  String get name => getString('name', '')!;

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

  static const Duration kPlayItemQueryExpires = Duration(minutes: 32);

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
      logInfo('video info updated: $name, $userInfo');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshPlayInfo(content, isRefresh: true);
      }
    }
  }

  Future<bool> _refreshPlayInfo(Content content, {required bool isRefresh}) async {
    Map? season = content['season'];
    season ??= content;
    if (season['page'] != widget.info['page']) {
      return false;
    }
    var format = content['format'];
    var text = content['text'];
    logInfo('refreshing play item with format: $format, size: ${text?.length}');
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
    String page = season['page'] ?? season.name;
    // check old records
    var shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    var content = await handler.getContent(widget.chat.identifier, 'season', page);
    if (content == null) {
      // query for new records
      logInfo('query video info first');
      await _query();
      return;
    }
    // check record time
    var time = content.time;
    if (time == null) {
      logError('video info error: $content');
      await _query();
    } else if (content['format'] != 'markdown') {
      logError('video format error: $content');
      await _query();
    } else {
      int? expires = content.getInt('expires', null);
      if (expires == null || expires <= 8) {
        expires = kPlayItemQueryExpires.inSeconds;
      }
      int later = time.millisecondsSinceEpoch + expires * 1000;
      var now = DateTime.now().millisecondsSinceEpoch;
      if (now > later) {
        logInfo('query video info again');
        await _query();
      }
    }
    // refresh with content loaded
    await _refreshPlayInfo(content, isRefresh: false);
  }
  // query for new records
  Future<void> _query() async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      logError('messenger not set, not connect yet?');
      return;
    }
    Season season = widget.info;
    String page = season['page'];
    // build command
    var content = CustomizedContent.create(app: 'chat.dim.video', mod: 'season', act: 'request');
    content['page'] = page;
    content['format'] = 'markdown';
    content['hidden'] = true;
    // TODO: check visa.key
    ID bot = widget.chat.identifier;
    logInfo('query video info: "$page"');
    await messenger.sendContent(content, sender: null, receiver: bot);
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
