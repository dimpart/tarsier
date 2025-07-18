import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:dim_flutter/dim_flutter.dart';

import '../sharing/pick_chat.dart';
import '../sharing/share_contact.dart';


class TextPreviewPage extends StatefulWidget {
  const TextPreviewPage({super.key,
    required this.text,
    required this.format,
    required this.sender,
    required this.onWebShare,
    required this.onVideoShare,
  });

  final String text;
  final String? format;
  final ID sender;
  final OnWebShare? onWebShare;
  final OnVideoShare? onVideoShare;

  static void open(BuildContext ctx, {
    required ID sender,
    required String text,
    required String? format,
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
  }) => showPage(
    context: ctx,
    builder: (context) => TextPreviewPage(
      text: text,
      format: format,
      sender: sender,
      onWebShare: onWebShare,
      onVideoShare: onVideoShare,
    ),
  );

  @override
  State<StatefulWidget> createState() => _TextPreviewState();

}

class _TextPreviewState extends State<TextPreviewPage> {

  String? _back;
  bool _previewing = false;

  @override
  void initState() {
    super.initState();
    setState(() {
      _previewing = widget.format == 'markdown';
    });
    _refresh();
  }

  void _refresh() async {
    GlobalVariable shared = GlobalVariable();
    String name = await shared.facebook.getName(widget.sender);
    if (mounted) {
      setState(() {
        _back = name;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      previousPageTitle: _back,
      trailing: _trailing(_shareBtn(context), _previewing ? _richButton() : _plainButton()),
    ),
    body: GestureDetector(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: buildScrollView(
              enableScrollbar: true,
              child: _body(),
            ),
          ),
        ],
      ),
      onTap: () => closePage(context),
    ),
  );

  Widget _trailing(Widget btn1, Widget btn2) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      btn1,
      btn2,
    ],
  );
  Widget _shareBtn(BuildContext ctx) => IconButton(
    icon: const Icon(AppIcons.shareIcon,
      color: CupertinoColors.systemGrey,
      size: 24,
    ),
    onPressed: () => PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
        _sharePreview(widget.text, chat),
        okAction: () => _shareMarkdown(
          text: widget.text,
          format: widget.format,
          receiver: chat.identifier,
        ),
      ),
    ),
  );
  Widget _plainButton() => IconButton(
    icon: const Icon(AppIcons.plainTextIcon,
      color: CupertinoColors.systemGrey,
      size: 24,
    ),
    onPressed: () => setState(() => _previewing = true),
  );
  Widget _richButton() => IconButton(
    icon: const Icon(AppIcons.richTextIcon,
      color: CupertinoColors.link,
      size: 24,
    ),
    onPressed: () => setState(() => _previewing = false),
  );

  Widget _body() => Container(
    padding: const EdgeInsets.fromLTRB(32, 32, 32, 64),
    alignment: AlignmentDirectional.centerStart,
    color: Styles.colors.textMessageBackgroundColor,
    child: _previewing ? _richText() : _plainText(),
  );
  Widget _plainText() => SelectableText(
    widget.text,
    style: const TextStyle(
      fontSize: 22,
    ),
  );
  Widget _richText() => RichTextView(
    sender: widget.sender,
    text: widget.text,
    onWebShare: widget.onWebShare,
    onVideoShare: widget.onVideoShare,
  );

}

