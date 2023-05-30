import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    Log.debug('mnemonic: $mnemonic');
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
          largeTitle: Text('Mnemonic', style: Facade.of(context).styles.titleTextStyle),
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
        child: _mosaics(context),
      ),
      const SizedBox(height: 16,),
      _memo(context, '* Mnemonic is your private key,'
          ' anyone got these words can own your account;'),
      _memo(context, '* You could write it down on a piece of paper'
          ' and keep it somewhere safety,'
          ' take a screenshot and store it in your computer is not recommended.'),
      const SizedBox(height: 32,),
      _toggleButton(context),
      const SizedBox(height: 64,),
    ],
  );

  Widget _mosaics(BuildContext context) {
    List<Widget> tiles = [];
    for (int index = 0; index < _words.length; ++index) {
      tiles.add(_tile(context, _words[index], index));
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

  Widget _tile(BuildContext context, String word, int index) => Expanded(
      child: Stack(
        alignment: AlignmentDirectional.topEnd,
        children: [
          Container(
            color: Facade.of(context).colors.tileBackgroundColor,
            margin: const EdgeInsets.all(1),
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
            alignment: Alignment.center,
            child: Text(visible ? word : '***',
              style: TextStyle(
                fontSize: 14,
                color: visible ? Facade.of(context).colors.tileColor
                    : Facade.of(context).colors.tileInvisibleColor,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(6),
            child: ClipOval(
              child: Container(
                alignment: Alignment.center,
                width: 12, height: 12,
                color: Facade.of(context).colors.tileBadgeColor,
                child: Text('${index + 1}',
                  style: TextStyle(
                    fontSize: 8,
                    color: Facade.of(context).colors.tileOrderColor,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
  );

  Widget _memo(BuildContext context, String text) => Container(
    width: 300,
    padding: const EdgeInsets.all(4),
    alignment: Alignment.topLeft,
    child: Text(text,
      style: TextStyle(fontSize: 12,
        color: visible ? Facade.of(context).colors.tertiaryTextColor
            : Facade.of(context).colors.secondaryTextColor,
      ),
    ),
  );

  Widget _toggleButton(BuildContext context) => SizedBox(
    width: 256,
    child: CupertinoButton(
      color: visible ? Facade.of(context).colors.normalButtonColor
          : Facade.of(context).colors.importantButtonColor,
      child: Text(visible ? 'Hide' : 'Show', style: Facade.of(context).styles.buttonStyle),
      onPressed: () => setState(() {
        visible = !visible;
      }),
    ),
  );

}
