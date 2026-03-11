import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:dim_flutter/dim_flutter.dart';


typedef OnTapLink = bool Function(String text, {
  required String? href, required String title,
});


class LinkElementBuilder extends MarkdownElementBuilder {
  LinkElementBuilder({required this.onTapLink});

  final OnTapLink onTapLink;

  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element, TextStyle? preferredStyle, TextStyle? parentStyle) {
    final children = element.children;
    if (children == null || children.isEmpty) {
      // empty link
      return null;
    }
    for (var child in children) {
      if (child is md.Text) {
        continue;
      }
      // not a pure text link, ignore it
      return super.visitElementAfterWithContext(context, element, preferredStyle, parentStyle);
    }
    // build active text link
    final text = element.textContent;
    final href = element.attributes['href'];
    final title = element.attributes['title'] ?? "";
    return _ActiveLink(text: text, href: href, title: title,
      onTapLink: onTapLink,
      textStyle: preferredStyle ?? parentStyle,
    );
  }

}

class _ActiveLink extends StatefulWidget {
  const _ActiveLink({
    required this.text, required this.href, required this.title,
    required this.onTapLink,
    this.textStyle,
  });

  final String text;
  final String? href;
  final String title;

  final OnTapLink onTapLink;
  final TextStyle? textStyle;

  @override
  State<StatefulWidget> createState() => _ActiveLinkState();

}

class _ActiveLinkState extends State<_ActiveLink> {

  @override
  Widget build(BuildContext context) {
    var text = widget.text;
    var href = widget.href;
    var title = widget.title;
    final onTapLink = widget.onTapLink;
    var textStyle = widget.textStyle;
    if (sharedLinksManager.isVisited(href)) {
      textStyle = textStyle?.copyWith(
        color: CupertinoColors.systemPurple,
      );
    }
    Widget view = Text(
      text,
      style: textStyle,
    );
    // view = Transform.translate(
    //   offset: const Offset(-1.5, 0),
    //   child: view,
    // );
    return GestureDetector(
      onTap: () {
        onTapLink(text, href: href, title: title);
        setState(() {
          sharedLinksManager.onTap(href);
        });
      },
      child: view,
    );
  }

}

final sharedLinksManager = _SharedLinksManager();

class _SharedLinksManager {
  factory _SharedLinksManager() => _instance;
  static final _SharedLinksManager _instance = _SharedLinksManager._internal();
  _SharedLinksManager._internal();

  final Map<String, bool> visitedLinks = {};

  void onTap(String? href) {
    visitedLinks[_key(href)] = true;
  }

  bool isVisited(String? href) {
    bool? visited = visitedLinks[_key(href)];
    return visited ?? false;
  }

  String _key(String? href) {
    if (href == null || href.isEmpty) {
      return 'about:blank';
    }
    Uint8List data = UTF8.encode(href);
    data = MD5.digest(data);
    return Hex.encode(data);
  }

}
