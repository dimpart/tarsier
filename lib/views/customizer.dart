import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'account.dart';
import 'account_export.dart';
import 'network.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static BottomNavigationBarItem barItem() {
    return const BottomNavigationBarItem(
      icon: Icon(Styles.settingsTabIcon),
      label: 'Settings',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: Styles.backgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      child: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          const CupertinoSliverNavigationBar(
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text('Settings'),
            border: Styles.navigationBarBorder,
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: Column(
              // mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    _myAccount(context),
                    _exportAccount(context),
                  ],
                ),
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    _network(context),
                  ],
                ),
                CupertinoListSection(
                  topMargin: 0,
                  additionalDividerMargin: 32,
                  children: [
                    // _whitePaper(context),
                    _source(context),
                    _term(context),
                    _about2(context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _myAccount(BuildContext context) => _MyAccountSection();

  Widget _exportAccount(BuildContext context) => CupertinoListTile(
    padding: Styles.settingsSectionItemPadding,
    leading: const Icon(Styles.exportAccountIcon),
    title: const Text('Export'),
    additionalInfo: const Text('Mnemonic'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => showCupertinoDialog(
      context: context,
      builder: (context) => const ExportPage(),
    ),
  );

  Widget _network(BuildContext context) => CupertinoListTile(
    padding: Styles.settingsSectionItemPadding,
    leading: const Icon(Styles.setNetworkIcon),
    title: const Text('Network'),
    additionalInfo: const Text('Relay Stations'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => showCupertinoDialog(
      context: context,
      builder: (context) => const NetworkSettingPage(),
    ),
  );

  // Widget _whitePaper(BuildContext context) => CupertinoListTile(
  //   padding: Styles.settingsSectionItemPadding,
  //   leading: const Icon(Styles.setWhitePaperIcon),
  //   title: const Text('White Paper'),
  //   additionalInfo: const Text('zh-CN'),
  //   trailing: const CupertinoListTileChevron(),
  //   onTap: () => Config().termsURL.then((url) => Browser.open(context,
  //     url: 'https://github.com/moky/DIMP/blob/master/zh-CN/TechnicalWhitePaper.md',
  //     title: 'Technical White Paper (zh-CN)',
  //   )),
  // );

  Widget _source(BuildContext context) => CupertinoListTile(
    padding: Styles.settingsSectionItemPadding,
    leading: const Icon(Styles.setOpenSourceIcon),
    title: const Text('Source'),
    additionalInfo: const Text('github.com/dimchat'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => Config().termsURL.then((url) => Browser.open(context,
      url: 'https://github.com/dimgame/tarsier',
      title: 'Open Source',
    )),
  );

  Widget _term(BuildContext context) => CupertinoListTile(
    padding: Styles.settingsSectionItemPadding,
    leading: const Icon(Styles.setTermsIcon),
    title: const Text('Terms'),
    additionalInfo: const Text('Privacy Policy'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => Config().termsURL.then((url) => Browser.open(context,
      url: url,
      title: 'Privacy Policy',
    )),
  );

  // Widget _about(BuildContext context) => CupertinoListTile(
  //   padding: Styles.settingsSectionItemPadding,
  //   leading: const Icon(Styles.setAboutIcon),
  //   title: const Text('About'),
  //   additionalInfo: const Text('DIM'),
  //   trailing: const CupertinoListTileChevron(),
  //   onTap: () => Config().aboutURL.then((url) => Browser.open(context,
  //     url: url,
  //     title: 'Decentralized Instant Messaging',
  //   )),
  // );

  Widget _about2(BuildContext context) => CupertinoListTile(
    padding: Styles.settingsSectionItemPadding,
    leading: const Icon(Styles.setAboutIcon),
    title: const Text('About'),
    additionalInfo: const Text('Tarsier (v1.0)'),
    onTap: () => Config().aboutURL.then((url) => GaussianInfo.show(context,
        'About Tarsier',
        'Secure chat application,'
            ' powered by E2EE (End-to-End Encryption) technology.\n'
            '\n'
            // 'Author: Albert Moky\n'
            'Version: 1.0 (build 10001)\n'
            'Website: $url',
    ),
    ),
  );

}

class _MyAccountSection extends StatefulWidget {

  @override
  State<StatefulWidget> createState() => _MyAccountState();

}

class _MyAccountState extends State<_MyAccountSection> implements lnc.Observer {
  _MyAccountState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kDocumentUpdated);
  }

  ContactInfo? _info;

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kDocumentUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? info = notification.userInfo;
    assert(name == NotificationNames.kDocumentUpdated, 'notification error: $notification');
    ID? identifier = info?['ID'];
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (identifier == null) {
      Log.error('notification error: $notification');
    } else if (identifier == user?.identifier) {
      await _reload();
    }
  }

  Future<void> _reload() async {
    GlobalVariable shared = GlobalVariable();
    User? user = await shared.facebook.currentUser;
    if (user == null) {
      Log.error('failed to get current user');
      return;
    }
    ContactInfo? info = _info;
    info ??= ContactInfo(user.identifier);
    await info.reloadData();
    if (mounted) {
      setState(() {
        _info = info;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoListTile(
    padding: const EdgeInsets.all(16),
    leadingSize: 64,
    leading: _info?.getImage(width: 64, height: 64),
    title: Text('${_info?.name}'),
    subtitle: Text('${_info?.identifier}'),
    trailing: const CupertinoListTileChevron(),
    onTap: () => AccountPage.open(context),
  );

}
