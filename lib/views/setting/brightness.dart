import 'package:dim_flutter/dim_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

class BrightnessSettingPage extends StatefulWidget {
  const BrightnessSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _BrightnessState();

}

class _BrightnessState extends State<BrightnessSettingPage> {

  late final _BrightnessListAdapter _adapter = _BrightnessListAdapter();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: Text('Brightness', style: Facade.of(context).styles.titleTextStyle),
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

  bool get isSelected => widget.order == _dataSource.getCurrentOrder();

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: brightnessIcon,
    title: brightnessName,
    trailing: selectedFlag,
    onTap: selectBrightness,
  );

  Icon get brightnessIcon {
    if (widget.order == 1) {
      return Icon(Styles.sunriseIcon,
        color: Facade.of(context).colors.secondaryTextColor,
      );
    } else if (widget.order == 2) {
      return Icon(Styles.sunsetIcon,
        color: Facade.of(context).colors.secondaryTextColor,
      );
    } else {
      return Icon(Styles.brightnessIcon,
        color: Facade.of(context).colors.secondaryTextColor,
      );
    }
  }

  Widget get brightnessName => Text(widget.name);

  Widget? get selectedFlag => !isSelected ? null : Icon(Styles.selectedIcon,
    color: Facade.of(context).colors.primaryTextColor,
  );

  void selectBrightness() {
    _dataSource.setBrightness(widget.order);
    setState(() {
    });
  }

}
