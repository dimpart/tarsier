import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'pick_chat.dart';


abstract class ShareNameCard {

  static void forwardNameCard(BuildContext ctx, NameCard content, ID sender) {
    List traces = content['traces'] ?? [];
    traces = [...traces, {
      'ID': sender.toString(),
      'time': content.getDouble('time', 0),
    }];
    PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
        _forwardNameCardPreview(content, chat),
        okAction: () => _sendContact(chat.identifier,
          identifier: content.identifier, name: content.name, avatar: content.avatar?.url.toString(),
          traces: traces,
        ).then((ok) {
          if (ok) {
            Alert.show(ctx, 'Forwarded',
                'Name Card @name forwarded to @chat'.trParams({
                  'name': content.name,
                  'chat': chat.title,
                })
            );
          } else {
            Alert.show(ctx, 'Error',
              'Failed to share Name Card @name with @chat'.trParams({
                'name': content.name,
                'chat': chat.title,
              }),
            );
          }
        }),
      ),
    );
  }

}


Widget _forwardNameCardPreview(NameCard content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from;
  PortableNetworkFile? avatar = content.avatar;
  if (avatar != null) {
    from = NameCardView.avatarImage(content);
  } else {
    String name = content.name;
    if (name.isEmpty) {
      name = content.identifier.toString();
    }
    from = _previewText(name);
  }
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

Future<bool> _sendContact(ID receiver,
    {required ID identifier, required String name, String? avatar,
      required List traces}) async {
  NameCard content = NameCard.create(identifier, name, PortableNetworkFile.parse(avatar));
  content['traces'] = traces;
  Log.debug('forward name card to receiver: $receiver, $content');
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver);
  return true;
}

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
