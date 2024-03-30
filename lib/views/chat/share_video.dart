import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'pick_chat.dart';


abstract class ShareVideo {

  static void forwardVideo(BuildContext ctx, VideoContent content, ID sender) {
    Uri? url = content.url;
    if (url == null) {
      assert(false, 'video URL not found: $content');
      return;
    }
    var filename = content.filename;
    filename ??= URLHelper.filenameFromURL(url, 'movie.mp4');
    var title = content['title'];
    var snapshot = content['snapshot'];
    shareVideo(ctx, url,
      filename: filename, title: title,
      snapshot: snapshot,
    );
  }

  static void shareVideo(BuildContext ctx, Uri url, {
    required String? filename,
    required String? title,
    required String? snapshot,
  }) {
    var content = FileContent.video(filename: filename, url: url, password: PlainKey.getInstance());
    content['title'] = title;
    content['snapshot'] = snapshot;
    PickChatPage.open(ctx, onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
      _forwardVideoPreview(content, chat),
      okAction: () => _sendVideo(chat.identifier,
        url: url, filename: filename, title: title, snapshot: snapshot,
      ).then((ok) {
        if (ok) {
          Alert.show(ctx, 'Forwarded',
            'Video message forwarded to @chat'.trParams({
              'chat': chat.title,
            }),
          );
        } else {
          Alert.show(ctx, 'Error',
            'Failed to share video with @chat'.trParams({
              'chat': chat.title,
            }),
          );
        }
      }),
    ));
  }

}


Widget _forwardVideoPreview(VideoContent content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget? from = Gallery.getSnapshot(content);
  if (from != null) {
    from = SizedBox(width: 64, child: from,);
  } else {
    String? title = content['title'];
    if (title == null || title.isEmpty) {
      title = content.filename ??= 'Video';
    }
    from = _previewText(title);
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
Future<bool> _sendVideo(ID receiver,
    {required Uri url, String? filename, String? title, String? snapshot}) async {
  // send image content with traces
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendVideo(url,
    filename: filename, title: title, snapshot: snapshot,
    receiver: receiver,
  );
  return true;
}

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
