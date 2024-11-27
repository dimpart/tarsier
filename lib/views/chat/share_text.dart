import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'pick_chat.dart';


abstract class ShareTextMessage {

  static void forwardTextMessage(BuildContext ctx, TextContent content, ID sender) {
    List traces = content['traces'] ?? [];
    traces = [...traces, {
      'ID': sender.toString(),
      'time': content.getDouble('time', 0),
    }];
    PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
        _forwardTextPreview(content, chat),
        okAction: () => _sendText(chat.identifier,
          content: content,
          traces: traces,
        ).then((ok) {
          if (ok) {
            Alert.show(ctx, 'Forwarded',
                'Text message forwarded to @chat'.trParams({
                  'chat': chat.title,
                })
            );
          } else {
            Alert.show(ctx, 'Error',
              'Failed to share text with @chat'.trParams({
                'chat': chat.title,
              }),
            );
          }
        }),
      ),
    );
  }

}


Widget _forwardTextPreview(TextContent content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from = _previewText(content.text);
  Widget body = Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      from,
      const SizedBox(width: 32,),
      const Text('~>'),
      const SizedBox(width: 32,),
      to,
    ],
  );
  return body;
}

Widget _previewText(String text) {
  if (text.length > 16) {
    text = text.substring(0, 12);
    text = '$text ...';
  }
  return SizedBox(
    width: 64,
    child: Text(text,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Future<bool> _sendText(ID receiver, {required TextContent content, required List traces}) async {
  TextContent forward = TextContent.create(content.text);
  // copy other fields
  Map info = content.copyMap(false);
  info.forEach((key, value) {
    if (!_fixedFields.contains(key)) {
      forward[key] = value;
    }
  });
  // update traces & send out
  forward['traces'] = traces;
  Log.warning('forward text message to receiver: $receiver, $forward');
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(forward, receiver);
  return true;
}
List<String> _fixedFields = [
  'type', 'sn', 'time', 'group',
  'text',
  'traces',
];