Future<bool> _shareMarkdown({
  required String text,
  required String? format,
  required ID receiver
}) async {
  var content = TextContent.create(text);
  if (format != null) {
    content['format'] = format;
  }
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


class RichTextView extends StatefulWidget {
  const RichTextView({super.key,
    required this.sender,
    required this.text,
    required this.onWebShare,
    required this.onVideoShare,
  });

  final ID sender;
  final String text;
  final OnWebShare? onWebShare;
  final OnVideoShare? onVideoShare;

  @override
  State<StatefulWidget> createState() => _RichTextState();

}

class _RichTextState extends State<RichTextView> {

  @override
  Widget build(BuildContext context) => MarkdownBody(
    data: widget.text,
    selectable: true,
    extensionSet: md.ExtensionSet.gitHubWeb,
    syntaxHighlighter: SyntaxManager().getHighlighter(),
    onTapLink: (text, href, title) => _MarkdownUtils.openLink(context,
      sender: widget.sender,
      text: text, href: href, title: title,
      onWebShare: widget.onWebShare,
      onVideoShare: widget.onVideoShare,
    ),
    imageBuilder: (url, title, alt) => _MarkdownUtils.buildImage(context,
      url: url, title: title, alt: alt,
    ),
  );

}


enum _MimeType {
  image,
  video,
  lives,  // 'lives.txt'
  other,
}
final List<String> _imageTypes = [
  'jpg', 'jpeg',
  'png',
  // 'gif',
  // 'bmp',
];
final List<String> _videoTypes = [
  'mp4',
  'mov',
  'avi',
  // 'wmv',
  // 'mkv',
  'mpg', 'mpeg',
  // '3gp', '3gpp',
  // 'rm', 'rmvb',
  'm3u', 'm3u8',
];

_MimeType? _checkFileType(String urlString) {
  // check extension (maybe the tail of query string)
  int pos = urlString.lastIndexOf('.');
  if (pos > 0) {
    String ext = urlString.substring(pos + 1).toLowerCase();
    if (_imageTypes.contains(ext)) {
      return _MimeType.image;
    } else if (_videoTypes.contains(ext)) {
      return _MimeType.video;
    }
  }
  return null;
}
Future<_MimeType> _checkUrlType(Uri url) async {
  _MimeType? type;
  // check for live stream
  if (url.hasFragment) {
    String text = url.toString();
    if (text.endsWith(r'#lives.txt')) {
      type = _MimeType.lives;
    // } else if (text.endsWith(r'#live') || text.contains(r'#live/')) {
    //   // video
    }
  }
  // check file type
  type ??= _checkFileType(url.path);
  if (type == null && (url.hasQuery || url.hasFragment)) {
    type ??= _checkFileType(url.toString());
  }
  type ??= _MimeType.other;  // TODO: check from HTTP head
  return type;
}


abstract class _MarkdownUtils {

  static void openLink(BuildContext context, {
    required ID sender,
    required String text,
    required String? href,
    required String title,
    required OnWebShare? onWebShare,
    required OnVideoShare? onVideoShare,
  }) {
    Log.info('openLink: text="$text" href="$href" title="$title"');
    if (href == null || href.isEmpty) {
      return;
    }
    Uri? url = HtmlUri.parseUri(href);
    if (url == null) {
      Log.error('link href invalid: $href');
      Alert.show(context, 'Error', 'URL error: "$href"');
      return;
    } else if (url.scheme != 'http' && url.scheme != 'https') {
      assert(url.scheme == 'data', 'unknown link href: $href');
      Log.info('open data link: $url');
      // - data:text/html;charset=UTF-8;base64,
      // - data:text/plain;charset=UTF-8;base64,
      String path = url.path;
      if (path.startsWith('text/plain;')) {
        String? plain = _parseText(href);
        if (plain == null) {
          Log.error('text url error: $href');
          Alert.show(context, 'Error', 'Data error: "$href"');
        } else {
          TextPreviewPage.open(context,
            text: plain,
            format: 'markdown',
            sender: sender,
            onWebShare: onWebShare, onVideoShare: onVideoShare,
          );
        }
      } else {
        assert(path.startsWith('text/html;'), 'data url error: $href');
        Browser.openURL(context, url, onWebShare: onWebShare,);
      }
      return;
    }
    _checkUrlType(url).then((type) {
      if (!context.mounted) {
        Log.warning('context unmounted: $context');
      } else if (type == _MimeType.image) {
        // show image
        Log.info('preview image: $url');
        var imageContent = FileContent.image(url: url,
          password: Password.kPlainKey,
        );
        _previewImage(context, imageContent);
      } else if (type == _MimeType.video) {
        // show video
        Log.info('play video: "$title" $url, text: "$text"');
        var filename = Paths.filename(url.path);
        var pair = _parseTitleInfo(title);
        var playingItem = MediaItem.create(url, title: pair.first, filename: filename);
        playingItem['snapshot'] = pair.second;
        VideoPlayerPage.openVideoPlayer(context, playingItem, onShare: onVideoShare);
      } else if (type == _MimeType.lives) {
        Log.info('open video player for live streams: "$title" $url, text: "$text"');
        VideoPlayerPage.openLivePlayer(context, url, onShare: onVideoShare);
      } else {
        Log.info('open link with type: $type, "$title" $url, text: "$text"');
        // open other link
        Browser.openURL(context, url, onWebShare: onWebShare,);
      }
    });
  }

  // - data:text/plain;charset=UTF-8;base64,
  static String? _parseText(String href) {
    Uint8List? data = _parseData(href);
    if (data == null) {
      assert(false, 'failed to decode text body: $href');
      return null;
    }
    return UTF8.decode(data);
  }
  static Uint8List? _parseData(String href) {
    int pos = href.indexOf(',');
    if (pos > 6) {
      assert(href.substring(pos - 6, pos) == 'base64', 'data url error: $href');
    } else {
      pos = href.lastIndexOf(';');
      if (pos < 0) {
        Log.error('data url error: $href');
        return null;
      }
    }
    String body = href.substring(pos + 1);
    return Base64.decode(body);
  }

  /// Get title and cover
  static Pair<String, String?> _parseTitleInfo(String text) {
    // Snapshot in alt text:
    //      [$title; cover=$cover]
    String title;
    String? cover;
    int pos;
    // get cover
    pos = text.indexOf('; cover=');
    if (pos > 0) {
      cover = text.substring(pos + 8);
      cover = cover.trim();
      text = text.substring(0, pos);
    }
    title = text.trim();
    return Pair(title, cover);
  }

  //
  //  Image
  //

  static Widget buildImage(BuildContext context, {
    required Uri url,
    required String? title,
    required String? alt,
  }) {
    String scheme = url.scheme;
    if (scheme == 'data') {
      // - data:image/png;base64,
      Uint8List? data = _parseData(url.toString());
      if (data == null) {
        Log.error('failed to decode text body: $url');
        return _errorImage(url, title: title, alt: alt);
      }
      Widget imageView = ImageUtils.memoryImage(data);
      return Container(
        constraints: const BoxConstraints(maxHeight: 256),
        child: imageView,
      );
    } else if (scheme != 'http' && scheme != 'https') {
      Log.error('image url error: $url');
      return _errorImage(url, title: title, alt: alt);
    }
    var plain = Password.kPlainKey;
    var imageContent = FileContent.image(url: url, password: plain);
    var pnf = PortableNetworkFile.parse(imageContent.toMap());
    // check file type
    _MimeType? type = _checkFileType(url.path);
    if (type == null && (url.hasQuery || url.hasFragment)) {
      type ??= _checkFileType(url.toString());
    }
    Widget imageView;
    if (type != _MimeType.image) {
      Log.warning('unknown image url: $url');
      imageView = ImageUtils.networkImage(url.toString());
    } else if (pnf == null) {
      assert(false, 'should not happen: $url => $imageContent');
      imageView = ImageUtils.networkImage(url.toString());
    } else {
      imageView = NetworkImageFactory().getImageView(pnf);
    }
    return GestureDetector(
      onDoubleTap: () => _previewImage(context, imageContent),
      onLongPress: () => Alert.actionSheet(context, null, null,
        Alert.action(AppIcons.saveFileIcon, 'Save to Album'),
            () => saveImageContent(context, imageContent),
        // 'Save Image', () { },
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 256),
        child: imageView,
      ),
    );
  }

  static Widget _errorImage(Uri url, {required String? title, required String? alt}) {
    String src = url.toString();
    if (src.length > 128) {
      String head = src.substring(0, 120);
      String tail = src.substring(src.length - 5);
      src = '$head...$tail';
    }
    return Text(
      '<img src="$src" title="$title" alt="$alt" />',
      style: const TextStyle(color: CupertinoColors.systemRed),
    );
  }

  static void _previewImage(BuildContext ctx, ImageContent imageContent) {
    var head = Envelope.create(sender: ID.ANYONE, receiver: ID.ANYONE);
    var msg = InstantMessage.create(head, imageContent);
    previewImageContent(ctx, imageContent, [msg]);
  }

}
