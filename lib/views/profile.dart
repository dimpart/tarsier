import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'chat_box.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage(this.info, this.fromChat, {super.key});

  final ContactInfo info;
  final ID? fromChat;

  static void open(BuildContext context, ID identifier, {ID? fromChat}) {
    ContactInfo info = ContactInfo.fromID(identifier);
    info.reloadData().then((value) {
      showCupertinoDialog(
        context: context,
        builder: (context) => ProfilePage(info, fromChat),
      );
    }).onError((error, stackTrace) {
      Alert.show(context, 'Error', '$error');
    });
    // query for update
    GlobalVariable shared = GlobalVariable();
    shared.messenger?.queryDocument(identifier);
    if (identifier.isGroup) {
      shared.messenger?.queryMembers(identifier);
    }
  }

  static Widget cell(ContactInfo info, {GestureLongPressCallback? onLongPress}) =>
      _ProfileTableCell(info, onLongPress: onLongPress);

  @override
  State<StatefulWidget> createState() => _ProfileState();

}

class _ProfileState extends State<ProfilePage> implements lnc.Observer {
  _ProfileState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
    nc.addObserver(this, NotificationNames.kContactsUpdated);
    nc.addObserver(this, NotificationNames.kBlockListUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
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
        if (mounted) {
          setState(() {
            // update name in title
          });
        }
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
      if (contact != null) {
        if (contact == widget.info.identifier) {
          await _reload();
        }
      } else {
        // block-list updated
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    // A ScrollView that creates custom scroll effects using slivers.
    body: CustomScrollView(
      // A list of sliver widgets.
      slivers: <Widget>[
        CupertinoSliverNavigationBar(
          backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
          // This title is visible in both collapsed and expanded states.
          // When the "middle" parameter is omitted, the widget provided
          // in the "largeTitle" parameter is used instead in the collapsed state.
          largeTitle: Text(widget.info.name,
            style: Facade.of(context).styles.titleTextStyle,
          ),
        ),
        // This widget fills the remaining space in the viewport.
        // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: true,
          child: SingleChildScrollView(
            child: _body(context),
          ),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      const SizedBox(height: 32,),
      _avatarImage(context),
      const SizedBox(height: 8,),
      _idLabel(context),
      const SizedBox(height: 32,),

      /// add friend
      if (!widget.info.isFriend)
        _addButton(context),
      if (widget.info.isFriend)
        Column(
          children: [
            if (!widget.info.isBlocked)
              _sendButton(context),
            /// clear history / delete contact
            const SizedBox(height: 8,),
            if (widget.fromChat != null)
            _clearButton(context),
            if (widget.fromChat == null)
            _deleteButton(context),
          ],
        ),
      const SizedBox(height: 32,),

      /// block/unblock
      if (!widget.info.isBlocked)
        _blockButton(context),
      if (widget.info.isBlocked)
        _unblockButton(context),

      const SizedBox(height: 64,),
    ],
  );

  Widget _avatarImage(BuildContext context) =>
      widget.info.getImage(width: 256, height: 256, onTap: () {
        GlobalVariable shared = GlobalVariable();
        shared.facebook.getAvatar(widget.info.identifier).then((pair) {
          String? path = pair.first;
          if (path == null) {
            Log.error('avatar image not found: ${widget.info.identifier}');
          } else {
            previewImage(context, path);
          }
        });
      });

  Widget _idLabel(BuildContext context) => Row(
    // mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Text('ID: ',
        style: TextStyle(fontSize: 12,
          color: Colors.blueGrey,
          fontWeight: FontWeight.bold,
        ),
      ),
      Container(
        constraints: const BoxConstraints(maxWidth: 336),
        child: SelectableText(widget.info.identifier.toString(),
          style: Facade.of(context).styles.identifierTextStyle,
        ),
      ),
    ],
  );

  Widget _addButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.normalButtonColor,
      child: Text('Add Contact', style: Facade.of(context).styles.buttonStyle),
      onPressed: () => widget.info.add(context: context),
    ),
  );

  Widget _sendButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.normalButtonColor,
      child: Text('Send Message', style: Facade.of(context).styles.buttonStyle),
      onPressed: () => _sendMessage(context, widget.info, widget.fromChat),
    ),
  );

  Widget _clearButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.importantButtonColor,
      child: Text('Clear History', style: Facade.of(context).styles.buttonStyle),
      onPressed: () => _clearHistory(context, widget.info),
    ),
  );

  Widget _deleteButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.criticalButtonColor,
      child: Text(widget.info.identifier.isUser ? 'Delete Contact' : 'Delete Group',
        style: Facade.of(context).styles.buttonStyle,
      ),
      onPressed: () => widget.info.delete(context: context),
    ),
  );

  Widget _blockButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.importantButtonColor,
      child: Text('Block',
        style: Facade.of(context).styles.buttonStyle,
      ),
      onPressed: () => _doBlock(context, widget.info),
    ),
  );

  Widget _unblockButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: Facade.of(context).colors.importantButtonColor,
      child: Text('Unblock',
        style: Facade.of(context).styles.buttonStyle,
      ),
      onPressed: () => _unblock(context, widget.info),
    ),
  );

}

void _sendMessage(BuildContext ctx, ContactInfo info, ID? fromChat) {
  if (info.identifier == fromChat) {
    // this page is open from a chat box
    Navigator.pop(ctx);
  } else {
    ChatBox.open(ctx, info);
  }
}

void _clearHistory(BuildContext ctx, ContactInfo info) {
  String msg;
  if (info.identifier.isUser) {
    msg = 'Are you sure want to clear chat history of this friend?';
  } else {
    msg = 'Are you sure want to clear chat history of this group?';
  }
  Alert.confirm(ctx, 'Confirm', msg,
    okAction: () => _doClear(ctx, info.identifier),
  );
}
void _doClear(BuildContext ctx, ID chat) {
  Amanuensis clerk = Amanuensis();
  clerk.clearConversation(chat).then((ok) {
    if (ok) {
      Navigator.pop(ctx);
    } else {
      Alert.show(ctx, 'Error', 'Failed to clear chat history');
    }
  });
}

void _doBlock(BuildContext ctx, ContactInfo info) {
  String msg = 'Are you sure want to block this contact?'
      ' You will never receive it\'s message again.';
  Alert.confirm(ctx, 'Confirm Block', msg,
    okAction: () => info.block(context: ctx),
  );
}
void _unblock(BuildContext ctx, ContactInfo info) {
  String msg = 'Are you sure want to unblock this contact?';
  Alert.confirm(ctx, 'Confirm Unblock', msg,
    okAction: () => info.unblock(context: ctx),
  );
}

//
//  Profile Table Cell
//

class _ProfileTableCell extends StatefulWidget {
  const _ProfileTableCell(this.info, {this.onLongPress});

  final ContactInfo info;
  final GestureLongPressCallback? onLongPress;

  @override
  State<StatefulWidget> createState() => _ProfileTableState();

}

class _ProfileTableState extends State<_ProfileTableCell> implements lnc.Observer {
  _ProfileTableState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == widget.info.identifier) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
        //
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: widget.info.getImage(),
    title: Text(widget.info.name),
    subtitle: Text(widget.info.identifier.toString()),
    onTap: () => ProfilePage.open(context, widget.info.identifier),
    onLongPress: widget.onLongPress,
  );

}
