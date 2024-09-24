import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../contact/profile.dart';
import 'share_contact.dart';
import 'share_image.dart';
import 'share_page.dart';
import 'share_video.dart';


abstract class ContentViewHelper {

  static Widget getNameCardView(BuildContext ctx, NameCard content, Envelope envelope) {
    ID sender = envelope.sender;
    // action - forward
    forwardNameCard() => ShareNameCard.forwardNameCard(ctx, content, sender);
    // action - recall
    recallNameCard() => _recallNameCard(ctx, content, envelope);
    // action - onLongPress
    bool canRecall = _canRecall(content, sender);
    actionSheet() => Alert.actionSheet(ctx, null, null,
      // forward
      Alert.action(AppIcons.shareIcon, 'Forward Name Card'),
      forwardNameCard,
      // recall
      !canRecall ? null : Alert.action(AppIcons.recallIcon, 'Recall Message'),
      recallNameCard,
    );
    // action - onTap
    openNameCard() => ProfilePage.open(ctx, content.identifier);
    // OK
    return ContentViewUtils.getNameCardView(content,
      onTap: openNameCard,
      onLongPress: actionSheet,
    );
  }

  static Widget getPageContentView(BuildContext ctx, PageContent content, Envelope envelope) {
    ID sender = envelope.sender;
    // action - onWebShare
    onWebShare(url, {required title, required desc, required icon}) =>
        ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon);
    // action - forward
    forwardWebPage() => ShareWebPage.forwardWebPage(ctx, content, sender);
    // action - recall
    recallWebPage() => _recallWebPage(ctx, content, envelope);
    // action - onLongPress
    bool canRecall = _canRecall(content, sender);
    actionSheet() => Alert.actionSheet(ctx, null, null,
      // forward
      Alert.action(AppIcons.shareIcon, 'Forward Web Page'),
      forwardWebPage,
      // recall
      !canRecall ? null : Alert.action(AppIcons.recallIcon, 'Recall Message'),
      recallWebPage,
    );
    // action - onTap
    openWebPage() => Browser.open(ctx, HtmlUri.getUriString(content),
      onWebShare: onWebShare,
    );
    // OK
    return ContentViewUtils.getPageContentView(content, sender,
      onTap: openWebPage,
      onLongPress: actionSheet,
    );
  }

  static Widget getImageContentView(BuildContext ctx, ImageContent content, Envelope envelope, List<InstantMessage> messages) {
    ID sender = envelope.sender;
    // action - forward
    forwardImage() => ShareImage.forwardImage(ctx, content, sender);
    // action - save
    saveImage() => saveImageContent(ctx, content);
    // action - recall
    recallImage() => _recallImageMessage(ctx, content, envelope);
    // action - onLongPress
    bool canRecall = _canRecall(content, sender);
    actionSheet() => Alert.actionSheet(ctx, null, null,
      // forward
      Alert.action(AppIcons.shareIcon, 'Forward Image'),
      forwardImage,
      // save
      Alert.action(AppIcons.saveFileIcon, 'Save to Album'),
      saveImage,
      // recall
      !canRecall ? null : Alert.action(AppIcons.recallIcon, 'Recall Message'),
      recallImage,
    );
    // action - onTap
    previewImage() => previewImageContent(ctx, content, messages);
    // OK
    return ContentViewUtils.getImageContentView(content, sender,
      onTap: previewImage,
      onLongPress: actionSheet,
    );
  }

  static Widget getVideoContentView(BuildContext ctx, VideoContent content, Envelope envelope) {
    ID sender = envelope.sender;
    // action - onVideoShare
    onVideoShare(playingItem) => ShareVideo.forwardVideo(ctx, content, sender);
    // action - recall
    recallVideo() => _recallVideoMessage(ctx, content, envelope);
    // action - onLongPress
    bool canRecall = _canRecall(content, sender);
    actionSheet() => Alert.actionSheet(ctx, null, null,
      // forward
      Alert.action(AppIcons.shareIcon, 'Forward Video'),
          () => ShareVideo.forwardVideo(ctx, content, sender),
      // recall
      !canRecall ? null : Alert.action(AppIcons.recallIcon, 'Recall Message'),
      recallVideo,
    );
    // OK
    return ContentViewUtils.getVideoContentView(content, sender,
      onLongPress: actionSheet,
      onVideoShare: onVideoShare,
    );
  }

  static Widget getAudioContentView(BuildContext ctx, AudioContent content, Envelope envelope) {
    ID sender = envelope.sender;
    // action - recall
    recallAudio() => _recallAudioMessage(ctx, content, envelope);
    // action - onLongPress
    bool canRecall = _canRecall(content, sender);
    // OK
    return ContentViewUtils.getAudioContentView(content, sender,
      onLongPress: !canRecall ? null : () => Alert.actionSheet(ctx, null, null,
        // recall
        Alert.action(AppIcons.recallIcon, 'Recall Message'),
        recallAudio,
      ),
    );
  }

  static Widget getTextContentView(BuildContext ctx, Content content, Envelope envelope) {
    ID sender = envelope.sender;
    bool mine = sender == ContentViewUtils.currentUser?.identifier;
    var format = content.getString('format', null);
    bool plain = mine || format != 'markdown';
    String text = DefaultMessageBuilder().getText(content, sender);
    // action - onWebShare
    onWebShare(url, {required title, required desc, required icon}) =>
        ShareWebPage.shareWebPage(ctx, url, title: title, desc: desc, icon: icon);
    // action - onVideoShare
    onVideoShare(playingItem) => ShareVideo.shareVideo(ctx, playingItem);
    // action - onDoubleTap
    openText() => TextPreviewPage.open(ctx,
      text: text, sender: sender,
      onWebShare: onWebShare,
      onVideoShare: onVideoShare,
      previewing: plain,
    );
    // action - onLongPress
    bool canRecall = content is TextContent && _canRecall(content, sender);
    // OK
    return ContentViewUtils.getTextContentView(content, sender,
      onDoubleTap: openText,
      onLongPress: !canRecall ? null : () => Alert.actionSheet(ctx, null, null,
        // recall
        Alert.action(AppIcons.recallIcon, 'Recall Message'),
            () => _recallTextMessage(ctx, content, envelope),
      ),
      onWebShare: onWebShare,
      onVideoShare: onVideoShare,
    );
  }

}

