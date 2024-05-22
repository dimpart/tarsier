import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;


class CacheFileManagePage extends StatefulWidget {
  const CacheFileManagePage({super.key});

  @override
  State<StatefulWidget> createState() => _CacheFileState();

}

class _CacheFileState extends State<CacheFileManagePage> implements lnc.Observer {
  _CacheFileState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kCacheFileFound);
    nc.addObserver(this, NotificationNames.kCacheScanFinished);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kCacheScanFinished);
    nc.removeObserver(this, NotificationNames.kCacheFileFound);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var colors = Styles.colors;
    return Scaffold(
      backgroundColor: colors.scaffoldBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: colors.appBardBackgroundColor,
        middle: Text('Cache Files Management'.tr, style: Styles.titleTextStyle),
      ),
      body: buildScrollView(
        enableScrollbar: true,
        child: _table(context,
          backgroundColor: colors.sectionItemBackgroundColor,
          backgroundColorActivated: colors.sectionItemDividerColor,
          dividerColor: colors.sectionItemDividerColor,
          primaryTextColor: colors.primaryTextColor,
          secondaryTextColor: colors.tertiaryTextColor,
        ),
      ),
    );
  }

  Widget _table(BuildContext context, {
    required Color backgroundColor,
    required Color backgroundColorActivated,
    required Color dividerColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    var man = CacheFileManager();
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ///
          /// Total Data
          ///
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Cached Data'.tr),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(man.summary, style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),),
                  Container(
                    padding: const EdgeInsets.only(right: 16),
                    child: _refreshButton(),
                  ),
                ],
              )
            ],
          ),
          ///
          /// Cache Data
          ///
          _sectionHeader(AppIcons.cacheIcon, 'Cache Files'.tr, primaryTextColor),
          CupertinoListSection(
            backgroundColor: dividerColor,
            topMargin: 0,
            additionalDividerMargin: 0,
            footer: _sectionFooter('CacheFiles::Description'.tr, secondaryTextColor,),
            children: [
              _listTile(
                title: 'Database'.tr,
                subtitle: man.dbSummary,
                backgroundColor: backgroundColor,
                backgroundColorActivated: backgroundColorActivated,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
              ),
              _listTile(
                title: 'Avatars'.tr,
                subtitle: man.avatarSummary,
                backgroundColor: backgroundColor,
                backgroundColorActivated: backgroundColorActivated,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                buttonColor: Styles.colors.criticalButtonColor,
                onTap: () => Alert.confirm(context, 'Confirm Delete',
                  'Sure to clear all avatar images?'.tr,
                  okAction: () => man.cleanAvatars(),
                ),
              ),
              _listTile(
                title: 'Message Files'.tr,
                subtitle: man.cacheSummary,
                backgroundColor: backgroundColor,
                backgroundColorActivated: backgroundColorActivated,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                buttonColor: Styles.colors.criticalButtonColor,
                onTap: () => Alert.confirm(context, 'Confirm Delete',
                  'Sure to clear all message files?'.tr,
                  okAction: () => man.cleanCaches(),
                ),
              ),
            ],
          ),
          ///
          /// Temporary Data
          ///
          _sectionHeader(AppIcons.temporaryIcon, 'Temporary Files'.tr, primaryTextColor),
          CupertinoListSection(
            backgroundColor: dividerColor,
            topMargin: 0,
            additionalDividerMargin: 0,
            footer: _sectionFooter('TemporaryFiles::Description'.tr, secondaryTextColor,),
            children: [
              _listTile(
                title: 'Upload Directory'.tr,
                subtitle: man.uploadSummary,
                backgroundColor: backgroundColor,
                backgroundColorActivated: backgroundColorActivated,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                buttonColor: Styles.colors.normalButtonColor,
                onTap: () => Alert.confirm(context, 'Confirm Delete',
                  'Sure to clear these temporary files?'.tr,
                  okAction: () => man.cleanUploads(),
                ),
              ),
              _listTile(
                title: 'Download Directory'.tr,
                subtitle: man.downloadSummary,
                backgroundColor: backgroundColor,
                backgroundColorActivated: backgroundColorActivated,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                buttonColor: Styles.colors.normalButtonColor,
                onTap: () => Alert.confirm(context, 'Confirm Delete',
                  'Sure to clear these temporary files?'.tr,
                  okAction: () => man.cleanDownloads(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Row(
      children: [
        Icon(icon, color: color, size: 16,),
        const SizedBox(width: 8,),
        Text(text),
      ],
    ),
  );

  Widget _sectionFooter(String text, Color color) => Container(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(text,
      style: TextStyle(color: color),
    ),
  );

  Widget _refreshButton() {
    var man = CacheFileManager();
    var refreshing = man.refreshing;
    if (refreshing) {
      return const CupertinoActivityIndicator();
    }
    return OutlinedButton(
      onPressed: () {
        man.scanAll();
        setState(() {});
      },
      child: Text('Scan'.tr),
    );
  }

}

Widget _listTile({
  required String title,
  required String subtitle,
  required Color backgroundColor, required Color backgroundColorActivated,
  required Color primaryTextColor, required Color secondaryTextColor,
  Color? buttonColor,
  VoidCallback? onTap,
}) => CupertinoListTile(
  backgroundColor: backgroundColor,
  backgroundColorActivated: backgroundColorActivated,
  padding: Styles.settingsSectionItemPadding,
  title: Text(title, style: TextStyle(color: primaryTextColor)),
  subtitle: Text(subtitle, style: TextStyle(color: secondaryTextColor)),
  trailing: onTap == null ? null : OutlinedButton(
    onPressed: onTap,
    child: Text('Clear'.tr, style: buttonColor == null ? null : TextStyle(
      color: buttonColor,
    ),),
  ),
);
