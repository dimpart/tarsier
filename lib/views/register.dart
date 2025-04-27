import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../main.dart';


class RegisterPage extends StatefulWidget {
  RegisterPage({super.key});

  final _RegisterInfo _info = _RegisterInfo();

  @override
  State<RegisterPage> createState() => _RegisterState();
}

class _RegisterInfo {

  bool importing = false;

  bool agreed = false;

  String nickname = '';
  String avatarURL = '';

  String? identifier;

  final List<String> _words = [];

  String getWord(int index) => index < _words.length ? _words[index] : '';

  void setWord(int index, String text) {
    while (index >= _words.length) {
      _words.add('');
    }
    _words[index] = text.trim();
  }

}

class _RegisterState extends State<RegisterPage> {

  static Color topColor(BuildContext context) => Styles.colors.logoBackgroundColor;
  static const Color bottomColor = CupertinoColors.white;

  static const Color titleColor = CupertinoColors.white;
  static const Color secondaryTitleColor = Colors.yellowAccent;
  static const Color textColor = CupertinoColors.darkBackgroundGray;

  static const Color memoColor = Colors.black54;
  static const Color okColor = CupertinoColors.systemGreen;

  static const Color tileColor = CupertinoColors.systemBackground;
  // static const Color badgeColor = CupertinoColors.systemGrey3;
  static const Color badgeColor = tarsierLogoBackgroundColor;
  static const Color badgeFontColor = CupertinoColors.white;
  static const Color inputColor = CupertinoColors.black;
  static const Color buttonColor = CupertinoColors.link;

  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // request permission and check current user,
    // if found, change to main page
    _checkCurrentUser(context, () {
      Log.debug('current user not found');
    });
    // build page
    return Scaffold(
      // A ScrollView that creates custom scroll effects using slivers.
      body: Stack(
        children: [
          _ground(context),
          _page(context),
        ],
      ),
      backgroundColor: topColor(context),
    );
  }

  Widget _ground(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [bottomColor, topColor(context)],
        begin: const FractionalOffset(0.6, 0.8),
        end: const FractionalOffset(0.4, 0.2),
        stops: const [0.0, 1.0],
        tileMode: TileMode.clamp,
      ),
    ),
  );

  Widget _page(BuildContext context) => CustomScrollView(
    // A list of sliver widgets.
    slivers: <Widget>[
      CupertinoSliverNavigationBar(
        // This title is visible in both collapsed and expanded states.
        // When the "middle" parameter is omitted, the widget provided
        // in the "largeTitle" parameter is used instead in the collapsed state.
        largeTitle: Text(
          widget._info.importing ? 'Import'.tr : 'Register'.tr,
          style: const TextStyle(
            color: titleColor,
          ),
        ),
        trailing: TextButton(
          child: Text(
            widget._info.importing ? 'Register'.tr : 'Import'.tr,
            style: const TextStyle(
              color: secondaryTitleColor,
            ),
          ),
          onPressed: () => setState(() {
            widget._info.importing = !widget._info.importing;
          }),
        ),
        backgroundColor: topColor(context),
      ),
      // This widget fills the remaining space in the viewport.
      // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
      SliverFillRemaining(
        hasScrollBody: false,
        fillOverscroll: true,
        child: _form(context),
      ),
    ],
  );

  Widget _logo() => SizedBox(
    width: 32,
    height: 32,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eye(),
        const SizedBox(width: 4,),
        _eye(),
      ],
    ),
  );
  Widget _eye() => const Icon(Icons.panorama_fish_eye,
    size: 8,
    color: CupertinoColors.white,
  );

  Widget _form(BuildContext context) => Column(
    // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: <Widget>[
      const SizedBox(
        height: 32,
      ),
      if (widget._info.importing)
        SizedBox(
          width: 320,
          child: _mosaics(context),
        ),
      if (widget._info.identifier != null)
        Container(
          width: 360,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          alignment: AlignmentDirectional.center,
          child: SelectableText('${widget._info.identifier}',
            style: Styles.identifierTextStyle,
          ),
        ),
      if (!widget._info.importing)
        _logo(),
      if (!widget._info.importing)
        SizedBox(
          width: 360,
          height: 500,
          child: _welcome(),
        ),
      const SizedBox(
        height: 32,
      ),
      Container(
        width: 260,
        alignment: Alignment.center,
        child: _nicknameField(context),
      ),
      const SizedBox(
        height: 32,
      ),
      _okButton(context),
      _terms(context),
      _privacyPolicy(context),
      const SizedBox(
        height: 128,
      ),
    ],
  );

  Widget _mosaics(BuildContext context) {
    List<Widget> tiles = [];
    for (int index = 0; index < 12; ++index) {
      tiles.add(_tile(widget._info.getWord(index), index));
    }
    List<Row> rows = [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Mnemonic Codes'.tr,
            style: const TextStyle(
              color: secondaryTitleColor,
              fontSize: 20,
            ),
          ),
        ],
      ),
      Row(
        children: [
          SizedBox(
            width: 320,
            child: _memo('MnemonicCodes::Description'.tr,
            ),
          ),
        ],
      )
    ];
    const int width = 3;
    int start = 0, end;
    for (start = 0; start < 12; start = end) {
      end = start + width;
      if (end < 12) {
        rows.add(Row(
          children: tiles.sublist(start, end),
        ));
      } else {
        rows.add(Row(
          children: tiles.sublist(start),
        ));
      }
    }
    return Column(
      children: rows,
    );
  }

  Future<void> _refreshIdentifier() async {
    var result = await _saveMnemonic(widget._info);
    String? address = result?.second;
    if (address == null && widget._info.identifier == null) {
      return;
    }
    if (mounted) {
      setState(() {
        widget._info.identifier = address;
      });
    }
  }

  Widget _tile(String word, int index) => Expanded(
    child: Stack(
      alignment: AlignmentDirectional.topEnd,
      children: [
        Container(
          color: tileColor,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
          alignment: Alignment.center,
          child: CupertinoTextField(
            decoration: const BoxDecoration(),
            style: const TextStyle(color: inputColor),
            textAlign: TextAlign.center,
            controller: TextEditingController(text: word),
            onChanged: (value) {
              widget._info.setWord(index, value);
              _refreshIdentifier();
            },
          ),
        ),
        Container(
          margin: const EdgeInsets.all(6),
          child: ClipOval(
            child: Container(
              alignment: Alignment.center,
              width: 12, height: 12,
              color: badgeColor,
              child: Text('${index + 1}',
                style: const TextStyle(
                  fontSize: 8,
                  color: badgeFontColor,
                ),
              ),
            ),
          ),
        )
      ],
    ),
  );

  Widget _welcome() => Column(
    children: [
      _memo('Imagine a world where you can message anyone without being forced to install the same app.'),
      _memo('Imagine a world where you can host your own communication and still be part of a huge network.'),
      _memo('This will be brought to you by Tarsier Secure Chat, which is powered by DIM'
          ' - an open source project that provides the protocol and system architecture.'),
      _memo('DIM network is decentralized, and there is no one server, company, or person running it.'
          ' Anyone can join and run their own services on DIM network.'),
      _memo('When someone joins DIM network with their servers, they are called Service Providers.'
          ' Since DIM network is open, a Service Provider can have its own set of services,'
          ' while complying with DIM Protocol.'
          ' User identification is generated and verified using a cryptographically algorithm,'
          ' and no longer authenticated by a single corporation.'
          ' Because of this, Service Providers cannot monetize the user’s privacy or data,'
          ' they must compete by providing better services.'
          ' This means that all the Service Providers share the same potential user base.'
          ' And users could choose the Service Provider that fits their needs at anytime.'),
      _memo(''),
      _memo('As a user, all you need to do now is just input a nickname and enter the wonderful world!'),
    ],
  );

  Widget _memo(String text, {double fontSize = 12}) => Container(
    padding: const EdgeInsets.all(4),
    alignment: Alignment.topLeft,
    child: Text(text, style: TextStyle(fontSize: fontSize, color: memoColor)),
  );

  Widget _nicknameField(BuildContext context) => Row(
    children: [
      Text(
        '${'Name'.tr}: ',
        style: const TextStyle(
          color: textColor,
          fontSize: 20,
        ),
      ),
      SizedBox(
        width: 160,
        child: CupertinoTextField(
          textAlign: TextAlign.center,
          placeholder: 'Your nickname'.tr,
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            border: Border.all(
              color: CupertinoColors.lightBackgroundGray,
              style: BorderStyle.solid,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          style: const TextStyle(
            height: 1.6,
            color: CupertinoColors.black,
          ),
          focusNode: _focusNode,
          onTapOutside: (event) => _focusNode.unfocus(),
          onChanged: (value) => setState(() {
            widget._info.nickname = value.trim();
          }),
        ),
      ),
    ],
  );

  Widget _okButton(BuildContext context) => CupertinoButton(
    color: okColor,
    borderRadius: const BorderRadius.all(Radius.circular(24)),
    onPressed: () {
      _submit(context, widget._info);
    },
    child: const Text("Let's rock!",
      style: TextStyle(color: titleColor),
    ),
  );

  Widget _terms(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      CupertinoButton(
        child: Container(
          decoration: BoxDecoration(
            color: widget._info.agreed
                ? CupertinoColors.systemGreen
                : CupertinoColors.white,
            border: Border.all(
              color: CupertinoColors.systemGrey,
              style: BorderStyle.solid,
              width: 1,
            ),
            borderRadius: const BorderRadius.all(Radius.circular(5)),
          ),
          child: Icon(widget._info.agreed
              ? AppIcons.agreeIcon
              : AppIcons.disagreeIcon,
            size: 16,
            color: widget._info.agreed
                ? CupertinoColors.white
                : CupertinoColors.systemGrey,
          ),
        ),
        onPressed: () => setState(() {
          widget._info.agreed = !widget._info.agreed;
        }),
      ),
      Text('Agreed with the'.tr,
        style: const TextStyle(color: CupertinoColors.black),
      ),
      TextButton(
        child: Text('Terms'.tr,
          style: const TextStyle(color: buttonColor),
        ),
        onPressed: () => Config().load().then((config) {
          if (context.mounted) {
            Browser.open(context, config.termsURL);
          }
        }),
      ),
    ],
  );

  Widget _privacyPolicy(BuildContext context) => TextButton(
    child: Text('Privacy Policy'.tr,
      style: const TextStyle(color: buttonColor),
    ),
    onPressed: () => Config().load().then((config) {
      if (context.mounted) {
        Browser.open(context, config.privacyURL);
      }
    }),
  );

}

