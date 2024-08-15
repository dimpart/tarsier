import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;

import 'setting/account.dart';
import 'setting/account_export.dart';
import 'setting/brightness.dart';
import 'setting/burn_after_reading.dart';
import 'setting/language.dart';
import 'setting/network.dart';
import 'setting/storage.dart';


class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static BottomNavigationBarItem barItem() => BottomNavigationBarItem(
    icon: const _SettingsIconView(icon: Icon(AppIcons.settingsTabIcon)),
    label: 'Settings'.tr,
  );

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> implements lnc.Observer {
  _SettingsPageState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kSettingUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kSettingUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kSettingUpdated) {
      Log.info('setting updated: $userInfo');
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackgroundColor,
      // A ScrollView that creates custom scroll effects using slivers.
      body: CustomScrollView(
        // A list of sliver widgets.
        slivers: <Widget>[
          CupertinoSliverNavigationBar(
            backgroundColor: colors.appBardBackgroundColor,
            // This title is visible in both collapsed and expanded states.
            // When the "middle" parameter is omitted, the widget provided
            // in the "largeTitle" parameter is used instead in the collapsed state.
            largeTitle: Text('Settings'.tr,
              style: Styles.titleTextStyle,
            ),
          ),
          // This widget fills the remaining space in the viewport.
          // Drag the scrollable area to collapse the CupertinoSliverNavigationBar.
          SliverFillRemaining(
            hasScrollBody: false,
            fillOverscroll: true,
            child: _table(context,
              backgroundColor: colors.sectionItemBackgroundColor,
              backgroundColorActivated: colors.sectionItemDividerColor,
              dividerColor: colors.sectionItemDividerColor,
              primaryTextColor: colors.primaryTextColor,
              secondaryTextColor: colors.tertiaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) => Column(
    // mainAxisSize: MainAxisSize.min,
    children: [
      //
      //  Account
      //
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Edit Profile
          _MyAccountSection(
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
          ),
          /// Export Private Key
          _listTile(
            leading: AppIcons.exportAccountIcon, title: 'Export'.tr,
            additional: 'Mnemonic'.tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const ExportPage(),
            ),
          ),
          /// Burn After Reading
          _listTile(
            leading: AppIcons.burnIcon, title: 'Burn After Reading'.tr,
            additional: BurnAfterReadingDataSource().getBurnAfterReadingDescription().tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const BurnAfterReadingPage(),
            ),
          ),
          /// Storage Management
          _listTile(
            leading: AppIcons.storageIcon, title: 'Storage'.tr,
            additional: 'Cache Files Management'.tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const CacheFileManagePage(),
            ),
          ),
        ],
      ),
      //
      //  Application
      //
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Language
          _listTile(
            leading: AppIcons.languageIcon, title: 'Language'.tr,
            additional: LanguageDataSource().getCurrentLanguageName().tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const LanguageSettingPage(),
            ),
          ),
          /// Brightness
          _listTile(
            leading: AppIcons.brightnessIcon, title: 'Brightness'.tr,
            additional: BrightnessDataSource().getCurrentBrightnessName().tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const BrightnessSettingPage(),
            ),
          ),
        ],
      ),
      //
      //  Station
      //
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Relay Stations
          _listTile(
            leading: AppIcons.setNetworkIcon, title: 'Network'.tr,
            additional: 'Relay Stations'.tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showPage(
              context: context,
              builder: (context) => const NetworkSettingPage(),
            ),
          ),
        ],
      ),
      //
      //  DIMP
      //
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Source Codes
          _listTile(
            leading: AppIcons.setOpenSourceIcon, title: 'Open Source'.tr,
            additional: 'github.com/dimchat',
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => Config().termsURL.then((url) => Browser.open(context,
              url: 'https://github.com/dimpart/tarsier',
            )),
          ),
          /// Privacy Policy
          _listTile(
            leading: AppIcons.setTermsIcon, title: 'Terms'.tr,
            additional: 'Privacy Policy'.tr,
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => Config().termsURL.then((url) => Browser.open(context,
              url: url,
            )),
          ),
          /// About Tarsier
          _about(context, backgroundColor: backgroundColor, backgroundColorActivated: backgroundColorActivated,
              primaryTextColor: primaryTextColor, secondaryTextColor: secondaryTextColor),
        ],
      ),
    ],
  );

  Widget _about(BuildContext context,
      {required Color backgroundColor, required Color backgroundColorActivated,
        required Color primaryTextColor, required Color secondaryTextColor}) {
    GlobalVariable shared = GlobalVariable();
    Client client = shared.terminal;
    Newest? newest = Config().newest;
    bool canUpgrade = newest != null && newest.canUpgrade(client);
    return _listTile(
        leading: AppIcons.setAboutIcon, title: 'About'.tr,
        additional: 'Tarsier (v${client.versionName})',
        trailing: canUpgrade ? Text('NEW'.tr, style: const TextStyle(
          color: CupertinoColors.white,
          backgroundColor: CupertinoColors.systemRed,
          decoration: TextDecoration.none,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),) : Container(),
        backgroundColor: backgroundColor,
        backgroundColorActivated: backgroundColorActivated,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        onTap: () => Config().aboutURL.then((url) => _showAbout(context, url, client)),
    );
  }

  void _showAbout(BuildContext context, String url, Client client) {
    Newest? newest = Config().newest;
    return FrostedGlassPage.show(context, title: 'About Tarsier', body: RichText(
      text: TextSpan(
        text: 'Secure chat application powered by DIM,'
            ' E2EE (End-to-End Encrypted) technology.\n'
            '\n'
            'Author: Albert Moky\n'
            'Version: ${client.versionName} (build ${client.buildNumber})    ',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: Styles.colors.secondaryTextColor,
          decoration: TextDecoration.none,
        ),
        children: [
          if (newest != null && newest.canUpgrade(client))
          _updateButton(context, newest),
          _homepage(context, url),
        ],
      ),
    ));
  }

  TextSpan _updateButton(BuildContext context, Newest newest) => TextSpan(
    text: 'UPDATE'.tr,
    style: const TextStyle(
      color: CupertinoColors.systemRed,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.double,
      fontWeight: FontWeight.bold,
    ),
    recognizer: TapGestureRecognizer()..onTap = () => Browser.launch(context,
      url: newest.url,
    ),
  );

  TextSpan _homepage(BuildContext context, String url) => TextSpan(
    text: '\nWebsite: ',
    style: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: Styles.colors.secondaryTextColor,
      decoration: TextDecoration.none,
    ),
    children: [
      TextSpan(
        text: url,
        style: const TextStyle(
          color: CupertinoColors.activeBlue,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()..onTap = () => Browser.open(context,
          url: url,
        ),
      ),
    ],
  );

}

