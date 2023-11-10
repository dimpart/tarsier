import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';


class BrightnessSettingPage extends StatefulWidget {
  const BrightnessSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _BrightnessState();

}

class _BrightnessState extends State<BrightnessSettingPage> {

  late final _BrightnessListAdapter _adapter = _BrightnessListAdapter();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: Text('Brightness'.tr, style: Styles.titleTextStyle),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );

}

class _BrightnessListAdapter with SectionAdapterMixin {

  late final BrightnessDataSource _dataSource = BrightnessDataSource();

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _BrightnessCell(_dataSource.getItem(indexPath.section, indexPath.item));

}

class _BrightnessCell extends StatefulWidget {
  const _BrightnessCell(this.item);

  final BrightnessItem item;

  int get order => item.order;
  String get name => item.name;

  @override
  State<StatefulWidget> createState() => _BrightnessCellState();

}

class _BrightnessCellState extends State<_BrightnessCell> {

  late final BrightnessDataSource _dataSource = BrightnessDataSource();

  bool get isSelected => widget.order == _dataSource.getCurrentBrightnessOrder();

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: brightnessIcon,
    title: brightnessName,
    trailing: selectedFlag,
    onTap: selectBrightness,
  );

  Icon get brightnessIcon => Icon(widget.order == BrightnessDataSource.kLight
      ? AppIcons.sunriseIcon : widget.order == BrightnessDataSource.kDark
      ? AppIcons.sunsetIcon
      : AppIcons.brightnessIcon,
    color: Styles.colors.secondaryTextColor,
  );

  Widget get brightnessName => Text(widget.name.tr,
    style: isSelected ? const TextStyle(color: CupertinoColors.systemRed) : null,
  );

  Widget? get selectedFlag => !isSelected ? null : Icon(AppIcons.selectedIcon,
    color: Styles.colors.primaryTextColor,
  );

  void selectBrightness() {
    _dataSource.setBrightness(widget.order);
    // closePage();
  }

}