void _submit(BuildContext context, _RegisterInfo info) =>
    _checkCurrentUser(context, () {
      if (info.nickname.isEmpty) {
        Alert.show(context, 'Input Name', 'Please input your nickname'.tr);
      } else if (!info.agreed) {
        Alert.show(context, 'Terms', 'Please agree the privacy policy'.tr);
      } else {
        (info.importing ? _importAccount(context, info) : _createAccount(context, info))
            .then((identifier) {
              if (!context.mounted) {
                Log.warning('context unmounted: $context');
              } else if (identifier != null) {
                _addUser(context, identifier).onError((error, stackTrace) {
                  Log.error('add user error: $error');
                  return false;
                });
              } else if (info.importing) {
                Alert.show(context, 'Error', 'Failed to import account'.tr);
              } else {
                Alert.show(context, 'Fatal Error', 'Failed to generate ID'.tr);
              }
            });
      }
    });

Future<ID?> _createAccount(BuildContext context, _RegisterInfo info) async {
  GlobalVariable shared = GlobalVariable();
  Account register = Account(shared.database);
  return await register.createUser(
      name: info.nickname,
      avatar: info.avatarURL,
  );
}

Future<ID?> _importAccount(BuildContext context, _RegisterInfo info) async {
  GlobalVariable shared = GlobalVariable();
  // get private key
  var result = await _saveMnemonic(info);
  PrivateKey? idKey = result?.first;
  if (idKey == null) {
    Log.error('failed to get private key');
    return null;
  }
  // generate account with private key
  Account register = Account(shared.database);
  return await register.generateUser(
      name: info.nickname,
      avatar: info.avatarURL,
      idKey: idKey,
  );
}

