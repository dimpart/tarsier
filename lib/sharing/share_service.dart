import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../views/service/base.dart';
import '../widgets/service_card.dart';

import 'pick_chat.dart';


abstract class ShareService {

  static void shareService(BuildContext ctx, ServiceInfo info) {
    PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Share',
        _shareServicePreview(info, chat),
        okAction: () => _sendService(chat.identifier, info).then((ok) {
          if (!ctx.mounted) {
            Log.warning('context unmounted: $ctx');
          } else if (ok) {
            Log.info('Service @title forwarded to @chat'.trParams({
              'title': info.title,
              'chat': chat.title,
            }));
          } else {
            Alert.show(ctx, 'Error',
              'Failed to share Service @title with @chat'.trParams({
                'title': info.title,
                'chat': chat.title,
              }),
            );
          }
        }),
      ),
    );
  }

}


Widget _shareServicePreview(ServiceInfo info, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget from;
  PortableNetworkFile? icon = info.icon;
  if (icon != null) {
    from = ServiceCardView.iconView(info);
  } else {
    String title = info.title;
    if (title.isEmpty) {
      title = info.identifier.toString();
    }
    from = _previewText(title);
  }
  return forwardPreview(from, to);
}

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);

Future<bool> _sendService(ID receiver, ServiceInfo info) async {
  GlobalVariable shared = GlobalVariable();
  ID identifier = info.identifier;
  // get user info
  Visa? visa = await shared.facebook.getVisa(identifier);
  if (visa == null) {
    return false;
  }
  String name = visa.name ?? info.title;
  PortableNetworkFile? avatar = visa.avatar;
  // send service info in a NameCard
  NameCard content = NameCard.create(identifier, name, avatar);
  content.setMap('service', info);
  Log.info('forward service to receiver: $receiver, $content');
  await shared.emitter.sendContent(content, receiver: receiver);
  return true;
}
