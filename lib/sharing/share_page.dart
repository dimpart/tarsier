import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'pick_chat.dart';
import 'share_contact.dart';


abstract class ShareWebPage {

  static void forwardWebPage(BuildContext ctx, PageContent content, ID sender) {
    String urlString = HtmlUri.getUriString(content);
    Uri? url = HtmlUri.parseUri(urlString);
    if (url == null) {
      Alert.show(ctx, 'URL Error', urlString);
    } else {
      var small = content['icon'];
      shareWebPage(ctx, url, title: content.title, desc: content.desc, icon: small);
    }
  }

  static void shareWebPage(BuildContext ctx, Uri url, {required String title, String? desc, String? icon}) {
    PickChatPage.open(ctx,
      onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
        _shareWebPagePreview(title, icon, chat),
        okAction: () => _sendWebPage(chat.identifier,
          url, title: title, desc: desc, icon: icon,
        ).then((ok) {
          if (!ctx.mounted) {
            Log.warning('context unmounted: $ctx');
          } else if (ok) {
            // Alert.show(ctx, 'Forwarded',
            //   'Web Page @title forwarded to @chat'.trParams({
            //     'title': title,
            //     'chat': chat.title,
            //   }),
            // );
            Log.info('Web Page @title forwarded to @chat'.trParams({
              'title': title,
              'chat': chat.title,
            }));
          } else {
            Alert.show(ctx, 'Error',
              'Failed to share Web Page @title with @chat'.trParams({
                'title': title,
                'chat': chat.title,
              }),
            );
          }
        }),
      ),
    );
  }

}


Widget _shareWebPagePreview(String title, String? icon, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget? from;
  if (icon != null) {
    from = ImageUtils.getImage(icon);
    from = SizedBox(width: 64, child: from,);
  } else if (title.isNotEmpty) {
    from = _previewText(title);
  } else {
    from = const Icon(AppIcons.webpageIcon);
  }
  return forwardPreview(from, to);
}

Future<bool> _sendWebPage(ID receiver, Uri url,
    {required String title, String? desc, String? icon}) async {
  // create web page content
  PageContent content = PageContent.create(url: url, title: title, desc: desc);
  if (icon != null) {
    content['icon'] = icon;
  }
  // check "data:text/html"
  HtmlUri.setHtmlString(url, content);
  Log.info('share web page to $receiver: "$title", $url');
  // send web page content
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendContent(content, receiver: receiver);
  return true;
}

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
