import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;


class BurnAfterReadingPage extends StatefulWidget {
  const BurnAfterReadingPage({super.key});

  @override
  State<StatefulWidget> createState() => _BurnState();

}

class _BurnState extends State<BurnAfterReadingPage> implements lnc.Observer {
  _BurnState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kSettingUpdated);
  }

  late final _BurnListAdapter _adapter = _BurnListAdapter();

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
      int? duration = userInfo?['duration'];
      Log.info('setting updated, duration: $duration');
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: Text('Burn After Reading'.tr, style: Styles.titleTextStyle),
    ),
    body: buildSectionListView(
      enableScrollbar: false,
      adapter: _adapter,
    ),
  );

}

class _BurnListAdapter with SectionAdapterMixin {

  late final BurnAfterReadingDataSource _dataSource = BurnAfterReadingDataSource();

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _BurnCell(_dataSource.getItem(indexPath.section, indexPath.item));

  @override
  bool shouldExistSectionFooter(int section) => section + 1 == numberOfSections();

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'BurnAfterReading::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(prompt,
            style: Styles.sectionFooterTextStyle,
          )),
        ],
      ),
    );
  }

}

class _BurnCell extends StatefulWidget {
  const _BurnCell(this.item);

  final BurnAfterReadingItem item;

  int get duration => item.duration;
  String get description => item.description;

  @override
  State<StatefulWidget> createState() => _BurnCellState();

}

class _BurnCellState extends State<_BurnCell> {

  late final BurnAfterReadingDataSource _dataSource = BurnAfterReadingDataSource();

  bool get isSelected => widget.duration == _dataSource.getBurnAfterReading();

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leadingSize: 28,
    leading: SizedBox(width: 48, height: 48, child: leadingIcon,),
    title: description,
    trailing: selectedFlag,
    onTap: selectDuration,
  );

  Icon? get leadingIcon {
    // TODO:
    return null;
  }

  Widget get description => Text(widget.description.tr,
    style: isSelected ? const TextStyle(color: CupertinoColors.systemRed) : null,
  );

  Widget? get selectedFlag => !isSelected ? null : Icon(AppIcons.selectedIcon,
    color: Styles.colors.primaryTextColor,
  );

  void selectDuration() {
    int duration = widget.duration;
    _dataSource.setBurnAfterReading(duration);
    // closePage();
    var nc = lnc.NotificationCenter();
    nc.postNotification(NotificationNames.kSettingUpdated, this, {
      'duration': duration,
    });
  }

}
