import 'package:dim_flutter/dim_flutter.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';


class LanguageSettingPage extends StatefulWidget {
  const LanguageSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _LanguageState();

}

class _LanguageState extends State<LanguageSettingPage> {

  late final _LanguageListAdapter _adapter = _LanguageListAdapter();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: Text('Language'.tr, style: Styles.titleTextStyle),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );

}

class _LanguageListAdapter with SectionAdapterMixin {

  late final LanguageDataSource _dataSource = LanguageDataSource();

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _LanguageCell(_dataSource.getItem(indexPath.section, indexPath.item));

}

class _LanguageCell extends StatefulWidget {
  const _LanguageCell(this.item);

  final LanguageItem item;

  String get code => item.code;
  String get name => item.name;

  @override
  State<StatefulWidget> createState() => _LanguageCellState();

}

class _LanguageCellState extends State<_LanguageCell> {

  late final LanguageDataSource _dataSource = LanguageDataSource();

  bool get isSelected => widget.code == _dataSource.getCurrentLanguageCode();

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: languageIcon,
    title: languageName,
    trailing: selectedFlag,
    onTap: selectLanguage,
  );

  Icon? get languageIcon {
    // TODO:
    return null;
  }

  Widget get languageName => Text(widget.name.tr,
    style: isSelected ? const TextStyle(color: CupertinoColors.systemRed) : null,
  );

  Widget? get selectedFlag => !isSelected ? null : Icon(AppIcons.selectedIcon,
    color: Styles.colors.primaryTextColor,
  );

  void selectLanguage() {
    _dataSource.setLanguage(widget.code);
    // closePage();
  }

}
