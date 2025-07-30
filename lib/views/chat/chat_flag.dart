import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;


class ChatSendFlag extends StatefulWidget {
  const ChatSendFlag(this.iMsg, {super.key});

  final InstantMessage iMsg;

  bool get isGroupChat =>
      iMsg.group != null || iMsg.receiver.isGroup;

  @override
  State<StatefulWidget> createState() => _SendState();

}

enum _MsgStatus {
  kDefault,
  kEncrypted,
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
    nc.addObserver(this, NotificationNames.kPortableNetworkEncrypted);
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
      Map? info = userInfo['mta'];
      ID? mta = ID.parse(info?['did']);
      mta ??= ID.parse(info?['ID']);
      Log.debug('checking status: $signature, $mta');
      // delay a while to wait the list updated
      await Future.delayed(const Duration(milliseconds: 256));
      if (sender == null || sn == null || mta == null) {
        Log.error('notification error: $userInfo');
      } else if (_match(sender: sender, sn: sn, signature: signature)) {
        // if match this message, refresh its status
        Log.debug('refreshing status: $signature');
        String? text = userInfo['text'];
        bool isBlocked = text != null && text.startsWith('Message is blocked');
        // TODO: show blocked count for group chat?
        if (isBlocked && !widget.isGroupChat) {
          _flags[sn] = _MsgStatus.kBlocked;
        } else {
          // clear to reload
          widget.iMsg['count_of_responded'] = null;
          widget.iMsg['count_of_traces'] = null;
        }
        await _refresh(sn: sn, mta: mta);
      }
    } else if (name == NotificationNames.kPortableNetworkEncrypted) {
      var pnf = userInfo?['PNF'];
      int? sn = pnf?['sn'];
      ID? sender = ID.parse(pnf?['enigma']?['sender']);
      if (sender == null || sn == null) {
        Log.error('notification error: $userInfo');
      } else if (_match(sender: sender, sn: sn, signature: null)) {
        // if match this message, refresh its status
        _flags[sn] = _MsgStatus.kEncrypted;
        if (mounted) {
          setState(() {
          });
        }
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
    String? sig = iMsg.getString('signature');
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
    } else if (current == _MsgStatus.kReceived) {
      Log.warning('message already received, ignore: $sn, $mta');
    } else if (mta == widget.iMsg.receiver) {
      current = _MsgStatus.kReceived;
      _flags[sn] = current;
    } else if (mta.type == EntityType.STATION) {
      current = _MsgStatus.kSent;
      _flags[sn] = current;
    } else if (await _checkMember(mta)) {
      current = _MsgStatus.kReceived;
      _flags[sn] = current;
    }
    if (current == null || current == _MsgStatus.kDefault ||
        current == _MsgStatus.kEncrypted ||
        current == _MsgStatus.kWaiting) {
      // kDefault, kEncrypted, kWaiting
      DateTime? time = widget.iMsg.time;
      if (time != null) {
        int expired = TimeUtils.currentTimeMilliseconds - 300 * 1000;
        if (time.millisecondsSinceEpoch < expired) {
          current = _MsgStatus.kExpired;
          _flags[sn] = current;
        }
      }
    }
    if (mounted) {
      setState(() {
      });
    }
    return current ?? _MsgStatus.kDefault;
  }

  Future<bool> _checkMember(ID mta) async {
    ID? group = widget.iMsg.group;
    if (group == null) {
      return false;
    }
    // check members.contains(mta)
    GroupInfo? info = GroupInfo.fromID(group);
    if (info == null) {
      assert(false, 'group not ready: $group');
      return false;
    }
    List<ID> members = info.members;
    return members.contains(mta);
  }

  /// load traces to refresh message status
  Future<List<String>> _loadTraces() async {
    GlobalVariable shared = GlobalVariable();
    ID sender = widget.iMsg.sender;
    int sn = widget.iMsg.content.sn;
    String? signature = widget.iMsg.getString('signature');
    List<String> traces = await shared.database.getTraces(sender, sn, signature);
    Log.info('got ${traces.length} traces for message: $sender, $sn, $signature');
    // count respond
    int count = _countOfUsers(traces);
    widget.iMsg['count_of_responded'] = count;
    widget.iMsg['count_of_traces'] = traces.length;
    return traces;
  }
  int _countOfUsers(List<String> traces) {
    Set<ID> responses = {};
    Map? info;
    ID? mta;
    for (String json in traces) {
      info = JSONMap.decode(json);
      mta = ID.parse(info?['did']);
      mta ??= ID.parse(info?['ID']);
      if (mta == null) {
        Log.error('trace error: $json');
      } else if (mta.type == EntityType.STATION) {
        Log.debug('ignore response from station: $mta');
      } else if (mta.isUser) {
        Log.debug('responded from user: $mta');
        // TODO: check whether is member?
        //       skip group bot too
        responses.add(mta);
      } else {
        Log.error('error response: $mta');
      }
    }
    Log.info('responded users: ${responses.length}, $responses');
    return responses.length;
  }

  Future<_MsgStatus> _refreshStatus(List<String> traces) async {
    int sn = widget.iMsg.content.sn;
    Map? info;
    ID? mta;
    _MsgStatus status = _MsgStatus.kDefault;
    for (String json in traces) {
      info = JSONMap.decode(json);
      mta = ID.parse(info?['did']);
      mta ??= ID.parse(info?['ID']);
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
    List<String> traces = await _loadTraces();
    // Check memory cache
    _MsgStatus? status = _flags[widget.iMsg.content.sn];
    if (status == _MsgStatus.kReceived) {
      // Your friend has received it, no need to update again.
      return;
    }
    // Try to load traces from database
    status = await _refreshStatus(traces);
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
    traces = await _loadTraces();
    await _refreshStatus(traces);
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
      case _MsgStatus.kEncrypted: {
        return AppIcons.msgEncryptedIcon;
      }
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
      case _MsgStatus.kEncrypted: {
        return CupertinoColors.activeOrange;
      }
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
      case _MsgStatus.kEncrypted: {
        return 'Waiting to upload'.tr;
      }
      case _MsgStatus.kWaiting: {
        return 'Waiting to send'.tr;
      }
      case _MsgStatus.kSent: {
        return 'Encrypted and sent to relay station'.tr;
      }
      case _MsgStatus.kBlocked: {
        return 'Message is rejected'.tr;
      }
      case _MsgStatus.kReceived: {
        if (_isPersonalChat()) {
          return 'Safely delivered'.tr;
        } else {
          int count = _countOfResponded();
          return 'Safely delivered to @count members'.trParams({
            'count': '$count',
          });
        }
      }
      case _MsgStatus.kExpired: {
        return 'No response'.tr;
      }
      default: {
        return 'Stranded'.tr;
      }
    }
  }
  bool _isPersonalChat() => widget.iMsg.content.group == null;
  int _countOfResponded() => widget.iMsg['count_of_responded'] ?? 0;

  @override
  Widget build(BuildContext context) {
    if (status == _MsgStatus.kEncrypted) {
      return _traceInfo();
    }
    if (status == _MsgStatus.kReceived) {
      if (widget.iMsg['count_of_responded'] == null) {
        _loadTraces().then((value) {
          if (mounted) {
            setState(() {
            });
          }
        });
      }
      return _traceInfo();
    }
    return GestureDetector(
      onTap: _resendMessage,
      child: _traceInfo(),
    );
  }

  Widget _traceInfo() {
    Widget view;
    view = Text('$text', style: TextStyle(
      fontSize: 10,
      color: color,
      overflow: TextOverflow.ellipsis,
    ), textAlign: TextAlign.right,);
    view = Expanded(child: view);
    view = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        view,
        const SizedBox(width: 4,),
        Icon(flag, size: 10, color: color,),
      ],
    );
    return view;
  }

  Future<void> _resendMessage() async {
    Log.warning('re-send message: ${widget.iMsg}');
    // clear last signature for repacking
    InstantMessage iMsg = widget.iMsg;
    Content content = iMsg.content;
    iMsg.remove('signature');
    if (mounted) {
      setState(() {
        _flags[content.sn] = _MsgStatus.kWaiting;
      });
    }
    // send again
    GlobalVariable shared = GlobalVariable();
    ReliableMessage? rMsg = await shared.emitter.sendInstantMessage(iMsg);
    if (rMsg == null) {
      Log.error('failed to send instant message: $iMsg');
    }
  }

}
