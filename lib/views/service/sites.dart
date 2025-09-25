import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import '../../sharing/pick_chat.dart';
import '../../sharing/share_page.dart';
import '../../sharing/share_video.dart';
import '../../widgets/text.dart';
import 'base.dart';


class WebSitePage extends StatefulWidget {
  const WebSitePage(this.chat, this.info, {super.key});

  final Conversation chat;
  final ServiceInfo info;

  String get title => info['title'] ?? 'Index Page'.tr;
  String? get keywords => info['keywords'];

  static void open(BuildContext context, Conversation chat, ServiceInfo info) => showPage(
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

  int _queryTag = 9527;  // show CupertinoActivityIndicator
  Content? _content;

  /// loading after enter
  bool get isLoading => !(_queryTag == 0 || _refreshing);

  /// waiting for update
  bool get isQuerying => _queryTag != 0; // && _queryTag != 9527;

  /// refreshed or timeout
  bool get isRefreshFinished => _queryTag == 0;

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

  Future<void> _load() async {
    // check old records
    var shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    var content = await handler.getContent(widget.chat.identifier, 'homepage', widget.title);
    if (content == null) {
      // query for new records
      logInfo('query homepage first: "${widget.title}"');
    } else {
      logInfo('query homepage again: "${widget.title}"');
      // refresh with content loaded
      await _refreshHomepage(content, isRefresh: false);
    }
    // query to update content
    await _query(content);
  }

  // query service bot to refresh content
  Future<void> _query([Content? old]) async {
    var content = await widget.info.request(old);
    if (content == null) {
      // old content not expired yet
      return;
    }
    _queryTag = content.sn;
    logInfo('query homepage with tag: $_queryTag');
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      // backgroundColor: Styles.themeBarBackgroundColor,
      middle: StatedTitleView.from(context, () => widget.title),
      trailing: _shareBtn(context, _content),
    ),
    body: RefreshIndicator(
      onRefresh: _refreshList,
      child: buildScrollView(
        enableScrollbar: true,
        child: _body(context),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    Widget body;
    var page = _content;
    if (page == null) {
      // body empty
      return const Center(child: CupertinoActivityIndicator());
    } else if (page['format'] == 'html' || page['HTML'] != null) {
      // web page
      body = _htmlView(context, page);
      if (isQuerying) {
        // TODO: show refreshing indicator
      }
      return body;
    } else if (page['URL'] != null) {
      // web page
      Widget? web = _webView(context, page);
      if (web != null) {
        return web;
      }
      // error
      var url = page['URL'];
      body = Text('Failed to open URL: $url');
      body = _wrapTextView(body);
    } else {
      // plaintext, markdown, ...
      body = _textView(context, page);
      body = _wrapTextView(body);
    }
    if (isLoading) {
      // refreshing
      body = Stack(
        alignment: Alignment.topCenter,
        children: [
          body,
          const CupertinoActivityIndicator(),
        ],
      );
    }
    return body;
  }

  Future<void> _refreshList() async {
    _refreshing = true;
    // force to refresh
    await _query();
    // waiting for response
    await untilConditionTrue(() => isRefreshFinished);
    _refreshing = false;
  }

  Widget? _shareBtn(BuildContext ctx, Content? page) {
    if (isQuerying) {
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

  Widget? _webView(BuildContext ctx, Content page) {
    Uri? url = HtmlUri.parseUri(page.getString('URL'));
    if (url == null) {
      return null;
    }
    return Browser.view(context, url);
  }

  Widget _htmlView(BuildContext ctx, Content page) {
    var sender = widget.chat.identifier;
    String? html = page.getString('HTML');
    html ??= DefaultMessageBuilder().getText(page, sender);
    return Browser.view(context, HtmlUri.blank, html: html);
  }

  Widget _textView(BuildContext ctx, Content page) {
    var sender = widget.chat.identifier;
    String text = DefaultMessageBuilder().getText(page, sender);
    if (page['format'] == 'markdown') {
      // show RichText
      return RichTextView(sender: sender, text: text,
        onWebShare: (url, {required title, required desc, required icon}) =>
            ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
        onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
      );
    } else {
      // show plaintext
      return Text(text,);
    }
  }

  Widget _wrapTextView(Widget body) {
    Widget view = Container(
      padding: Styles.textMessagePadding,
      child: body,
    );
    return buildScrollView(
      enableScrollbar: true,
      child: view,
    );
  }

}

Future<bool> _shareMarkdown(ID receiver, {required String title, required String body}) async {
  // "data:text/plain;charset=UTF-8;base64,"
  var base64 = Base64.encode(UTF8.encode(body));
  var link = 'data:text/plain;charset=UTF-8;base64,$base64';
  var text = '[$title]($link "")';
  var content = TextContent.create(text);
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
  return forwardPreview(from, to);
}
Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
