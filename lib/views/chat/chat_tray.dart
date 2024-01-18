import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:lnc/lnc.dart' as lnc;

import 'package:dim_flutter/dim_flutter.dart';


class ChatInputTray extends StatefulWidget {
  const ChatInputTray(this.info, {super.key});

  final Conversation info;

  @override
  State<StatefulWidget> createState() => _InputState();

}

class _InputState extends State<ChatInputTray> implements lnc.Observer {
  _InputState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kAvatarLongPressed);
  }

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVoice = false;

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kAvatarLongPressed) {
      ID? user = userInfo?['user'];
      if (user == null) {
        assert(false, 'failed to get user: $userInfo');
      } else {
        GlobalVariable shared = GlobalVariable();
        Visa? visa = await shared.facebook.getVisa(user);
        String? nickname = visa?.name;
        if (nickname != null && nickname.isNotEmpty) {
          String text = _controller.text;
          TextSelection selection = _controller.selection;
          String mentioned = '@$nickname ';
          if (selection.start < 0) {
            _controller.text += mentioned;
          } else {
            _controller.text = text.replaceRange(selection.start, selection.end, mentioned);
            _controller.selection = TextSelection.collapsed(offset: selection.baseOffset + mentioned.length);
          }
          _typing(_controller, widget.info);
        }
      }
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kAvatarLongPressed);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // load editing text
    var shared = SharedEditingText();
    String? text = shared.getConversationEditingText(widget.info);
    if (text != null) {
      _controller.text = text;
    }
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!_isVoice)
        CupertinoButton(
          child: const Icon(AppIcons.chatMicIcon),
          onPressed: () => setState(() {
            _isVoice = true;
          }),
        ),
      if (_isVoice)
        CupertinoButton(
          child: const Icon(AppIcons.chatKeyboardIcon),
          onPressed: () => setState(() {
            _isVoice = false;
          }),
        ),
      if (!_isVoice)
        Expanded(
          flex: 1,
          child: CupertinoTextField(
            minLines: 1,
            maxLines: 8,
            controller: _controller,
            placeholder: 'Input text message'.tr,
            decoration: Styles.textFieldDecoration,
            style: Styles.textFieldStyle,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            focusNode: _focusNode,
            onTapOutside: (event) => _focusNode.unfocus(),
            onSubmitted: (value) => _sendText(context, _controller, widget.info),
            onChanged: (value) => setState(() {
              Log.warning('onChanged: $value');
              _typing(_controller, widget.info);
            }),
          ),
        ),
      if (_isVoice)
        Expanded(
          flex: 1,
          child: RecordButton(
            onComplected: (data, duration) => _sendVoice(data, duration, widget.info),
          ),
        ),
      if (_controller.text.isEmpty || _isVoice)
        CupertinoButton(
          child: const Icon(AppIcons.chatFunctionIcon),
          onPressed: () => _sendImage(context, widget.info),
        ),
      if (_controller.text.isNotEmpty && !_isVoice)
        CupertinoButton(
          child: const Icon(AppIcons.chatSendIcon),
          onPressed: () => _sendText(context, _controller, widget.info),
        ),
    ],
  );

}

//--------

void _typing(TextEditingController controller, Conversation chat) {
  var shared = SharedEditingText();
  shared.setConversationEditingText(controller.text, chat);
  var nc = lnc.NotificationCenter();
  nc.postNotification(NotificationNames.kMessageTyping, controller, {
    'ID': chat.identifier,
  });
}

void _sendText(BuildContext context, TextEditingController controller, Conversation chat) {
  String text = controller.text.trim();
  if (text.isNotEmpty) {
    GlobalVariable shared = GlobalVariable();
    shared.emitter.sendText(text, chat.identifier);
  }
  controller.text = '';
  var shared = SharedEditingText();
  shared.setConversationEditingText('', chat);
}

void _sendImage(BuildContext context, Conversation chat) =>
    openImagePicker(context, onPicked: (path) {
      Log.info('picked image: $path');
    }, onRead: (path, jpeg) => adjustImage(jpeg, 2048, (Uint8List data) async {
      // send adjusted image data with thumbnail
      Uint8List thumbnail = await compressThumbnail(data);
      GlobalVariable shared = GlobalVariable();
      shared.emitter.sendImage(data, 'image.jpeg', thumbnail, chat.identifier);
    }));

void _sendVoice(Uint8List data, double duration, Conversation chat) =>
    GlobalVariable().emitter.sendVoice(data, 'voice.mp4', duration, chat.identifier);
