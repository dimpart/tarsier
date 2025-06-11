import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import '../../widgets/text.dart';
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
        int? tag = content.tag;
        if (tag != null) {
          _transQueries.remove(tag);
        }
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
      String? warning;
      Widget btn;
      if (_isQuerying(widget.content)) {
        warning = tr.warning;
        btn = const CupertinoActivityIndicator(radius: 6,);
      } else {
        String? format = widget.content.getString('format', null);
        btn = _translateButton(context, text, tag, format: format);
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
          if (warning != null && warning.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(warning, style: Styles.translatorTextStyle,),
            ),
        ],
      );
    }
    //
    //  2. show translated result
    //
    var trView = _translatedView(context, record);
    if (trView != null) {
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
    }
    // create panel view for translation
    var trPanel = _foldButton(record.folded, record);
    var result = record.result;
    String? from = result?.from;
    String? to = result?.to;
    if (from != null || to != null) {
      trPanel = Row(
        children: [
          _translateLanguages(from, to),
          const SizedBox(width: 8,),
          trPanel,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.sourceView,
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: trPanel,
        ),
        if (trView != null)
          trView,
      ],
    );
  }

  Widget _translateButton(BuildContext ctx, String text, int tag, {required String? format}) => TextButton(
    style: Styles.translateButtonStyle,
    onPressed: () => _queryTranslator(ctx, text, tag, format: format),
    child: Text('Translate'.tr),
  );

  Widget _translateLanguages(String? from, String? to) => Text('$from >> $to',
    style: const TextStyle(
      fontSize: 10,
      color: CupertinoColors.systemGrey,
    ),
  );

  Widget _foldButton(bool folded, TranslateContent content) => TextButton(
    style: Styles.translateButtonStyle,
    onPressed: () => setState(() {
      content.folded = !folded;
    }),
    child: Text(folded ? 'Show'.tr : 'Hide'.tr),
  );

  Widget? _translatedView(BuildContext ctx, TranslateContent record) {
    if (record.folded) {
      return null;
    }
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

  void _queryTranslator(BuildContext ctx, String text, int tag, {required String? format}) {
    var warning = Translator().warning;
    if (warning == null || warning.isEmpty) {
      _doQuery(text, tag, format: format);
    } else if (_transConfirmed) {
      _doQuery(text, tag, format: format);
    } else {
      Alert.confirm(ctx, 'Confirm', warning,
        okAction: () => _doQuery(text, tag, format: format),
      );
    }
  }
  void _doQuery(String text, int tag, {required String? format}) {
    Translator().request(text, tag, format: format);
    setState(() {
      // set querying time
      _transQueries[tag] = DateTime.now();
      _transConfirmed = true;
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
bool _transConfirmed = false;
