import 'dart:typed_data';

import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';


class ChatInputTray extends StatefulWidget {
  const ChatInputTray(this.info, {super.key});

  final ContactInfo info;

  @override
  State<StatefulWidget> createState() => _InputState();

}

class _InputState extends State<ChatInputTray> {

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isVoice = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!_isVoice)
        CupertinoButton(
          child: const Icon(Styles.chatMicIcon),
          onPressed: () => setState(() {
            _isVoice = true;
          }),
        ),
      if (_isVoice)
        CupertinoButton(
          child: const Icon(Styles.chatKeyboardIcon),
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
            placeholder: 'Input text message',
            decoration: Facade.of(context).styles.textFieldDecoration,
            style: Facade.of(context).styles.textFieldStyle,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            focusNode: _focusNode,
            onTapOutside: (event) => _focusNode.unfocus(),
            onSubmitted: (value) => _sendText(context, _controller, widget.info),
            onChanged: (value) => setState(() {}),
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
          child: const Icon(Styles.chatFunctionIcon),
          onPressed: () => _sendImage(context, widget.info),
        ),
      if (_controller.text.isNotEmpty && !_isVoice)
        CupertinoButton(
          child: const Icon(Styles.chatSendIcon),
          onPressed: () => _sendText(context, _controller, widget.info),
        ),
    ],
  );

}

//--------

void _sendText(BuildContext context, TextEditingController controller, ContactInfo chat) {
  String text = controller.text.trim();
  if (text.isNotEmpty) {
    GlobalVariable shared = GlobalVariable();
    shared.emitter.sendText(text, chat.identifier);
  }
  controller.text = '';
}

void _sendImage(BuildContext context, ContactInfo chat) =>
    openImagePicker(context, onPicked: (path) {
      Log.info('picked image: $path');
    }, onRead: (path, jpeg) => adjustImage(jpeg, 2048, (Uint8List data) async {
      // send adjusted image data with thumbnail
      Uint8List thumbnail = await compressThumbnail(data);
      GlobalVariable shared = GlobalVariable();
      shared.emitter.sendImage(data, thumbnail, chat.identifier);
    }));

void _sendVoice(Uint8List data, double duration, ContactInfo chat) =>
    GlobalVariable().emitter.sendVoice(data, duration, chat.identifier);
