import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'pick_chat.dart';


abstract class ShareImage {

  static void forwardImage(BuildContext ctx, ImageContent content, ID sender) {
    // get local file path, if not exists
    // try to download from file server
    _pathFromContent(content).then((path) {
      if (path == null) {
        Alert.show(ctx, 'Image Not Found',
            'Failed to load image @filename'.trParams({
              'filename': '${content.filename}',
            })
        );
      } else {
        String filename = content.filename ?? Paths.filename(path) ?? 'a.jpeg';
        String? thumbnail = content['thumbnail'];
        List traces = content['traces'] ?? [];
        traces = [...traces, {
          'ID': sender.toString(),
          'time': content.getDouble('time', 0),
        }];
        PickChatPage.open(ctx,
          onPicked: (chat) => Alert.confirm(ctx, 'Confirm Forward',
            _forwardImagePreview(content, chat),
            okAction: () => _sendImage(chat.identifier,
              path: path, filename: filename, thumbnail: thumbnail, traces: traces,
            ).then((ok) {
              if (ok) {
                // Alert.show(ctx, 'Forwarded',
                //   'Image message forwarded to @chat'.trParams({
                //     'chat': chat.title,
                //   }),
                // );
                Log.info('Image message forwarded to @chat'.trParams({
                  'chat': chat.title,
                }));
              } else {
                Alert.show(ctx, 'Error',
                  'Failed to share image with @chat'.trParams({
                    'chat': chat.title,
                  }),
                );
              }
            }),
          ),
        );
      }
    });
  }

}


Future<String?> _pathFromContent(ImageContent content) async {
  PortableNetworkFile? pnf = PortableNetworkFile.parse(content);
  if (pnf == null) {
    assert(false, 'failed to parse PNF: $content');
    return null;
  }
  String? cachePath;
  if (pnf.url == null) {
    var ftp = SharedFileUploader();
    var task = PortableFileUploadTask(pnf, ftp.enigma);
    cachePath = await task.cacheFilePath;
  } else {
    var task = PortableFileDownloadTask(pnf);
    cachePath = await task.cacheFilePath;
  }
  if (cachePath == null) {
    Log.error('failed to get cache path: $content');
    return null;
  } else if (await Paths.exists(cachePath)) {
    return cachePath;
  } else {
    Log.error('cache path not exists: $cachePath, $content');
    return null;
  }
}

Widget _forwardImagePreview(ImageContent content, Conversation chat) {
  Widget to = previewEntity(chat);
  Widget? from = Gallery.getThumbnail(content.toMap());
  if (from != null) {
    from = SizedBox(width: 64, child: from,);
  } else {
    String? filename = content.filename ??= 'Image';
    from = _previewText(filename);
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

Future<bool> _sendImage(ID receiver,
    {required String path, required String filename, String? thumbnail,
      required List traces}) async {
  // load image data
  Uint8List? jpeg = await ExternalStorage.loadBinary(path);
  if (jpeg == null) {
    Log.error('failed to load image: $path');
    return false;
  } else {
    Log.debug('forwarding image to $receiver: "$filename", traces: $traces');
  }
  var pnf = PortableNetworkFile.parse(thumbnail);
  // send image content with traces
  GlobalVariable shared = GlobalVariable();
  await shared.emitter.sendPicture(jpeg, filename: filename, thumbnail: pnf, extra: {
    'traces': traces,
  }, receiver: receiver);
  return true;
}

Widget _previewText(String text) => SizedBox(
  width: 64,
  child: Text(text,
    maxLines: 3,
    overflow: TextOverflow.ellipsis,
  ),
);
