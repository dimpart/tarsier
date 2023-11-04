import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'views/chats.dart';
import 'views/customizer.dart';
import 'views/contacts.dart';
import 'views/register.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set log level
  Log.level = Log.kDevelop;
  if (Platform.isIOS) {
    Log.colorful = false;
    Log.showTime = true;
    Log.showCaller = true;
  } else {
    Log.colorful = true;
    Log.showTime = true;
    Log.showCaller = true;
  }

  bool released = Log.level == Log.kRelease;
  if (released) {
    // This app is designed only to work vertically, so we limit
    // orientations to portrait up and down.
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
    );
  }

  // Check Brightness & Language
  await initFacade();
  // Check permission: Storage
  bool permitted = await checkStoragePermissions();
  // Launch the app
  if (!permitted) {
    // not granted for photos/storage, first run?
    Log.warning('not granted for photos/storage, first run?');
    runApp(_Application(RegisterPage()));
  } else {
    // check current user
    Log.debug('check current user');
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    Log.info('current user: $user');
    if (user == null) {
      runApp(_Application(RegisterPage()));
    } else {
      runApp(const _Application(_MainPage()));
    }
  }
}

void changeToMainPage(BuildContext context) {
  Navigator.pop(context);
  Navigator.push(context, CupertinoPageRoute(
    builder: (context) => const _MainPage(),
  ));
}

class _Application extends StatelessWidget {
  const _Application(this.home);

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    // debugShowCheckedModeBanner: false,
    theme: ThemeData.light(useMaterial3: true),
    darkTheme: ThemeData.dark(useMaterial3: true),
    home: home,
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
    ],
  );
}

class _MainPage extends StatefulWidget {
  const _MainPage();

  @override
  State<_MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<_MainPage> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Log.info('didChangeAppLifecycleState: state=$state');
    GlobalVariable shared = GlobalVariable();
    shared.terminal.onAppLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    tabBar: CupertinoTabBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      items: [
        ChatHistoryPage.barItem(),
        ContactListPage.barItem(),
        SettingsPage.barItem(),
      ],
    ),
    tabBuilder: (context, index) {
      Widget page;
      if (index == 0) {
        page = const ChatHistoryPage();
      } else if (index == 1) {
        page = const ContactListPage();
      } else {
        page = const SettingsPage();
      }
      return CupertinoTabView(
        builder: (context) {
          return page;
        },
      );
    },
  );
}
