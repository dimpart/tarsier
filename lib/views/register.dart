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
    _words[index] = text;
  }

}

class _RegisterState extends State<RegisterPage> {

  static const Color topColor = Colors.purple;
  static const Color bottomColor = Colors.blueAccent;

  static const Color textColor = Colors.white70;
  static const Color buttonColor = Colors.greenAccent;

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
          _ground(),
          _page(),
        ],
      ),
      backgroundColor: topColor,
    );
  }

  Widget _ground() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [bottomColor, topColor],
        begin: FractionalOffset(0.4, 1.0),
        end: FractionalOffset(0.6, 0.2),
        stops: [0.0, 1.0],
        tileMode: TileMode.clamp,
      ),
    ),
  );

  Widget _page() => CustomScrollView(
    // A list of sliver widgets.
    slivers: <Widget>[
      CupertinoSliverNavigationBar(
        // This title is visible in both collapsed and expanded states.
        // When the "middle" parameter is omitted, the widget provided
        // in the "largeTitle" parameter is used instead in the collapsed state.
        largeTitle: Text(
          widget._info.importing ? 'Import' : 'Register',
          style: const TextStyle(
            color: textColor,
          ),
        ),
        trailing: TextButton(
          child: Text(
            widget._info.importing ? 'Register' : 'Import',
            style: const TextStyle(
              color: buttonColor,
            ),
          ),
          onPressed: () => setState(() {
            widget._info.importing = !widget._info.importing;
          }),
        ),
        backgroundColor: topColor,
      ),
      // This widget fills the remaining space in the viewport.
      // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
      SliverFillRemaining(
        hasScrollBody: false,
        fillOverscroll: true,
        child: _form(),
      ),
    ],
  );

  Widget _form() => Column(
    // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: <Widget>[
      const SizedBox(
        height: 32,
      ),
      if (widget._info.importing)
        SizedBox(
          width: 320,
          child: _mosaics(),
        ),
      if (!widget._info.importing)
        SizedBox(
          width: 320,
          height: 256,
          child: _welcome(),
        ),
      const SizedBox(
        height: 32,
      ),
      Container(
        width: 240,
        alignment: Alignment.center,
        child: _nicknameField(),
      ),
      const SizedBox(
        height: 32,
      ),
      _okButton(context),
      Container(
        width: 320,
        alignment: Alignment.center,
        child: _privacyPolicy(context),
      ),
      const SizedBox(
        height: 32,
      ),
    ],
  );

  Widget _mosaics() {
    List<Widget> tiles = [];
    for (int index = 0; index < 12; ++index) {
      tiles.add(_tile(widget._info.getWord(index), index));
    }
    List<Row> rows = [
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Mnemonic Codes',
            style: TextStyle(
              color: Colors.yellowAccent,
              fontSize: 20,
            ),
          ),
        ],
      ),
      Row(
        children: [
          SizedBox(
            width: 320,
            child: _memo('Mnemonic is the private key for an existing account,'
                ' if you don\'t have one, please click "Register" button'
                ' on the top-right corner to generate a new one.',
              fontSize: 12,
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
    String? identifier = widget._info.identifier;
    if (identifier != null) {
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            height: 32,
          ),
          SelectableText(identifier,
            style: const TextStyle(fontSize: 12,
              color: Colors.teal,
            ),
          ),
        ],
      ));
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
          color: Colors.white24,
          margin: const EdgeInsets.all(1),
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          alignment: Alignment.center,
          child: CupertinoTextField(
            decoration: const BoxDecoration(
              // color: CupertinoColors.tertiarySystemFill,
            ),
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
              color: CupertinoColors.lightBackgroundGray,
              child: Text('${index + 1}',
                style: const TextStyle(
                  fontSize: 8,
                  color: CupertinoColors.secondaryLabel,
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
      _memo('Welcome to the social network you control!'),
      _memo('Here is a world where you can host your own communication'
          ' and still be part of a huge network.'
          ' DIM network is decentralized, and there is no one server,'
          ' company, or person running it. Anyone can join and run'
          ' their own services on DIM network.'),
      _memo('All you need to do is just input a nickname to enter'
          ' the wonderful world now.'),
    ],
  );

  Widget _memo(String text, {double fontSize = 16}) => Container(
    padding: const EdgeInsets.all(4),
    alignment: Alignment.topLeft,
    child: Text(text, style: TextStyle(fontSize: fontSize, color: textColor)),
  );

  Widget _nicknameField() => Row(
    children: [
      const Text(
        'Name: ',
        style: TextStyle(
          color: textColor,
          fontSize: 20,
        ),
      ),
      SizedBox(
        width: 160,
        child: CupertinoTextField(
          placeholder: 'your nickname',
          padding: const EdgeInsets.only(left: 10, right: 10,),
          style: const TextStyle(
            fontSize: 20,
            height: 1.6,
          ),
          focusNode: _focusNode,
          onTapOutside: (event) => _focusNode.unfocus(),
          onChanged: (value) => setState(() {
            widget._info.nickname = value;
          }),
        ),
      ),
    ],
  );

  Widget _okButton(BuildContext context) => CupertinoButton(
    color: Colors.red,
    borderRadius: const BorderRadius.all(Radius.circular(24)),
    onPressed: () {
      _submit(context, widget._info);
    },
    child: const Text("Let's rock!"),
  );

  Widget _privacyPolicy(BuildContext context) => Row(
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
          child: Icon(Styles.agreeIcon,
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
      const Text('Agreed with the'),
      TextButton(
        child: const Text('DIM Privacy Policy',
          style: TextStyle(color: buttonColor),
        ),
        onPressed: () => Config().termsURL.then((url) => Browser.open(context,
          url: url,
          title: 'Privacy Policy',
        )),
      ),
    ],
  );

}

void _submit(BuildContext context, _RegisterInfo info) =>
    _checkCurrentUser(context, () {
      if (info.nickname.isEmpty) {
        Alert.show(context, 'Input Name', 'Please input your nickname.');
      } else if (!info.agreed) {
        Alert.show(context, 'Privacy Policy', 'Please read and agree the privacy policy.');
      } else {
        (info.importing ? _importAccount(context, info) : _createAccount(context, info))
            .then((identifier) => {
              if (identifier != null) {
                _addUser(context, identifier).onError((error, stackTrace) {
                  Log.error('add user error: $error');
                  return false;
                })
              } else if (info.importing) {
                Alert.show(context, 'Error', 'Failed to import account,'
                    ' please check your mnemonic codes.')
              } else {
                Alert.show(context, 'Fatal Error', 'Failed to generate ID.')
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
  if (version == MetaType.kETH || version == MetaType.kExETH) {
    return Pair(await keychain.ethKey, await keychain.ethAddress);
  } else {
    assert(version == MetaType.kBTC || version == MetaType.kExBTC
        || version == MetaType.kMKM, 'meta type error: $version');
    return Pair(await keychain.btcKey, await keychain.btcAddress);
  }
}

Future<bool> _addUser(BuildContext context, ID identifier) async {
  GlobalVariable shared = GlobalVariable();
  return shared.database.addUser(identifier).then((value) {
    changeToMainPage(context);
    return true;
  });
}

void _checkCurrentUser(BuildContext context, void Function() onNotFound) {
  GlobalVariable shared = GlobalVariable();
  Log.debug('checking permissions');
  requestStoragePermissions(context, onGranted: (context) {
    shared.facebook.currentUser.then((user) {
      if (user == null) {
        onNotFound();
      } else {
        changeToMainPage(context);
      }
    }).onError((error, stackTrace) {
      Log.error('current user error: $error');
    });
  });
}