///
///   Recall Messages
///
bool _canRecall(Content content, ID sender) {
  if (sender != ContentViewUtils.currentUser?.identifier) {
    return false;
  }
  DateTime? when = content.time;
  if (when == null) {
    return true;
  }
  Duration elapsed = DateTime.now().difference(when);
  return elapsed.inSeconds < 128;
}

void _recallImageMessage(BuildContext ctx, ImageContent content, Envelope envelope) {
  Log.info('recalling image message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallImageMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}
void _recallVideoMessage(BuildContext ctx, VideoContent content, Envelope envelope) {
  Log.info('recalling video message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallVideoMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}
void _recallAudioMessage(BuildContext ctx, AudioContent content, Envelope envelope) {
  Log.info('recalling audio message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallAudioMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}

void _recallTextMessage(BuildContext ctx, TextContent content, Envelope envelope) {
  Log.info('recalling text message: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallTextMessage(content, envelope).then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}

void _recallWebPage(BuildContext ctx, PageContent content, Envelope envelope) {
  Log.info('recalling web page: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallMessage(content, envelope, text: '_(web page recalled)_').then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}

void _recallNameCard(BuildContext ctx, NameCard content, Envelope envelope) {
  Log.info('recalling name card: $content');
  Alert.confirm(ctx, 'Confirm', 'Sure to recall this message?'.tr,
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.emitter.recallMessage(content, envelope, text: '_(name card recalled)_').then((pair) {
          if (pair.first == null) {
            Log.warning('failed to recall message.');
          } else {
            Log.info('message recalled.');
          }
        });
      }
  );
}