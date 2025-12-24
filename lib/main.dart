import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'views/chats.dart';
import 'views/customizer.dart';
import 'views/contacts.dart';
import 'views/register.dart';
import 'views/services.dart';
import 'views/setting/account.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  var newest = NewestManager();
  newest.store = 'Demo';
  // newest.store = 'Apple';       // appstoreconnect.apple.com
  // newest.store = 'Google';      // play.google.com
  // newest.store = 'Amazon';      // developer.amazon.com
  // newest.store = 'GSP';         // tarsier.dim.chat
  /// TODO: set distribution channel name

  // Set log level
  Log.level = Log.RELEASE;
  // Log.level = Log.DEVELOP;
  if (DevicePlatform.isIOS) {
    Log.colorful = false;
    Log.showTime = false;
    Log.showCaller = true;
  } else {
    Log.colorful = true;
    Log.showTime = true;
    Log.showCaller = true;
  }

  // debugShowCheckedModeBanner
  bool debug = false;
  assert((){
    debug = Log.level != Log.RELEASE;
    return true;
  }());

  // Check Brightness & Language
  await initFacade();
  // Check permission: Storage
  bool permitted = await PermissionChecker().checkDatabasePermissions();
  // Launch the app
  if (!permitted) {
    // not granted for photos/storage, first run?
    Log.warning('not granted for photos/storage, first run?');
    launchApp(RegisterPage(), debug: debug);
  } else {
    // check current user
    Log.debug('check current user');
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    Log.info('current user: $user');
    if (user == null) {
      launchApp(RegisterPage(), debug: debug);
    } else {
      launchApp(const _MainPage(), debug: debug);
    }
  }
}

void changeToMainPage(BuildContext context) {
  // prevent returning to the register page
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (builder) => const _MainPage()),
    (route) => false,
  );
  // // Navigator.pop(...)
  // closePage(context);
  // // showCupertinoDialog(...)
  // showPage(
  //   context: context,
  //   builder: (context) => const _MainPage(),
  // );
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
    // system check
    _SystemChecker().check(context);
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
  Widget build(BuildContext context) => DefaultTabController(
    length: 4,
    initialIndex: AppSettings().getValue('tab_index') ?? 0,
    child: Scaffold(
      body: const TabBarView(
        children: [
          ChatHistoryPage(),
          ContactListPage(),
          ServiceListPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: TabBar(
        labelColor: Styles.colors.activeTabColor,
        // unselectedLabelColor: Styles.colors.tabColor,
        tabs: [
          ChatHistoryPage.tab(),
          ContactListPage.tab(),
          ServiceListPage.tab(),
          SettingsPage.tab(),
        ],
        onTap: (index) => AppSettings().setValue('tab_index', index),
      ),
    ),
  );

  // @override
  // Widget build(BuildContext context) => CupertinoTabScaffold(
  //   backgroundColor: Styles.colors.scaffoldBackgroundColor,
  //   tabBar: CupertinoTabBar(
  //     backgroundColor: Styles.colors.appBardBackgroundColor,
  //     items: [
  //       ChatHistoryPage.barItem(),
  //       ContactListPage.barItem(),
  //       ServiceListPage.barItem(),
  //       SettingsPage.barItem(),
  //     ],
  //   ),
  //   tabBuilder: (context, index) {
  //     Widget page;
  //     if (index == 0) {
  //       page = const ChatHistoryPage();
  //     } else if (index == 1) {
  //       page = const ContactListPage();
  //     } else if (index == 2) {
  //       page = const ServiceListPage();
  //     } else {
  //       page = const SettingsPage();
  //     }
  //     return CupertinoTabView(
  //       builder: (context) {
  //         return page;
  //       },
  //     );
  //   },
  //   controller: CupertinoTabController(initialIndex: 2),
  // );

}


class _SystemChecker with Logging {
  factory _SystemChecker() => _instance;
  static final _SystemChecker _instance = _SystemChecker._internal();
  _SystemChecker._internal();

  bool _checked = false;

  Future<bool> check(BuildContext context) async {
    if (_checked) {
      logWarning('system checked');
      return false;
    } else {
      _checked = true;
    }
    // wait a while
    await Future.delayed(const Duration(seconds: 5));
    logWarning('system checking');
    //
    //  1. test speeds for all stations
    //
    logWarning('check station speeds');
    StationSpeeder speeder = StationSpeeder();
    await speeder.reload();
    await speeder.testAll();
    //
    //  2. checking for upgrade
    //
    if (context.mounted) {
      logWarning('check app update');
      NewestManager().checkUpdate(context);
    }
    //
    //  3. checking for avatar
    //
    var pnf = await _getAvatar();
    if (pnf != null) {
      Log.info('current user avatar: $pnf');
    } else if (context.mounted) {
      Alert.confirm(context, 'Pick Image',
        'Please choose your avatar'.tr,
        okAction: () => AccountPage.open(context),
      );
    }
    return true;
  }

}

Future<PortableNetworkFile?> _getAvatar() async {
  GlobalVariable shared = GlobalVariable();
  User? user = await shared.facebook.currentUser;
  assert(user != null, 'current user not found');
  Visa? visa = await user?.visa;
  assert(visa != null, 'visa not found: $user');
  return visa?.avatar;
}
