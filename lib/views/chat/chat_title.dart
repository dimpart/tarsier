import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;


class ChatTitleView extends StatefulWidget {
  const ChatTitleView(this.info, {required this.style, super.key});

  final Conversation info;
  final TextStyle style;

  static ChatTitleView from(BuildContext context, Conversation info) =>
      ChatTitleView(info, style: Facade.of(context).styles.titleTextStyle);

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
      int state = _stateIndex(info?['current']);
      Log.debug('session state: $state');
      if (mounted) {
        setState(() {
          _sessionState = state;
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
    int state = _stateIndex(shared.terminal.session?.state);
    Log.debug('session state: $state');
    if (mounted) {
      setState(() {
        _sessionState = state;
      });
    }
    if (state == SessionStateOrder.kDefault) {
      // current user must be set before enter this page,
      // so just do connecting here.
      _reconnect(false);
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

int _stateIndex(SessionState? state) =>
    state?.index ?? SessionStateOrder.kDefault;

int _sessionState = SessionStateOrder.kRunning;

String _titleWithState(Conversation info) {
  String? sub;
  switch (_sessionState) {
    case SessionStateOrder.kDefault:
      sub = 'Waiting';  // waiting to connect
      break;
    case SessionStateOrder.kConnecting:
      sub = 'Connecting';
      break;
    case SessionStateOrder.kConnected:
      sub = 'Connected';
      break;
    case SessionStateOrder.kHandshaking:
      sub = 'Handshaking';
      break;
    case SessionStateOrder.kRunning:
      sub = null;  // normal running
      break;
    default:
      sub = 'Disconnected';
      _reconnect(true);
      break;
  }
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

void _reconnect(bool test) async {
  GlobalVariable shared = GlobalVariable();
  if (test) {
    StationSpeeder speeder = StationSpeeder();
    await speeder.reload();
    await speeder.testAll();
    await Future.delayed(const Duration(seconds: 3));
  } else {
    await Future.delayed(const Duration(seconds: 1));
  }
  await shared.terminal.reconnect();
}
