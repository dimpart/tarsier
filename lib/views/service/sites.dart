import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../../sharing/pick_chat.dart';
import '../../sharing/share_contact.dart';
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
  Widget build(BuildContext context) {
    Widget? body;
    var page = _content;
    if (page == null) {
      // body empty
    } else if (page['format'] == 'html') {
      // web page
      var sender = widget.chat.identifier;
      String text = DefaultMessageBuilder().getText(page, sender);
      body = Browser.view(context, HtmlUri.blank, html: text);
      if (_queryTag == 0) {
        return body;
      }
      // TODO: show refreshing indicator
      return body;
    } else {
      // plaintext, markdown, ...
      body = _body(context, page);
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
    // force to refresh
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
