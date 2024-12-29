import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../chat/pick_chat.dart';
import '../chat/share_page.dart';
import '../chat/share_video.dart';


class WebSitePage extends StatefulWidget {
  const WebSitePage(this.chat, this.info, {super.key});

  final Conversation chat;
  final Map info;

  String get title => info['title'] ?? 'Index Page';
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, Map info) => showPage(
    context: context,
    builder: (context) => WebSitePage(chat, info),
  );

  @override
  State<StatefulWidget> createState() => _WebSiteState();

}

class _WebSiteState extends State<WebSitePage> with Logging implements lnc.Observer {
  _WebSiteState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kWebSitesUpdated);
  }

  bool _refreshing = false;

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
    if (!_checkHomepage(content)) {
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

  bool _checkHomepage(Content content) {
    if (content['app'] != 'chat.dim.sites' || content['mod'] != 'homepage') {
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
  Future<Content?> _loadHomepage() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.chat.identifier,
        limit: 32);
    List<InstantMessage> messages = pair.first;
    logInfo('checking home page from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      // check customized info
      if (_checkHomepage(content)) {
        // got last one
        var format = content['format'];
        if (format is String) {
          format = format.toLowerCase();
        }
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
        _queryTag = content.sn;
      });
    }
    content['tag'] = _queryTag;
    content['title'] = title;
    content['keywords'] = keywords;
    content['hidden'] = true;
    // TODO: check visa.key
    ID bot = widget.chat.identifier;
    logInfo('query homepage with tag: $_queryTag, keywords: $keywords, title: "$title"');
    await messenger.sendContent(content, sender: null, receiver: bot);
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    var page = _content;
    if (page == null || _queryTag > 0) {
      // loading
      body = const Center(
        child: CupertinoActivityIndicator(),
      );
    } else if (page['format'] == 'html') {
      // web page
      var sender = widget.chat.identifier;
      String text = DefaultMessageBuilder().getText(page, sender);
      return Browser.view(context, HtmlUri.blank, html: text);
    } else {
      body = _body(context, page);
    }
    return Scaffold(
      backgroundColor: Styles.colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Styles.colors.appBardBackgroundColor,
        // backgroundColor: Styles.themeBarBackgroundColor,
        middle: StatedTitleView.from(context, () => widget.title),
        trailing: _trailing(_refreshBtn(), _shareBtn(context, page)),
      ),
      body: buildScrollView(
        enableScrollbar: true,
        child: body,
      ),
    );
    // var colors = Styles.colors;
    // return Scaffold(
    //   backgroundColor: colors.scaffoldBackgroundColor,
    //   // A ScrollView that creates custom scroll effects using slivers.
    //   body: CustomScrollView(
    //     // A list of sliver widgets.
    //     slivers: <Widget>[
    //       CupertinoSliverNavigationBar(
    //         backgroundColor: colors.appBardBackgroundColor,
    //         // This title is visible in both collapsed and expanded states.
    //         // When the "middle" parameter is omitted, the widget provided
    //         // in the "largeTitle" parameter is used instead in the collapsed state.
    //         largeTitle: Text(widget.title,
    //           style: Styles.titleTextStyle,
    //         ),
    //         trailing: _shareBtn(context, page),
    //       ),
    //       // This widget fills the remaining space in the viewport.
    //       // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
    //       SliverFillRemaining(
    //         hasScrollBody: false,
    //         fillOverscroll: true,
    //         child: body,
    //       ),
    //     ],
    //   ),
    // );
  }

  Widget _trailing(Widget btn1, Widget? btn2) {
    if (btn2 == null) {
      return btn1;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        btn2,
        btn1,
      ],
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

  Widget? _shareBtn(BuildContext ctx, Content? page) {
    if (_queryTag > 0) {
      return null;
    }
    String? text = page?['text'];
    if (text == null || text.isEmpty) {
      return null;
    }
    String title = widget.title;
    String? format = page?['format'];
    format = format?.trim().toLowerCase();
    if (format == 'markdown') {
      // forward as text
    } else {
      assert(false, 'unknown page format: $format');
      return null;
    }
    return IconButton(
      icon: const Icon(
        AppIcons.shareIcon,
        size: Styles.navigationBarIconSize,
        // color: Styles.avatarColor,
      ),
      onPressed: () => PickChatPage.open(ctx,
        onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
          _sharePreview(title, chat),
          okAction: () => _shareMarkdown(chat.identifier,
            title: title, body: text,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext ctx, Content page) {
    var sender = widget.chat.identifier;
    var format = page['format'];
    if (format is String) {
      format = format.toLowerCase();
    }
    String text = DefaultMessageBuilder().getText(page, sender);
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

Future<bool> _shareMarkdown(ID receiver, {required String title, required String body}) async {
  var content = TextContent.create(body);
  content['format'] = 'markdown';
  // if (receiver.isGroup) {
  //   content.group = receiver;
  // }
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver: receiver);
  return true;
}

Widget _sharePreview(String title, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from = _previewText(title);
  Widget body = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      from,
      const SizedBox(width: 32,),
      const Text('~>'),
      const SizedBox(width: 32,),
      to,
    ],
  );
  return body;
}
Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
