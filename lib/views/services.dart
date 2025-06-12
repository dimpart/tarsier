import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'service/base.dart';
import 'service/report.dart';


class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  static const String title = 'Services';
  static const IconData icon = AppIcons.servicesTabIcon;

  static BottomNavigationBarItem barItem() => BottomNavigationBarItem(
    icon: const Icon(icon),
    label: title.tr,
  );

  static Tab tab() => Tab(
    icon: const Icon(icon, size: 32),
    text: title.tr,
    // height: 64,
    iconMargin: EdgeInsets.zero,
  );

  @override
  State<StatefulWidget> createState() => _BotListState();
}

class _BotListState extends State<ServiceListPage> {
  _BotListState() {
    _adapter = _BotListAdapter();
  }

  late final _BotListAdapter _adapter;

  Future<void> _load() async {
    if (await _adapter.loadData()) {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: StatedTitleView.from(context, () => 'Service Bots'.tr),
      trailing: _reportButton(context, 'Service Bots'.tr),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

}

Widget _reportButton(BuildContext context, String title) {
  String text = 'Report Object: "@title"\n'
      '\n'
      'Reason: ...\n'
      '(Screenshots will be attached below)'.trParams({
    'title': title,
  });
  return CustomerService.reportButton(context, text);
}


//
//  Section Adapter
//

class _BotListAdapter with SectionAdapterMixin, Logging {

  final List<ServiceInfo> _services = [];

  Future<bool> loadData() async {
    Config config = Config();
    List array = config.services;
    logInfo('loaded ${array.length} services: $array');
    if (array.isEmpty) {
      return false;
    }
    _services.clear();
    _services.addAll(ServiceInfo.convert(array));
    return true;
  }

  @override
  bool shouldExistSectionFooter(int section) => true;

  @override
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'ServiceBotList::Description'.tr;
    return Container(
      color: Styles.colors.appBardBackgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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

  @override
  int numberOfItems(int section) => _services.length;

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) {
    if (indexPath.item >= _services.length) {
      logError('out of range: ${_services.length}, $indexPath');
      return const Text('');
    }
    var info = _services[indexPath.item];
    logDebug('show item: $info');
    return _ServiceTableCell(info);
  }

}

/// TableCell for Service Bots
class _ServiceTableCell extends StatefulWidget {
  const _ServiceTableCell(this.info);

  final ServiceInfo info;

  @override
  State<StatefulWidget> createState() => _ServiceTableCellState();

}

class _ServiceTableCellState extends State<_ServiceTableCell> {

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leadingSize: 72,
    leading: _leading(widget.info),
    title: _title(widget.info),
    subtitle: _subtitle(widget.info),
    additionalInfo: _additional(widget.info),
    trailing: const CupertinoListTileChevron(),
    onTap: () => widget.info.open(context),
  );

  Widget _leading(ServiceInfo info) {
    var pnf = info.icon;
    if (pnf == null) {
      return const SizedBox(
        width: 48,
        height: 48,
      );
    }
    Widget view = NetworkImageFactory().getImageView(pnf);
    // view = NetworkImageFactory().getImageView(pnf, fit: BoxFit.cover);
    // view = SizedBox.expand(child: view,);
    view = Container(
      width: 48,
      height: 48,
      color: CupertinoColors.white,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: view,
    );
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.elliptical(8, 8),
      ),
      child: view,
    );
  }

  Widget _title(ServiceInfo info) {
    var text = info.title;
    return Text(text);
  }

  Widget? _subtitle(ServiceInfo info) {
    var text = info.subtitle;
    return text == null ? null : Text(text);
  }

  Widget? _additional(ServiceInfo info) {
    var text = info.provider;
    return text == null ? null : Text(text);
  }

}
