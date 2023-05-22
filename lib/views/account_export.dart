import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';


class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<StatefulWidget> createState() => _ExportState();

}

class _ExportState extends State<ExportPage> {

  final List<String> _words = [];
  bool visible = false;

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    Keychain keychain = Keychain(shared.database);
    String? mnemonic = await keychain.mnemonic;
    if (mnemonic != null && mounted) {
      setState(() {
        _words.addAll(mnemonic.split(' '));
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    // A ScrollView that creates custom scroll effects using slivers.
    child: CustomScrollView(
      // A list of sliver widgets.
      slivers: <Widget>[
        const CupertinoSliverNavigationBar(
          // This title is visible in both collapsed and expanded states.
          // When the "middle" parameter is omitted, the widget provided
          // in the "largeTitle" parameter is used instead in the collapsed state.
          largeTitle: Text('Mnemonic'),
        ),
        // This widget fills the remaining space in the viewport.
        // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: true,
          child: _body(context),
        ),
      ],
    ),
  );

  Widget _body(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      const SizedBox(height: 32,),
      SizedBox(
        width: 320,
        child: _mosaics(),
      ),
      const SizedBox(height: 16,),
      _memo('* Mnemonic is your private key,'
          ' anyone got these words can own your account;'),
      _memo('* You could write it down on a piece of paper'
          ' and keep it somewhere safety,'
          ' take a screenshot and store it in your computer is not recommended.'),
      const SizedBox(height: 32,),
      _toggleButton(),
      const SizedBox(height: 64,),
    ],
  );

  Widget _mosaics() {
    List<Widget> tiles = [];
    for (int index = 0; index < _words.length; ++index) {
      tiles.add(_tile(_words[index], index));
    }
    List<Row> rows = [];
    const int width = 3;
    int start = 0, end;
    for (start = 0; start < _words.length; start = end) {
      end = start + width;
      if (end < _words.length) {
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

  Widget _tile(String word, int index) => Expanded(
      child: Stack(
        alignment: AlignmentDirectional.topEnd,
        children: [
          Container(
            color: CupertinoColors.extraLightBackgroundGray,
            margin: const EdgeInsets.all(1),
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            alignment: Alignment.center,
            child: Text(visible ? word : '***',
              style: TextStyle(
                color: visible ? CupertinoColors.black : CupertinoColors.systemGrey,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            child: ClipOval(
              child: Container(
                alignment: Alignment.center,
                width: 12, height: 12,
                color: CupertinoColors.white,
                child: Text('${index + 1}',
                  style: const TextStyle(
                    fontSize: 8,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
  );

  Widget _memo(String text) => Container(
    width: 300,
    padding: const EdgeInsets.all(4),
    alignment: Alignment.topLeft,
    child: Text(text,
      style: TextStyle(fontSize: 12,
        color: visible ? CupertinoColors.systemGrey : CupertinoColors.black,
      ),
    ),
  );

  Widget _toggleButton() => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: visible ? CupertinoColors.systemBlue : CupertinoColors.systemOrange,
      child: Text(visible ? 'Hide' : 'Show'),
      onPressed: () => setState(() {
        visible = !visible;
      }),
    ),
  );

}
