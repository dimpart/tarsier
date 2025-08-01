import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';


class AccountPage extends StatefulWidget {
  const AccountPage(this.user, {super.key});

  final User user;

  static void open(BuildContext context) {
    GlobalVariable shared = GlobalVariable();
    shared.facebook.currentUser.then((user) {
      if (!context.mounted) {
        Log.warning('context unmounted: $context');
      } else if (user == null) {
         Alert.show(context, 'Error', 'Current user not found'.tr);
      } else {
        showPage(
          context: context,
          builder: (context) => AccountPage(user),
        );
      }
    });
  }

  @override
  State<StatefulWidget> createState() => _AccountState();

}

class _AccountState extends State<AccountPage> {

  final FocusNode _focusNode = FocusNode();

  String? _nickname;
  String? _avatarPath;
  Uri? _avatarUrl;

  // static final Uri _upWaiting = Uri.parse('https://chat.dim.sechat/up/waiting');
  // static final Uri _upError = Uri.parse('https://chat.dim.sechat/up/error');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    ClientFacebook facebook = shared.facebook;
    ID identifier = widget.user.identifier;
    _nickname = await facebook.getName(identifier);
    var pnf = await facebook.getAvatar(identifier);
    if (pnf != null) {
      var loader = AvatarFactory().getImageLoader(pnf);
      // await loader.run();
      _avatarPath = await loader.cacheFilePath;
      _avatarUrl = pnf.url;
      Log.info('avatar path: $_avatarPath, url: $_avatarUrl');
    }
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
      backgroundColor: colors.scaffoldBackgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      body: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            backgroundColor: colors.appBardBackgroundColor,
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text('Edit Profile'.tr, style: Styles.titleTextStyle),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: _body(context,
              backgroundColor: colors.sectionItemBackgroundColor,
              backgroundColorActivated: colors.sectionItemDividerColor,
              dividerColor: colors.sectionItemDividerColor,
              primaryTextColor: colors.primaryTextColor,
              secondaryTextColor: colors.tertiaryTextColor,
              importantTextColor: colors.importantButtonColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required Color importantTextColor,
  }) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [

      /// Avatar
      const SizedBox(height: 32,),
      _avatarImage(context),
      const SizedBox(height: 32,),

      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [

          /// ID
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('ID', style: TextStyle(color: primaryTextColor)),
            additionalInfo: SelectableText(
              widget.user.identifier.toString(),
              style: Styles.identifierTextStyle,
            ),
          ),

          /// Nickname
          CupertinoListTile(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            padding: Styles.settingsSectionItemPadding,
            title: Text('Nickname'.tr, style: TextStyle(color: primaryTextColor)),
            additionalInfo: SizedBox(
              width: 160,
              child: _nicknameText(context),
            ),
          ),

        ],
      ),

      CupertinoListSection(
        backgroundColor: dividerColor,
        separatorColor: dividerColor,
        dividerMargin: 0,
        additionalDividerMargin: 0,
        children: [
          /// update profile
          _updateButton(context, backgroundColor: backgroundColor, textColor: importantTextColor),
          /// update description
          _intro('UpdateVisa::Description'.tr, backgroundColor: dividerColor, textColor: secondaryTextColor),
        ],
      ),

      const SizedBox(height: 128,),
    ],
  );

  Widget _avatarImage(BuildContext context) => ClipRRect(
    borderRadius: const BorderRadius.all(Radius.circular(32)),
    child: Stack(
      alignment: AlignmentDirectional.bottomCenter,
      children: [
        if (_avatarPath == null)
        Container(width: 256, height: 256, color: Styles.colors.logoBackgroundColor),
        if (_avatarPath != null)
        ImageUtils.fileImage(_avatarPath!, width: 256, height: 256, fit: BoxFit.cover),
        SizedBox(
          width: 256,
          height: 36,
          child: TextButton(
            onPressed: () => _editAvatar(context),
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all<Color>(Colors.black38),
              foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
              shape: MaterialStateProperty.all(const LinearBorder()),
            ),
            child: Text('Change Avatar'.tr),
          ),
        )
      ],
    ),
  );

  Widget _nicknameText(BuildContext context) => SizedBox(
    width: 160,
    child: CupertinoTextField(
      textAlign: TextAlign.end,
      controller: TextEditingController(text: _nickname),
      placeholder: 'Your nickname'.tr,
      decoration: Styles.textFieldDecoration,
      style: Styles.textFieldStyle,
      focusNode: _focusNode,
      onTapOutside: (event) => _focusNode.unfocus(),
      onChanged: (value) => _nickname = value,
    ),
  );

  Widget _updateButton(BuildContext context, {
    required Color textColor, required Color backgroundColor
  }) => _button('Update & Broadcast'.tr, AppIcons.updateDocIcon,
    textColor: textColor,
    backgroundColor: backgroundColor,
    onPressed: () => _saveInfo(context).then((ok) {
      if (!context.mounted) {
        Log.warning('context unmounted: $context');
      } else if (ok) {
        Alert.show(context, 'Success', 'Profile is updated'.tr);
      } else {
        Alert.show(context, 'Error', 'Failed to update profile'.tr);
      }
    }),
  );

  Widget _button(String title, IconData icon, {
    required Color textColor, required Color backgroundColor,
    VoidCallback? onPressed
  }) => Row(
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

  Widget _intro(String desc, {
    required Color textColor, required Color backgroundColor,
  }) => Row(
    children: [
      Expanded(child: Container(
        color: backgroundColor,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(desc,
          style: TextStyle(
            color: textColor,
          ),
        ),
      ))
    ],
  );

  void _editAvatar(BuildContext context) => openImagePicker(context, onPicked: (path) {
    if (mounted) {
      setState(() {
        _avatarPath = path;
        // _avatarUrl = _upWaiting;
      });
    }
    Log.info('picked avatar: $path');
  }, onRead: (path, jpeg) => adjustImage(jpeg, 256, (Uint8List data) {
    String? ext = Paths.extension(path);
    if (ext == null || ext.toLowerCase() != 'png') {
      ext = 'jpeg';
    }
    String filename = URLHelper.filenameFromData(data, 'avatar.$ext');
    var ftp = SharedFileUploader();
    ftp.uploadAvatar(data, filename, widget.user.identifier).then((url) {
      if (url == null) {
        Log.error('failed to upload avatar: $filename');
        // _avatarUrl = _upError;
      } else {
        Log.warning('avatar uploaded: $filename -> $url');
        _avatarUrl = url;
      }
    }).onError((error, stackTrace) {
      if (context.mounted) {
        Alert.show(context, 'Upload Failed', '$error');
      }
    });
  }));

  Future<bool> _saveInfo(BuildContext context) async {
    // save profile for current user
    GlobalVariable shared = GlobalVariable();
    User user = widget.user;
    // 1. get sign key for current user
    SignKey? sKey = await shared.facebook.getPrivateKeyForVisaSignature(user.identifier)
        .onError((error, stackTrace) {
          if (context.mounted) {
            Alert.show(context, 'Error', 'Failed to get private key'.tr);
          }
          return null;
        });
    if (sKey == null) {
      assert(false, 'private key not found: $user');
      return false;
    }
    // 2. get visa document for current user
    Visa? visa = await user.visa
        .onError((error, stackTrace) {
          if (context.mounted) {
            Alert.show(context, 'Error', 'Failed to get visa'.tr);
          }
          return null;
        });
    if (visa == null) {
      // FIXME: query from station or create a new one?
      assert(false, 'user error: $user');
      return false;
    } else {
      // clone for modifying
      Document? clone = Document.parse(visa.copyMap(false));
      if (clone is Visa) {
        visa = clone;
      } else {
        assert(false, 'visa error: $visa, $user');
        return false;
      }
    }
    // 3. update visa document
    assert(visa.publicKey != null, 'visa error: $visa');
    // set nickname
    String? nickname = _nickname?.trim();
    visa.name = nickname;
    // set avatar URL
    String? url = _avatarUrl?.toString();
    visa.avatar = PortableNetworkFile.parse(url);
    // 4. sign it
    Uint8List? sig = visa.sign(sKey);
    assert(sig != null, 'failed to sign visa: $visa, $user');
    // 5. save it
    var archivist = shared.facebook.archivist;
    bool? ok = await archivist?.saveDocument(visa)
        .onError((error, stackTrace) {
          if (context.mounted) {
            Alert.show(context, 'Error', 'Failed to save visa'.tr);
          }
          return false;
        });
    assert(ok == true, 'failed to save visa: $visa');
    Log.info('visa updated: $ok, $visa');
    if (ok == true) {
      // broadcast this document to all friends
      try {
        await shared.messenger?.broadcastDocuments(updated: true);
      } catch (e, st) {
        Log.error('failed to broadcast document: $user, error: $e, $st');
      }
    }
    return ok == true;
  }

  /*
  void _exportKey(BuildContext context) {
    Alert.show(context, 'Coming soon', 'Export private key'.tr);
  }
   */

}