Widget _listTile({required IconData leading,
  required String title, required String additional, Widget? trailing,
  required Color backgroundColor, required Color backgroundColorActivated,
  required Color primaryTextColor, required Color secondaryTextColor,
  required VoidCallback onTap}) =>
    CupertinoListTile(
      backgroundColor: backgroundColor,
      backgroundColorActivated: backgroundColorActivated,
      padding: Styles.settingsSectionItemPadding,
      leading: Icon(leading, color: primaryTextColor),
      title: Text(title, style: TextStyle(color: primaryTextColor)),
      additionalInfo: Text(additional, style: TextStyle(color: secondaryTextColor)),
      trailing: trailing ?? const CupertinoListTileChevron(),
      onTap: onTap,
    );

class _MyAccountSection extends StatefulWidget {
  const _MyAccountSection({
    required this.backgroundColor, required this.backgroundColorActivated,
    required this.primaryTextColor, required this.secondaryTextColor});

  final Color backgroundColor;
  final Color backgroundColorActivated;
  final Color primaryTextColor;
  final Color secondaryTextColor;

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
    info ??= ContactInfo.fromID(user.identifier);
    await info?.reloadData();
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
    backgroundColor: widget.backgroundColor,
    backgroundColorActivated: widget.backgroundColorActivated,
    padding: const EdgeInsets.all(16),
    leadingSize: 64,
    leading: _info?.getImage(width: 64, height: 64),
    title: Text('${_info?.title}', style: TextStyle(
      color: widget.primaryTextColor,
    )),
    subtitle: Text('${_info?.identifier}', style: TextStyle(
      color: widget.secondaryTextColor,
    )),
    trailing: const CupertinoListTileChevron(),
    onTap: () => AccountPage.open(context),
  );

}


///
///   Settings Tab Item
///
class _SettingsIconView extends StatefulWidget {
  const _SettingsIconView({required this.icon});

  final Widget icon;

  @override
  State<StatefulWidget> createState() => _SettingsIconState();

}

class _SettingsIconState extends State<_SettingsIconView> implements lnc.Observer {
  _SettingsIconState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kConfigUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kConfigUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    if (name == NotificationNames.kConfigUpdated) {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    GlobalVariable shared = GlobalVariable();
    Client client = shared.terminal;
    Newest? newest = Config().newest;
    int count = newest != null && newest.canUpgrade(client) ? 1 : 0;
    Log.warning('greeting count: $count');
    return IconView.fromSpot(widget.icon, count);
  }

}
