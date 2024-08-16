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

class _WebSiteState extends State<WebSitePage> implements lnc.Observer {
  _WebSiteState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMessageUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMessageUpdated);
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
    if (name == NotificationNames.kMessageUpdated) {
      ID? cid = userInfo?['ID'];
      assert(cid != null, 'notification error: $notification');
      if (cid == widget.chat.identifier) {
        // reload
        _content = null;
        await _load();
      }
    }
  }

  Future<void> _load() async {
    var home = _content;
    if (home != null) {
      return;
    }
    home = await _loadHomePage();
    if (home != null) {
      _content = home;
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  Future<Content?> _loadHomePage() async {
    GlobalVariable shared = GlobalVariable();
    var pair = await shared.database.getInstantMessages(widget.chat.identifier,
        limit: 32);
    List<InstantMessage> messages = pair.first;
    Log.info('checking home page from ${messages.length} messages');
    for (var msg in messages) {
      var content = msg.content;
      var mod = content['mod'];
      var format = content['format'];
      if (mod == 'homepage' && format == 'markdown') {
        // got last one
        return content;
      }
    }
    return null;
  }

  Content? _content;

  @override
  Widget build(BuildContext context) {
    var home = _content;
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
            child: home == null ? _loading() : buildScrollView(
              enableScrollbar: true,
              child: _body(context, home),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() => const CupertinoActivityIndicator();

  Widget _body(BuildContext ctx, Content content) {
    var sender = widget.chat.identifier;
    String text = DefaultMessageBuilder().getText(content, sender);
    Widget view = RichTextView(sender: sender, text: text,
      onWebShare: (url, {required title, required desc, required icon}) =>
          ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
      onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
    );
    return Container(
      padding: Styles.textMessagePadding,
      child: view,
    );
  }

}
