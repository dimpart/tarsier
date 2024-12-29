import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:lnc/notification.dart' as lnc;

import 'package:dim_flutter/dim_flutter.dart';


class ChatInputTray extends StatefulWidget {
  const ChatInputTray(this.info, this.extra, {super.key});

  final Conversation info;
  final Map? extra;

  String? get text => extra?['text'];

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
          _insertTextToFocus('@$nickname ');
        }
      }
    }
  }

  void _insertTextToFocus(String fragment) {
    String text = _controller.text;
    TextSelection selection = _controller.selection;
    if (selection.start < 0) {
      _controller.text += fragment;
    } else {
      _controller.text = text.replaceRange(selection.start, selection.end, fragment);
      _controller.selection = TextSelection.collapsed(offset: selection.baseOffset + fragment.length);
    }
    _typing(_controller, widget.info);
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
    _focusNode.requestFocus();
    // load editing text
    var shared = SharedEditingText();
    String? text = widget.text;
    text ??= shared.getConversationEditingText(widget.info);
    if (text != null) {
      _controller.text = text;
      _lastText = text;
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
          child: DevicePlatform.isMobile ? _inputTextField(context) : Focus(
            focusNode: _focusNode,
            child: _inputTextField(context),
            onKeyEvent: (FocusNode focusNode, KeyEvent event) {
              Log.info('focus node: $focusNode, key event: $event');
              var checker = RawKeyboardChecker();
              var key = checker.checkKeyEvent(event);
              if (key != null && key.isModified && key == RawKeyboardKey.enter) {
                _sendText(context, _controller, widget.info);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
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

  Widget _inputTextField(BuildContext context) => CupertinoTextField(
    minLines: 1,
    maxLines: 8,
    controller: _controller,
    placeholder: 'Input text message'.tr,
    decoration: Styles.textFieldDecoration,
    style: Styles.textFieldStyle,
    keyboardType: TextInputType.multiline,
    textInputAction: TextInputAction.newline,
    focusNode: DevicePlatform.isMobile ? _focusNode : null,
    onTapOutside: (event) => _focusNode.unfocus(),
    onSubmitted: (text) => _sendText(context, _controller, widget.info),
    onChanged: (text) => setState(() {
      Log.warning('onChanged: $text');
      _typing(_controller, widget.info);
      var info = widget.info;
      if (info is GroupInfo) {
        var delta = _lastCharacter(text);
        Log.info('last input: "$delta"');
        if (delta == '@') {
          _selectMentionedMember(context, info.members);
        }
      }
    }),
  );

  String? _lastCharacter(String text) {
    String last = _lastText;
    _lastText = text;
    int diff = text.length - last.length;
    if (diff != 1) {
      return null;
    }
    int index = 0;
    for (; index < last.length; ++index) {
      if (last[index] != text[index]) {
        break;
      }
    }
    return text[index];
  }
  String _lastText = '';

  void _selectMentionedMember(BuildContext context, List<ID> members) {
    Set<ID> candidates = members.toSet();
    // TODO: remove myself
    if (candidates.isEmpty) {
      Log.error('failed to get members');
      return;
    }
    Log.info('candidates: $candidates');
    MemberPicker.open(context, candidates,
      onPicked: (users) => _insertMentionedMembers(users),
    );
  }

  void _insertMentionedMembers(Set<ID> users) async {
    GlobalVariable shared = GlobalVariable();
    var facebook = shared.facebook;
    User? current = await facebook.currentUser;
    if (current == null) {
      Log.error('failed to get current user');
      return;
    }
    List<String> names = [];
    for (ID member in users) {
      if (member == current.identifier) {
        Log.warning('skip myself: $member');
        continue;
      }
      String nickname = await facebook.getName(member);
      if (nickname.isNotEmpty) {
        names.add(nickname);
      }
    }
    if (names.isEmpty) {
      Log.warning('failed to get names: $users');
      return;
    }
    String text = names.join(' @');
    _insertTextToFocus('$text ');
  }

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
    shared.emitter.sendText(text, receiver: chat.identifier,);
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
      String? thumbnail;
      Uint8List? small = await ImageUtils.compressThumbnail(data);
      if (small != null) {
        var ted = TransportableData.create(small);
        thumbnail = ted.toString();
      }
      var pnf = PortableNetworkFile.parse(thumbnail);
      GlobalVariable shared = GlobalVariable();
      shared.emitter.sendPicture(data, filename: 'image.jpeg', thumbnail: pnf,
        receiver: chat.identifier,);
    }));

void _sendVoice(Uint8List data, double duration, Conversation chat) =>
    GlobalVariable().emitter.sendVoice(data, filename: 'voice.mp4', duration: duration,
      receiver: chat.identifier,);
