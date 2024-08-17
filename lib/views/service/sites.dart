import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/share_page.dart';
import '../chat/share_video.dart';


class WebSitePage extends StatefulWidget {
  const WebSitePage(this.chat, this.title, {super.key});

  final Conversation chat;
  final String title;

  static void open(BuildContext context, Conversation chat, String title) => showPage(
    context: context,
    builder: (context) => WebSitePage(chat, title),
  );

  @override
  State<StatefulWidget> createState() => _WebSiteState();

}

class _WebSiteState extends State<WebSitePage> with Logging implements lnc.Observer {
  _WebSiteState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kWebSitesUpdated);
  }

  int _queryTag = 9527;
  Content? _content;

  static const Duration kHomepageQueryExpires = Duration(minutes: 32);

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kWebSitesUpdated);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kWebSitesUpdated) {
      logInfo('web sites updated: $name, $userInfo');
      var content = userInfo?['cmd'];
      if (content is Content) {
        await _refreshHomepage(content, isRefresh: true);
      }
    }
  }

  Future<void> _refreshHomepage(Content content, {required bool isRefresh}) async {
    // check customized info
    String? app = content['app'];
    String? mod = content['mod'];
    String? act = content['act'];
    if (app == 'chat.dim.sites' && mod == 'homepage') {
      assert(act == 'respond', 'content error: $content');
    } else {
      assert(false, 'content error: $content');
      return;
    }
    // check tag
    int? tag = content['tag'];
    if (!isRefresh) {
      // update from local
      _queryTag = 0;
    } else if (tag == _queryTag) {
      // update from remote
      _queryTag = 0;
    } else {
      logWarning('query tag not match, ignore this response: $tag <> $_queryTag');
      return;
    }
    // refresh
    if (mounted) {
      setState(() {
        _content = content;
      });
    }
  }

  /// load from local storage
  Future<Content?> _loadHomepage() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.chat.identifier,
        limit: 32);
    List<InstantMessage> messages = pair.first;
    logInfo('checking home page from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      var mod = content['mod'];
      var format = content['format'];
      if (mod == 'homepage') {
        // got last one
        if (format == 'markdown' || format == 'html') {
          return content;
        }
      }
    }
    return null;
  }

  Future<void> _load() async {
    // check old records
    var content = await _loadHomepage();
    if (content == null) {
      // query for new records
      logInfo('query sites first');
      await _query();
      return;
    }
    // check record time
    var time = content.time;
    if (time == null) {
      logError('sites content error: $content');
      await _query();
    } else {
      int? expires = content.getInt('expires', null);
      if (expires == null || expires <= 8) {
        expires = kHomepageQueryExpires.inSeconds;
      }
      int later = time.millisecondsSinceEpoch + expires * 1000;
      var now = DateTime.now().millisecondsSinceEpoch;
      if (now > later) {
        logInfo('query sites again');
        await _query();
      }
    }
    // refresh with content loaded
    await _refreshHomepage(content, isRefresh: false);
  }
  // query for new records
  Future<void> _query() async {
    logWarning('query sites with title: "${widget.title}"');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      logError('messenger not set, not connect yet?');
      return;
    }
    // build command
    var content = TextContent.create(widget.title);
    _queryTag = content.sn;
    content['tag'] = _queryTag;
    content['hidden'] = true;
    // TODO: check visa.key
    ID bot = widget.chat.identifier;
    logInfo('query homepage with tag: $_queryTag');
    await messenger.sendContent(content, sender: null, receiver: bot);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    var page = _content;
    if (page == null) {
      // loading
      body = const CupertinoActivityIndicator();
    } else if (page['format'] == 'html') {
      // web page
      var sender = widget.chat.identifier;
      String text = DefaultMessageBuilder().getText(page, sender);
      return Browser.view(context, HtmlUri.blank, html: text);
    } else {
      body = _body(context, page);
    }
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      body: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            backgroundColor: colors.appBardBackgroundColor,
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text(widget.title,
              style: Styles.titleTextStyle,
            ),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: body,
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext ctx, Content content) {
    var sender = widget.chat.identifier;
    var format = content['format'];
    String text = DefaultMessageBuilder().getText(content, sender);
    Widget? view;
    if (format == 'markdown') {
      // show RichText
      view = RichTextView(sender: sender, text: text,
        onWebShare: (url, {required title, required desc, required icon}) =>
            ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
        onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
      );
    } else {
      view = Text(text,);
    }
    view = Container(
      padding: Styles.textMessagePadding,
      child: view,
    );
    return buildScrollView(
      enableScrollbar: true,
      child: view,
    );
  }

}
