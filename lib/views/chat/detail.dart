import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:dim_flutter/lnc.dart' as lnc;

import '../service/report.dart';
import 'associates.dart';


class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage(this.info, {super.key});

  final ContactInfo info;

  static void open(BuildContext context, ID identifier) {
    assert(identifier.isUser, 'ID error: $identifier');
    ContactInfo? info = ContactInfo.fromID(identifier);
    info?.reloadData().then((value) {
      if (context.mounted) {
        showPage(
          context: context,
          builder: (context) => ChatDetailPage(info),
        );
      }
    }).onError((error, stackTrace) {
      if (context.mounted) {
        Alert.show(context, 'Error', '$error');
      }
    });
  }

  @override
  State<StatefulWidget> createState() => _ChatDetailState();

}

class _ChatDetailState extends State<ChatDetailPage> implements lnc.Observer {
  _ChatDetailState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
    nc.addObserver(this, NotificationNames.kMuteListUpdated);
  }

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kMuteListUpdated);
    nc.removeObserver(this, NotificationNames.kBlockListUpdated);
    nc.removeObserver(this, NotificationNames.kContactsUpdated);
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kDocumentUpdated) {
      ID? identifier = userInfo?['ID'];
      assert(identifier != null, 'notification error: $notification');
      if (identifier == widget.info.identifier) {
        Log.info('document updated: $identifier');
        await _reload();
      }
    } else if (name == NotificationNames.kContactsUpdated) {
      ID? contact = userInfo?['contact'];
      Log.info('contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kBlockListUpdated) {
      ID? contact = userInfo?['blocked'];
      contact ??= userInfo?['unblocked'];
      Log.info('blocked contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else if (name == NotificationNames.kMuteListUpdated) {
      ID? contact = userInfo?['muted'];
      contact ??= userInfo?['unmuted'];
      Log.info('muted contact updated: $contact');
      if (contact == widget.info.identifier) {
        await _reload();
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: Styles.colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: Styles.colors.appBardBackgroundColor,
        middle: Text('Chat Details'.tr, style: Styles.titleTextStyle),
      ),
      body: buildScrollView(
        enableScrollbar: true,
        child: _body(context,
          backgroundColor: colors.sectionItemBackgroundColor,
          backgroundColorActivated: colors.sectionItemDividerColor,
          dividerColor: colors.sectionItemDividerColor,
          primaryTextColor: colors.primaryTextColor,
          secondaryTextColor: colors.tertiaryTextColor,
          dangerousTextColor: CupertinoColors.systemRed,
        ),
      ),
    );
  }

  Widget _body(BuildContext context, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color dangerousTextColor,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [

      Container(
        color: backgroundColor,
        padding: const EdgeInsets.all(16),
        child: _participantList(context),
      ),
      const SizedBox(height: 16,),

      if (widget.info.identifier.type != EntityType.STATION)
        CupertinoListSection(
          backgroundColor: dividerColor,
          topMargin: 0,
          additionalDividerMargin: 32,
          children: [
            /// Mute
            CupertinoListTile(
              backgroundColor: backgroundColor,
              backgroundColorActivated: backgroundColorActivated,
              padding: Styles.settingsSectionItemPadding,
              leading: Icon(AppIcons.muteListIcon, color: primaryTextColor),
              title: Text('Mute Notifications'.tr, style: TextStyle(color: primaryTextColor)),
              additionalInfo: CupertinoSwitch(
                value: widget.info.isMuted,
                onChanged: (bool value) => setState(() {
                  if (value) {
                    widget.info.mute(context: context);
                  } else {
                    widget.info.unmute(context: context);
                  }
                }),
              ),
            ),
          ],
        ),

      CupertinoListSection(
        backgroundColor: dividerColor,
        dividerMargin: 0,
        additionalDividerMargin: 0,
        children: [
          /// clear history
          _clearButton(context, textColor: dangerousTextColor, backgroundColor: backgroundColor),
          /// report
          if (!CustomerService.isDirector(widget.info.identifier))
          _reportButton(context, textColor: dangerousTextColor, backgroundColor: backgroundColor),
        ],
      ),

      const SizedBox(height: 64,),

    ],
  );

  Widget _participantList(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      contactCard(context, widget.info),
      const SizedBox(width: 16,),
      plusCard(context, widget.info),
    ],
  );

  Widget _clearButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Clear History'.tr, AppIcons.clearChatIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _clearHistory(context, widget.info),
      );

  Widget _reportButton(BuildContext context, {required Color textColor, required Color backgroundColor}) =>
      _button('Report'.tr, AppIcons.reportIcon, textColor: textColor, backgroundColor: backgroundColor,
        onPressed: () => _reportContact(context, widget.info),
      );

  Widget _button(String title, IconData icon, {required Color textColor, required Color backgroundColor,
    VoidCallback? onPressed}) => Row(
    children: [
      Expanded(child: Container(
        color: backgroundColor,
        child: CupertinoButton(
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor,),
              const SizedBox(width: 12,),
              Text(title,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold,),
              ),
            ],
          ),
        ),
      ))
    ],
  );

}

void _reportContact(BuildContext context, ContactInfo info) {
  String text = 'Report Object: "@title"\n'
      'ID: @did\n'
      '\n'
      'Reason: ...\n'
      '(Screenshots will be attached below)'.trParams({
    'title': info.title,
    'did': info.identifier.toString(),
  });
  // open chat box to report
  CustomerService.report(context, text);
}

void _clearHistory(BuildContext ctx, ContactInfo info) {
  Alert.confirm(ctx, 'Confirm', 'Sure to clear chat history of this friend?'.tr,
    okAction: () => _doClear(ctx, info.identifier),
  );
}
void _doClear(BuildContext ctx, ID chat) {
  Amanuensis clerk = Amanuensis();
  clerk.clearConversation(chat).then((ok) {
    if (!ctx.mounted) {
      Log.warning('context unmounted');
    } else if (ok) {
      closePage(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to clear chat history'.tr);
    }
  });
}
