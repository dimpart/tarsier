import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import 'detail_participants.dart';


class MembersPage extends StatefulWidget {
  const MembersPage(this.info, {super.key});

  final GroupInfo info;

  static void open(BuildContext context, GroupInfo info) => showPage(
    context: context,
    builder: (context) => MembersPage(info),
  );

  @override
  State<StatefulWidget> createState() => _MembersState();
}

class _MembersState extends State<MembersPage> implements lnc.Observer {
  _MembersState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kParticipantsUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
    nc.removeObserver(this, NotificationNames.kParticipantsUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group document updated: $chat');
        await _reload();
      }
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? chat = userInfo?['ID'];
      if (chat == widget.info.identifier) {
        Log.info('group members updated: $chat');
        await _reload();
      }
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Group Members (@count)'.trParams({
        'count': widget.info.members.length.toString(),
      }))
    ),
    body: buildScrollView(
      enableScrollbar: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        child: ParticipantsWidget(widget.info, maxItems: -1),
      ),
    ),
  );

}
