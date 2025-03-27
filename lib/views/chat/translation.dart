import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../sharing/share_page.dart';
import '../sharing/share_video.dart';

class TranslatableView extends StatefulWidget {
  const TranslatableView(this.sourceView, this.content, this.sender, {super.key});

  final Widget sourceView;
  final Content content;
  final ID sender;

  bool matchContent(TranslateContent tr) {
    String? text = content.getString('text', null);
    return tr.result?.text == text || tr.tag == content.sn;
  }

  @override
  State<StatefulWidget> createState() => _TranslateState();

}

class _TranslateState extends State<TranslatableView> implements lnc.Observer {
  _TranslateState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kTranslatorReady);
    nc.addObserver(this, NotificationNames.kTranslateUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kTranslateUpdated);
    nc.removeObserver(this, NotificationNames.kTranslatorReady);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // check for the fastest translator
    Translator().testCandidates();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kTranslateUpdated) {
      TranslateContent? content = info?['content'];
      if (content != null && widget.matchContent(content)) {
        await _reload();
      }
    } else if (name == NotificationNames.kTranslatorReady) {
      ID? bot = info?['translator'];
      if (bot != null) {
        await _reload();
      }
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        // refresh
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var tr = Translator();
    //
    //  0. check whether translator is ready
    //
    if (tr.ready == false) {
      // translator not ready
      return widget.sourceView;
    }
    //
    //  1. fetch translation record
    //
    String text = widget.content.getString('text', '')!;
    int tag = widget.content.sn;
    TranslateContent? record = tr.fetch(text, tag);
    String? local = record?.text;
    if (record == null || local == null || local.isEmpty) {
      // translate record not found
      Widget btn;
      if (_isQuerying(widget.content)) {
        btn = const CupertinoActivityIndicator(radius: 6,);
      } else {
        btn = _translateButton(text, tag);
      }
      btn = Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: btn,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.sourceView,
          btn,
        ],
      );
    }
    //
    //  2. show translated result
    //
    var trView = _translatedView(context, record);
    trView = Container(
      color: Styles.colors.textMessageBackgroundColor,
      padding: Styles.textMessagePadding,
      child: trView,
    );
    const radius = Radius.circular(12);
    const borderRadius = BorderRadius.all(radius);
    trView = Container(
      margin: Styles.messageContentMargin,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: trView,
      ),
    );
    var result = record.result;
    String? from = result?.from;
    String? to = result?.to;
    Widget? langView;
    if (from != null || to != null) {
      langView = _translateLanguages(from, to);
      langView = Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: langView,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.sourceView,
        if (langView != null)
          langView,
        trView,
      ],
    );
  }

  Widget _translateButton(String text, int tag) => TextButton(
    style: TextButton.styleFrom(
      foregroundColor: CupertinoColors.systemBlue,
      textStyle: const TextStyle(fontSize: 10, color: CupertinoColors.systemBlue),
      minimumSize: Size.zero,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    onPressed: () => _queryTranslator(text, tag),
    child: Text('Translate'.tr),
  );

  Widget _translateLanguages(String? from, String? to) => Text('$from -> $to',
    style: const TextStyle(
      fontSize: 10,
      color: CupertinoColors.systemGrey,
    ),
  );

  Widget _translatedView(BuildContext ctx, TranslateContent record) {
    String? format = record.getString('format', null);
    String text = record.text ?? '';
    if (format == 'markdown' && text.isNotEmpty) {
      return RichTextView(sender: widget.sender, text: text,
        onWebShare: (url, {required title, required desc, required icon}) =>
            ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon),
        onVideoShare: (playingItem) => ShareVideo.shareVideo(ctx, playingItem),
      );
    } else {
      return SelectableText(text,
        style: TextStyle(color: Styles.colors.textMessageColor),
      );
    }
  }

  void _queryTranslator(String text, int tag) {
    // do querying
    Translator().request(text, tag);
    setState(() {
      // set querying time
      _transQueries[tag] = DateTime.now();
    });
  }

  bool _isQuerying(Content content) {
    var last = _transQueries[content.sn];
    if (last == null) {
      return false;
    }
    var now = DateTime.now();
    var delta = const Duration(seconds: 120);
    return now.subtract(delta).isBefore(last);
  }

}

Map<int, DateTime> _transQueries = {};
