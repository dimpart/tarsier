import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;

import 'account.dart';
import 'account_export.dart';
import 'network.dart';


class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static BottomNavigationBarItem barItem() => const BottomNavigationBarItem(
    icon: Icon(Styles.settingsTabIcon),
    label: 'Settings',
  );

  @override
  Widget build(BuildContext context) {
    var colors = Facade.of(context).colors;
    var styles = Facade.of(context).styles;
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
            largeTitle: Text('Settings',
              style: styles.titleTextStyle,
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

  Widget _table(BuildContext context,
      {required Color backgroundColor, required Color backgroundColorActivated, required Color dividerColor,
        required Color primaryTextColor, required Color secondaryTextColor}) => Column(
    // mainAxisSize: MainAxisSize.min,
    children: [
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
            leading: Styles.exportAccountIcon, title: 'Export',
            additional: 'Mnemonic',
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showCupertinoDialog(
              context: context,
              builder: (context) => const ExportPage(),
            ),
          ),
        ],
      ),
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Relay Stations
          _listTile(
            leading: Styles.setNetworkIcon, title: 'Network',
            additional: 'Relay Stations',
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => showCupertinoDialog(
              context: context,
              builder: (context) => const NetworkSettingPage(),
            ),
          ),
        ],
      ),
      CupertinoListSection(
        backgroundColor: dividerColor,
        topMargin: 0,
        additionalDividerMargin: 32,
        children: [
          /// Source Codes
          _listTile(
            leading: Styles.setOpenSourceIcon, title: 'Source',
            additional: 'github.com/dimchat',
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => Config().termsURL.then((url) => Browser.open(context,
              url: 'https://github.com/dimpart/tarsier', title: 'Open Source',
            )),
          ),
          /// Privacy Policy
          _listTile(
            leading: Styles.setTermsIcon, title: 'Terms',
            additional: 'Privacy Policy',
            backgroundColor: backgroundColor,
            backgroundColorActivated: backgroundColorActivated,
            primaryTextColor: primaryTextColor,
            secondaryTextColor: secondaryTextColor,
            onTap: () => Config().termsURL.then((url) => Browser.open(context,
              url: url, title: 'Privacy Policy',
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
    return _listTile(
        leading: Styles.setAboutIcon, title: 'About',
        additional: 'Tarsier (v${client.versionName})',
        trailing: false,
        backgroundColor: backgroundColor,
        backgroundColorActivated: backgroundColorActivated,
        primaryTextColor: primaryTextColor,
        secondaryTextColor: secondaryTextColor,
        onTap: () => Config().aboutURL.then((url) => _showAbout(context, url, client)),
    );
  }

  void _showAbout(BuildContext context, String url, Client client) =>
      FrostedGlassPage.show(context, title: 'About Tarsier', body: RichText(
        text: TextSpan(
          text: 'Secure chat application,'
              ' powered by DIM, E2EE (End-to-End Encrypted) technology.\n'
              '\n'
              'Version: ${client.versionName} (build ${client.buildNumber})\n'
              'Website: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.normal,
            color: CupertinoColors.systemGrey,
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
                url: url, title: 'Decentralized Instant Messaging',
              ),
            ),
          ],
        ),
      ));

}

Widget _listTile({required IconData leading,
  required String title, required String additional, bool trailing = true,
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
      trailing: trailing ? const CupertinoListTileChevron() : null,
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
    backgroundColor: widget.backgroundColor,
    backgroundColorActivated: widget.backgroundColorActivated,
    padding: const EdgeInsets.all(16),
    leadingSize: 64,
    leading: _info?.getImage(width: 64, height: 64),
    title: Text('${_info?.name}', style: TextStyle(
      color: widget.primaryTextColor,
    )),
    subtitle: Text('${_info?.identifier}', style: TextStyle(
      color: widget.secondaryTextColor,
    )),
    trailing: const CupertinoListTileChevron(),
    onTap: () => AccountPage.open(context),
  );

}
