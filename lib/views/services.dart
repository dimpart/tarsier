import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';

import 'chat/chat_box.dart';
import 'service/lives.dart';
import 'service/sites.dart';


class ServiceListPage extends StatefulWidget {
  const ServiceListPage({super.key});

  static final String title = 'Services'.tr;
  static const IconData icon = AppIcons.servicesTabIcon;

  static BottomNavigationBarItem barItem() => BottomNavigationBarItem(
    icon: const Icon(icon),
    label: title,
  );

  static Tab tab() => Tab(
    icon: const Icon(icon, size: 32),
    text: title,
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
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );
}

class _BotListAdapter with SectionAdapterMixin, Logging {

  final List<Map> _services = [];

  Future<bool> loadData() async {
    List array = await Config().services;
    logInfo('loaded ${array.length} services: $array');
    if (array.isEmpty) {
      return false;
    }
    _services.clear();
    for (var item in array) {
      if (item is Map) {
        var st = item['type'];
        if (st == 'ChatBox' || st == 'ChatBot') {
          _services.add(item);
        } else if (st == 'LiveSources') {
          _services.add(item);
        } else if (st == 'WebSites') {
          _services.add(item);
        } else {
          logWarning('ignore service item: $item');
        }
      } else {
        logError('unknown service item: $item');
      }
    }
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
      Log.error('out of range: ${_services.length}, $indexPath');
      return const Text('');
    }
    var info = _services[indexPath.item];
    Log.debug('show item: $info');
    return _ServiceTableCell(info);
  }

}

/// TableCell for Service Bots
class _ServiceTableCell extends StatefulWidget {
  const _ServiceTableCell(this.info);

  final Map info;

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
    trailing: const CupertinoListTileChevron(),
    onTap: () => _openService(context, widget.info),
  );

  Widget _leading(Map info) {
    String? icon = info['icon'];
    PortableNetworkFile? pnf = icon == null ? null : PortableNetworkFile.parse({
      "URL": icon,
    });
    Widget? view;
    if (pnf != null) {
      view = NetworkImageFactory().getImageView(pnf);
    }
    view = Container(
      width: 48,
      height: 48,
      color: CupertinoColors.white,
      padding: const EdgeInsets.all(4),
      child: view,
    );
    return ClipRRect(
      borderRadius: const BorderRadius.all(
        Radius.elliptical(8, 8),
      ),
      child: view,
    );
  }

  Widget _title(Map info) {
    String? title = info['title'];
    title ??= info['name'];
    return Text('$title');
  }

  Widget? _subtitle(Map info) {
    String? text = info['subtitle'];
    return text == null ? null : Text(text);
  }

}

bool _openService(BuildContext ctx, Map info) {
  Log.warning('tap: $info');
  // check service bot
  ID? bot = ID.parse(info['ID']);
  if (bot == null) {
    return false;
  }
  ContactInfo? contact = ContactInfo.fromID(bot);
  if (contact == null) {
    return false;
  }
  // check service type
  var st = info['type'];
  if (st == 'ChatBox' || st == 'ChatBot') {
    // chat box
    ChatBox.open(ctx, contact);
    return true;
  } else if (st == 'LiveSources') {
    // live source list
    String? title = info['title'];
    if (title == null || title.isEmpty) {
      title = 'Live Stream Sources';
    }
    LiveSourceListPage.open(ctx, contact, title);
    return true;
  } else if (st == 'WebSites') {
    // live source list
    String? title = info['title'];
    if (title == null || title.isEmpty) {
      title = 'Index Page';
    }
    WebSitePage.open(ctx, contact, title);
    return true;
  }
  Log.error('unknown service type: $st');
  return false;
}