Future<Pair<PrivateKey?, String?>?> _saveMnemonic(_RegisterInfo info) async {
  String mnemonic = info._words.join(' ');
  GlobalVariable shared = GlobalVariable();
  Keychain keychain = Keychain(shared.database);
  if (await keychain.saveMnemonic(mnemonic)) {
    Log.debug('mnemonic saved: [$mnemonic]');
  } else {
    Log.debug('mnemonic error: [$mnemonic]');
    return null;
  }
  int version = Account.type;
  if (version == MetaType.ETH || version == MetaType.ExETH) {
    return Pair(await keychain.ethKey, await keychain.ethAddress);
  } else {
    assert(version == MetaType.BTC || version == MetaType.ExBTC
        || version == MetaType.MKM, 'meta type error: $version');
    return Pair(await keychain.btcKey, await keychain.btcAddress);
  }
}

Future<bool> _addUser(BuildContext context, ID identifier) async {
  GlobalVariable shared = GlobalVariable();
  return shared.database.addUser(identifier).then((value) {
    if (context.mounted) {
      changeToMainPage(context);
    }
    return true;
  });
}

void _checkCurrentUser(BuildContext context, void Function() onNotFound) {
  GlobalVariable shared = GlobalVariable();
  Log.debug('checking permissions');
  PermissionCenter().requestDatabasePermissions(context, onGranted: (context) {
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        onNotFound();
      } else if (context.mounted) {
        changeToMainPage(context);
      }
    }).onError((error, stackTrace) {
      Log.error('current user error: $error');
    });
  });
}
