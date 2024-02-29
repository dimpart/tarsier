import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;


class ChatTitleView extends StatefulWidget {
  const ChatTitleView(this.info, {required this.style, super.key});

  final Conversation info;
  final TextStyle style;

  static ChatTitleView from(BuildContext context, Conversation info) =>
      ChatTitleView(info, style: Styles.titleTextStyle);

  @override
  State<StatefulWidget> createState() => _TitleState();

}

class _TitleState extends State<ChatTitleView> implements lnc.Observer {
  _TitleState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kServerStateChanged);
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kMembersUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMembersUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    nc.removeObserver(this, NotificationNames.kServerStateChanged);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    if (name == NotificationNames.kServerStateChanged) {
      GlobalVariable shared = GlobalVariable();
      int state = shared.terminal.sessionStateOrder;
      Log.debug('session state: $state');
      if (mounted) {
        setState(() {
        });
      }
    } else if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == widget.info.identifier) {
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    } else if (name == NotificationNames.kMembersUpdated) {
      ID? identifier = info?['ID'];
      if (identifier == widget.info.identifier) {
        await widget.info.reloadData();
        if (mounted) {
          setState(() {
            // refresh
          });
        }
      }
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    int state = shared.terminal.sessionStateOrder;
    Log.debug('session state: $state');
    if (mounted) {
      setState(() {
      });
    }
    if (state == SessionStateOrder.init.index) {
      // current user must be set before enter this page,
      // so just do connecting here.
      shared.terminal.reconnect();
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Text(
    _titleWithState(widget.info),
    style: widget.style,
  );

}

String _titleWithState(Conversation info) {
  GlobalVariable shared = GlobalVariable();
  String? sub = shared.terminal.sessionStateText;
  String name = _trimName(info.name);
  if (sub == null) {
    if (info is GroupInfo) {
      int count = info.members.length;
      return '$name ($count)';
    }
    return info.title;
  }
  return '$name ($sub)';
}
String _trimName(String name) {
  name = name.trim();
  String text = '';
  int i = 0, j = 0;
  for (; i < name.length; ++i, ++j) {
    text += name[i];
    if (name.codeUnitAt(i) > 127) {
      ++j;
    }
    if (j > 15) {
      break;
    }
  }
  return i < name.length ? '$text...' : name;
}
