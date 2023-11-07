import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;


class ChatSendFlag extends StatefulWidget {
  const ChatSendFlag(this.iMsg, {super.key});

  final InstantMessage iMsg;

  @override
  State<StatefulWidget> createState() => _SendState();

}

enum _MsgStatus {
  kDefault,
  kWaiting,   // sending out, or waiting file data upload
  kSent,      // MTA respond
  kBlocked,   // blocked by receiver
  kReceived,  // receiver respond
  kExpired;   // failed
}

final Map<int, _MsgStatus> _flags = {};

class _SendState extends State<ChatSendFlag> implements lnc.Observer {
  _SendState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kMessageTraced);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMessageTraced);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kMessageTraced) {
      if (userInfo == null) {
        Log.error('notification error: $userInfo');
        return;
      }
      ID? sender = userInfo['sender'];
      int? sn = userInfo['sn'];
      String? signature = userInfo['signature'];
      ID? mta = ID.parse(userInfo['mta']?['ID']);
      Log.debug('checking status: $signature, $mta');
      // delay a while to wait the list updated
      await Future.delayed(const Duration(milliseconds: 256));
      if (sender == null || sn == null || mta == null) {
        Log.error('notification error: $userInfo');
      } else if (_match(sender: sender, sn: sn, signature: signature)) {
        // if match this message, refresh its status
        Log.debug('refreshing status: $signature');
        String? text = userInfo['text'];
        if (text != null && text.startsWith('Message is blocked')) {
          _flags[sn] = _MsgStatus.kBlocked;
        }
        _refresh(sn: sn, mta: mta);
      }
    }
  }

  /// check whether match current message
  bool _match({required ID sender, required int sn, required String? signature}) {
    InstantMessage iMsg = widget.iMsg;
    if (sender != iMsg.sender) {
      Log.debug('sender not match: $sender, ${iMsg.sender}');
      return false;
    }
    if (sn > 0) {
      Log.debug('check by sn: $sn, ${iMsg.content.sn}, sender: $sender');
      return sn == iMsg.content.sn;
    } else if (signature == null) {
      Log.error('sn & signature should not be empty at the same time');
      return false;
    } else if (signature.length > 8) {
      signature = signature.substring(signature.length - 8);
    }
    String? sig = iMsg.getString('signature', null);
    if (sig == null) {
      Log.warning('signature not found');
      return false;
    } else if (sig.length > 8) {
      sig = sig.substring(sig.length - 8);
    }
    Log.debug('comparing signatures: $signature, $sig, ${iMsg.content['text']}');
    return signature == sig;
  }

  /// refresh status of current message
  Future<_MsgStatus> _refresh({required int sn, required ID mta}) async {
    if (sn == 0) {
      sn = widget.iMsg.content.sn;
    }
    assert(sn > 0, 'sn error: $sn');
    _MsgStatus? current = _flags[sn];
    if (current == _MsgStatus.kBlocked) {
      Log.warning('message is blocked');
      if (mounted) {
        setState(() {
        });
      }
    } else if (current == _MsgStatus.kReceived) {
      Log.warning('message already received, ignore: $sn, $mta');
    } else if (mta == widget.iMsg.receiver) {
      current = _MsgStatus.kReceived;
      _flags[sn] = current;
      if (mounted) {
        setState(() {
        });
      }
    } else if (mta.type == EntityType.kStation) {
      current = _MsgStatus.kSent;
      _flags[sn] = current;
      if (mounted) {
        setState(() {
        });
      }
    } else if (await _checkMember(mta)) {
      current = _MsgStatus.kReceived;
      _flags[sn] = current;
      if (mounted) {
        setState(() {
        });
      }
    }
    if (current == null || current == _MsgStatus.kDefault ||
        current == _MsgStatus.kWaiting) {
      // kDefault, kWaiting
      DateTime? time = widget.iMsg.time;
      if (time != null) {
        int expired = Time.currentTimeMilliseconds - 300 * 1000;
        if (time.millisecondsSinceEpoch < expired) {
          current = _MsgStatus.kExpired;
          _flags[sn] = current;
          if (mounted) {
            setState(() {
            });
          }
        }
      }
    }
    return current ?? _MsgStatus.kDefault;
  }

  Future<bool> _checkMember(ID mta) async {
    ID? group = widget.iMsg.group;
    if (group == null) {
      return false;
    }
    // TODO: check members.contains(mta)
    return true;
  }

  /// load traces to refresh message status
  Future<_MsgStatus> _load() async {
    ID sender = widget.iMsg.sender;
    int sn = widget.iMsg.content.sn;
    String? signature = widget.iMsg.getString('signature', null);
    ID? mta;
    GlobalVariable shared = GlobalVariable();
    List<String> traces = await shared.database.getTraces(sender, sn, signature);
    Log.debug('got ${traces.length} traces for message: $sender, $sn, $signature');
    _MsgStatus status = _MsgStatus.kDefault;
    for (String json in traces) {
      mta = ID.parse(JSONMap.decode(json)?['ID']);
      if (mta == null) {
        Log.error('trace error: $json');
      } else {
        status = await _refresh(sn: sn, mta: mta);
        if (status == _MsgStatus.kReceived) {
          break;
        }
      }
    }
    return status;
  }

  /// load traces to refresh message status,
  /// if it's waiting for response, reload after 5 minutes
  Future<void> _reload() async {
    // Check memory cache
    _MsgStatus? status = _flags[widget.iMsg.content.sn];
    if (status == _MsgStatus.kReceived) {
      // Your friend has received it, no need to update again.
      return;
    }
    // Try to load traces from database
    status = await _load();
    if (status == _MsgStatus.kReceived) {
      // Yes! It's received.
      return;
    }
    // Check after 5 minutes
    await Future.delayed(const Duration(seconds: 308));
    status = _flags[widget.iMsg.content.sn];
    if (status == _MsgStatus.kReceived) {
      // Finally!
      return;
    }
    // Still not received? Load it again.
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  _MsgStatus get status =>
      _flags[widget.iMsg.content.sn] ?? _MsgStatus.kDefault;

  IconData? get flag {
    switch (status) {
      case _MsgStatus.kWaiting: {
        return AppIcons.msgWaitingIcon;
      }
      case _MsgStatus.kSent: {
        return AppIcons.msgSentIcon;
      }
      case _MsgStatus.kBlocked: {
        return AppIcons.msgBlockedIcon;
      }
      case _MsgStatus.kReceived: {
        return AppIcons.msgReceivedIcon;
      }
      case _MsgStatus.kExpired: {
        return AppIcons.msgExpiredIcon;
      }
      default: {
        return AppIcons.msgDefaultIcon;
      }
    }
  }
  Color? get color {
    switch (status) {
      case _MsgStatus.kWaiting: {
        return CupertinoColors.systemGrey;
      }
      case _MsgStatus.kSent: {
        return CupertinoColors.systemGreen;
      }
      case _MsgStatus.kBlocked: {
        return CupertinoColors.systemRed;
      }
      case _MsgStatus.kReceived: {
        return CupertinoColors.systemBlue;
      }
      case _MsgStatus.kExpired: {
        return CupertinoColors.systemRed;
      }
      default: {
        return CupertinoColors.systemGrey;
      }
    }
  }
  String? get text {
    switch (status) {
      case _MsgStatus.kWaiting: {
        return 'Waiting to send'.tr;
      }
      case _MsgStatus.kSent: {
        return 'Sent to relay station'.tr;
      }
      case _MsgStatus.kBlocked: {
        return 'Message is rejected'.tr;
      }
      case _MsgStatus.kReceived: {
        return 'Your friend received'.tr;
      }
      case _MsgStatus.kExpired: {
        return 'No response'.tr;
      }
      default: {
        return 'Stranded'.tr;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == _MsgStatus.kReceived) {
      return _traceInfo();
    }
    return GestureDetector(
      onTap: _resendMessage,
      child: _traceInfo(),
    );
  }

  Widget _traceInfo() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$text ', style: TextStyle(
        fontSize: 10,
        color: color,
      )),
      Icon(flag, size: 10, color: color,),
      const SizedBox(width: 8,),
    ],
  );

  Future<void> _resendMessage() async {
    Log.warning('re-send message: ${widget.iMsg}');
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      assert(false, 'should not happen');
      return;
    }
    InstantMessage? iMsg = widget.iMsg;
    // iMsg.remove('signature');
    if (mounted) {
      setState(() {
        _flags[iMsg.content.sn] = _MsgStatus.kWaiting;
      });
    }
    ReliableMessage? rMsg = await messenger.sendInstantMessage(iMsg);
    if (rMsg == null) {
      Log.error('failed to send instant message: $iMsg');
    }
  }

}
