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
    shareVideo(ctx, MediaItem(content.toMap()));
  }

  static void shareVideo(BuildContext ctx, MediaItem playingItem) {
    // get playing info
    Uri? url = playingItem.url;
    String? title = playingItem.title;
    String? filename = playingItem.filename;
    Uri? cover = playingItem.cover;
    String? snapshot = cover?.toString();
    if (url == null) {
      assert(false, 'playing url not found: $playingItem');
      return;
    }
    // build video content
    var content = FileContent.video(filename: filename, url: url, password: Password.plainKey);
    content['title'] = title;
    content['snapshot'] = snapshot;
    // confirm
    PickChatPage.open(ctx, onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
      _forwardVideoPreview(content, chat),
      okAction: () => _sendVideo(chat.identifier,
        url: url, filename: filename, title: title, snapshot: snapshot,
      ).then((ok) {
        if (ok) {
          // Alert.show(ctx, 'Forwarded',
          //   'Video message forwarded to @chat'.trParams({
          //     'chat': chat.title,
          //   }),
          // );
          Log.info('Video message forwarded to @chat'.trParams({
            'chat': chat.title,
          }));
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
  var pnf = PortableNetworkFile.parse(snapshot);
  // send image content with traces
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendMovie(url,
    filename: filename, title: title, snapshot: pnf,
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
