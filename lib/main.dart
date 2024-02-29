import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'views/chats.dart';
import 'views/customizer.dart';
import 'views/contacts.dart';
import 'views/register.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set log level
  Log.level = Log.kDevelop;
  if (DevicePlatform.isIOS) {
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
  bool permitted = await checkDatabasePermissions();
  // Launch the app
  if (!permitted) {
    // not granted for photos/storage, first run?
    Log.warning('not granted for photos/storage, first run?');
    launchApp(RegisterPage());
  } else {
    // check current user
    Log.debug('check current user');
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    Log.info('current user: $user');
    if (user == null) {
      launchApp(RegisterPage());
    } else {
      launchApp(const _MainPage());
    }
  }
}

void changeToMainPage(BuildContext context) {
  // closePage();
  Navigator.pop(context);
  openPage(const _MainPage());
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
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    forceAppUpdate();
  }

  @override
  Widget build(BuildContext context) => CupertinoTabScaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    tabBar: CupertinoTabBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
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
