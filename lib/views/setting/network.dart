import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/lnc.dart' as lnc;


class NetworkSettingPage extends StatefulWidget {
  const NetworkSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _NetworkState();

}

class _NetworkState extends State<NetworkSettingPage> {
  _NetworkState();

  late final _StationListAdapter _adapter = _StationListAdapter();
  bool _refreshing = false;

  Future<void> _reload() async {
    await _adapter.reload();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    GlobalVariable shared = GlobalVariable();
    shared.terminal.reconnect();
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBardBackgroundColor,
      middle: Text('Relay Stations'.tr, style: Styles.titleTextStyle),
      trailing: IconButton(
          icon: const Icon(AppIcons.refreshStationsIcon, size: 16),
          onPressed: _refreshing ? null : () => _confirmRefresh(context)),
    ),
    body: SectionListView.builder(
      adapter: _adapter,
    ),
  );

  void _confirmRefresh(BuildContext context) {
    Alert.confirm(context,
        'Refresh Stations',
        'The fastest station will be connected automatically next time.',
        okAction: _refreshStations
    );
    // // TEST:
    // GlobalVariable shared = GlobalVariable();
    // final ID gsp = ProviderInfo.kGSP;
    // shared.database.addStation('192.168.31.152', 9394, provider: gsp);
    // // shared.database.addStation('203.195.224.155', 9394, provider: gsp);
    // // shared.database.addStation('47.254.237.224', 9394, provider: gsp);
    // // shared.database.removeStation('203.195.224.155', 9394, provider: gsp);
    // shared.database.removeStations(provider: gsp);
  }
  void _refreshStations() {
    // disable the refresh button to avoid refresh frequently
    if (mounted) {
      setState(() {
        _refreshing = true;
      });
    }
    // enable the refresh button after 5 seconds
    Future.delayed(const Duration(seconds: 5)).then((value) {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    });
    // test all stations
    StationSpeeder speeder = StationSpeeder();
    speeder.testAll();
  }
}

class _StationListAdapter with SectionAdapterMixin {
  _StationListAdapter();

  late final StationSpeeder _dataSource = StationSpeeder();

  Future<void> reload() async => await _dataSource.reload();

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => section > 0;  // hide 'gsp'

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Styles.colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text('Provider (${_dataSource.getSection(section)})',
      style: Styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _StationCell(_dataSource.getItem(indexPath.section, indexPath.item));

}

/// TableCell for Station
class _StationCell extends StatefulWidget {
  const _StationCell(this.info);

  final NeighborInfo info;

  @override
  State<StatefulWidget> createState() => _StationCellState();

}

class _StationCellState extends State<_StationCell> implements lnc.Observer {
  _StationCellState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kStationSpeedUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kStationSpeedUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kStationSpeedUpdated) {
      VelocityMeter meter = userInfo!['meter'];
      if (meter.port != widget.info.port || meter.host != widget.info.host) {
        return;
      }
      String state = userInfo['state'];
      Log.debug('test state: $state, $meter');
      if (state == 'start') {
        Log.debug('start to test station speed: $meter');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = 0;
          });
        }
      } else if (state == 'connected') {
        Log.debug('connected to station: $meter');
      } else if (state == 'failed' || meter.responseTime == null) {
        Log.error('speed task failed: $meter, $state');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = -1;
          });
        }
      } else {
        assert(state == 'finished', 'meta state error: $userInfo');
        Log.debug('refreshing $meter -> ${widget.info}, $state');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = meter.responseTime;
          });
        }
      }
    } else {
      Log.error('notification error: $notification');
    }
  }

  Future<void> _reload() async {
    await widget.info.reloadData();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leading: _getChosen(widget.info),
    title: Text(_getName(widget.info)),
    subtitle: Text('${widget.info.host}:${widget.info.port}'),
    trailing: Text(_getResult(widget.info),
      style: TextStyle(
        fontSize: 10,
        color: _getColor(widget.info),
      ),
    ),
  );

  bool _isCurrentStation(NeighborInfo info) {
    GlobalVariable shared = GlobalVariable();
    Station? current = shared.terminal.session?.station;
    if (current == null) {
      return false;
    } else {
      return current.port == info.port && current.host == info.host;
    }
  }

  String _getName(NeighborInfo info) {
    String? name = info.name;
    name ??= info.identifier?.toString();
    if (name != null && name.isNotEmpty) {
      return name;
    } else {
      return '${info.host}:${info.port}';
    }
  }
  Icon _getChosen(NeighborInfo info) {
    if (_isCurrentStation(info)) {
      return Icon(AppIcons.currentStationIcon, color: _getColor(info));
    } else if (info.chosen == 0) {
      return Icon(AppIcons.stationIcon, color: _getColor(info));
    } else {
      return Icon(AppIcons.chosenStationIcon, color: _getColor(info));
    }
  }
  String _getResult(NeighborInfo info) {
    double? responseTime = info.responseTime;
    if (responseTime == null) {
      return 'unknown';
    } else if (responseTime == 0) {
      return 'testing';
    } else if (responseTime < 0) {
      return 'error';
    }
    return '${responseTime.toStringAsFixed(3)}"';
  }
  Color _getColor(NeighborInfo info) {
    double? responseTime = info.responseTime;
    if (responseTime == null) {
      return CupertinoColors.systemGrey;
    } else if (responseTime == 0) {
      return CupertinoColors.systemBlue;
    } else if (responseTime < 0) {
      return CupertinoColors.systemRed;
    } else if (responseTime > 15) {
      return CupertinoColors.systemYellow;
    }
    return CupertinoColors.systemGreen;
  }

}
