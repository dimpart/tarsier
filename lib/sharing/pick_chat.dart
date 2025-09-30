import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';


typedef PickChatCallback = void Function(Conversation chat);

class PickChatPage extends StatefulWidget {
  const PickChatPage({super.key, required this.onPicked});

  final PickChatCallback onPicked;

  static void open(BuildContext context, {required PickChatCallback onPicked}) =>
      showPage(
        context: context,
        builder: (context) => PickChatPage(onPicked: onPicked),
      );

  @override
  State<StatefulWidget> createState() => _PickChatState();
}

class _PickChatState extends State<PickChatPage> with SectionAdapterMixin {
  _PickChatState() : _clerk = Amanuensis();

  final Amanuensis _clerk;

  Future<void> _reload() async {
    List<Conversation> chats = await _clerk.loadConversations();
    for (Conversation item in chats) {
      await item.reloadData();
    }
    if (mounted) {
      setState(() {
        notifyDataChange();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  int numberOfItems(int section) => _clerk.conversations.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    List<Conversation> conversations = _clerk.conversations;
    if (indexPath.item >= conversations.length) {
      Log.error('out of range: ${conversations.length}, $indexPath');
      return const Text('');
    }
    Conversation info = conversations[indexPath.item];
    Log.warning('show item: $info');
    return _PickChatCell(info, () {
      closePage(context);
      widget.onPicked(info);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Select a Chat'.tr),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: this,
    ),
  );
}

/// TableCell for Conversations
class _PickChatCell extends StatefulWidget {
  const _PickChatCell(this.info, this.onTap);

  final Conversation info;
  final GestureTapCallback? onTap;

  @override
  State<StatefulWidget> createState() => _PickChatCellState();

}

class _PickChatCellState extends State<_PickChatCell> {
  _PickChatCellState();

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: widget.info.getImage(),
    title: widget.info.getNameLabel(),
    trailing: const CupertinoListTileChevron(),
    onTap: widget.onTap,
  );

}


Row forwardPreview(Widget from, Widget to) => Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    from,
    const SizedBox(width: 16,),
    const Icon(AppIcons.forwardIcon, size: 16,),
    const SizedBox(width: 16,),
    to,
  ],
);
