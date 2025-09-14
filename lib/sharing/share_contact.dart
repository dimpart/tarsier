import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../widgets/name_card.dart';

import 'pick_chat.dart';


abstract class ShareNameCard {

  static void forwardNameCard(BuildContext ctx, NameCard content, ID sender) {
    List traces = content['traces'] ?? [];
    traces = [...traces, {
      'ID': sender.toString(),
      'did': sender.toString(),
      'time': content.getDouble('time', 0),
    }];
    PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
        _forwardNameCardPreview(content, chat),
        okAction: () => _sendContact(chat.identifier, content, traces: traces).then((ok) {
          if (!ctx.mounted) {
            Log.warning('context unmounted: $ctx');
          } else if (ok) {
            // Alert.show(ctx, 'Forwarded',
            //   'Name Card @name forwarded to @chat'.trParams({
            //     'name': content.name,
            //     'chat': chat.title,
            //   }),
            // );
            Log.info('Name Card @name forwarded to @chat'.trParams({
              'name': content.name,
              'chat': chat.title,
            }));
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
  return forwardPreview(from, to);
}

Future<bool> _sendContact(ID receiver, NameCard info, {required List traces}) async {
  NameCard content = NameCard.create(info.identifier, info.name, info.avatar);
  info.forEach((key, value) {
    if (!_fixedNameCardFields.contains(key)) {
      Log.info('copy key: $key');
      content[key] = value;
    }
  });
  content['traces'] = traces;
  Log.info('forward name card to receiver: $receiver, $content');
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver: receiver);
  return true;
}
List<String> _fixedNameCardFields = [
  'type', 'sn', 'time', 'group',
  'ID', 'did', 'name', 'avatar',
  'traces',
];

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
