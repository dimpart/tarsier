import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'root.dart';
import 'views/register.dart';


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
  // Launch the app
  launchApp(const _RootRouterPage(), debug: debug);
}


class _RootRouterPage extends StatefulWidget {
  const _RootRouterPage();

  @override
  State<_RootRouterPage> createState() => _RootRouterPageState();
}

class _RootRouterPageState extends State<_RootRouterPage> with Logging {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAppRoute(context));
  }

  Future<void> _handleAppRoute(BuildContext context) async {
    User? user;
    // Check permission: Storage
    bool permitted = await PermissionChecker().checkDatabasePermissions();
    if (permitted) {
      // check current user
      logDebug('check current user');
      GlobalVariable shared = GlobalVariable();
      user = await shared.facebook.currentUser;
      logInfo('current user: $user');
    }
    // Launch the app
    if (!context.mounted) {
      logError('context error: $context');
    } else if (user != null) {
      logInfo('open main page');
      changeToMainPage(context);
    } else {
      logInfo('open register page');
      // changeToRegisterPage
      changeRootPage(context, (context) => RegisterPage());
    }

  }

  @override
  Widget build(BuildContext context) {
    Widget view = const Center(child: CircularProgressIndicator());
    view = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _logo(),
        view,
      ],
    );
    return MaterialApp(
      home: Scaffold(
        body: view,
        backgroundColor: Styles.colors.logoBackgroundColor,
      ),
    );
  }

  Widget _logo() => SizedBox(
    width: 60,
    height: 60,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eye(),
        const SizedBox(width: 6,),
        _eye(),
      ],
    ),
  );
  Widget _eye() => const Icon(Icons.panorama_fish_eye,
    size: 18,
    color: Colors.white,
  );

}
