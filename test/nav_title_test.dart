// Minimal reproduction test:
// does CupertinoSliverNavigationBar.largeTitle update on setState?
//
// The widget tree copies the structure of lib/views/register.dart:
//   Scaffold -> Stack -> CustomScrollView -> [CupertinoSliverNavigationBar, SliverToBoxAdapter]

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, TextButton;
import 'package:flutter_test/flutter_test.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<StatefulWidget> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  bool importing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: <Widget>[
              CupertinoSliverNavigationBar(
                alwaysShowMiddle: false,
                largeTitle: Text(importing ? 'Import' : 'Register'),
                middle: Text(importing ? 'Import' : 'Register'),
                trailing: TextButton(
                  child: Text(importing ? 'Register' : 'Import'),
                  onPressed: () => setState(() {
                    importing = !importing;
                  }),
                ),
              ),
              SliverToBoxAdapter(
                child: Text(importing ? 'importing-form' : 'registering-form'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  testWidgets('largeTitle updates after toggling flag', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: TestPage()));
    await tester.pumpAndSettle();

    // initial state: register
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('importing-form'), findsNothing);

    // tap the trailing toggle button
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    // after toggle: form switched, large title should switch too
    expect(find.text('importing-form'), findsOneWidget,
        reason: 'form should switch to importing mode');
    expect(find.widgetWithText(CupertinoSliverNavigationBar, 'Import'),
        findsOneWidget,
        reason: 'large title should show "Import" after toggling');
  });

  testWidgets('largeTitle updates after scrolling (collapsed) and toggling',
      (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: TestPage()));
    await tester.pumpAndSettle();

    // scroll down to collapse the nav bar
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    // tap the toggle button in the collapsed bar
    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('importing-form'), findsOneWidget,
        reason: 'form should switch to importing mode');
    expect(find.widgetWithText(CupertinoSliverNavigationBar, 'Import'),
        findsOneWidget,
        reason: 'collapsed middle title should show "Import" after toggling');
  });
}
