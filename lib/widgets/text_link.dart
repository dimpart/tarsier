import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:dim_flutter/dim_flutter.dart';


typedef OnTapLink = bool Function(String text, {
  required String? href, required String title,
});


class LinkElementBuilder extends MarkdownElementBuilder {
  LinkElementBuilder({this.onTapLink});

  OnTapLink? onTapLink;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final text = element.textContent;
    final href = element.attributes['href'];
    final title = element.attributes['title'] ?? "";
    return _ActiveLink(text: text, href: href, title: title,
      onTapLink: onTapLink,
      textStyle: preferredStyle,
    );
  }

}

class _ActiveLink extends StatefulWidget {
  const _ActiveLink({
    required this.text, required this.href, required this.title,
    this.onTapLink,
    this.textStyle,
  });

  final String text;
  final String? href;
  final String title;

  final OnTapLink? onTapLink;
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
    if (isVisited(href)) {
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
        var man = _SharedLinksManager();
        man.onTap(href);
        if (onTapLink != null) {
          onTapLink(text, href: href, title: title);
        }
        setState(() {});
      },
      child: view,
    );
  }

  bool isVisited(String? href) {
    var man = _SharedLinksManager();
    return man.isVisited(href);
  }
}

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
