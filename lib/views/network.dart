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
  _NetworkState() {
    _dataSource = _StationDataSource();
    _adapter = _StationListAdapter(dataSource: _dataSource);
  }

  late final _StationDataSource _dataSource;
  late final _StationListAdapter _adapter;
  bool _refreshing = false;

  Future<void> _reload() async {
    await _dataSource.reload();
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
    backgroundColor: Facade.of(context).colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Facade.of(context).colors.appBardBackgroundColor,
      middle: Text('Relay Stations', style: Facade.of(context).styles.titleTextStyle),
      trailing: IconButton(
          icon: const Icon(Styles.refreshStationsIcon, size: 16),
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
    // final ID gsp = ProviderDBI.kGSP;
    // shared.database.addStation('192.168.31.152', 9394, provider: gsp);
    // // shared.database.addStation('203.195.224.155', 9394, provider: gsp);
    // // shared.database.addStation('47.254.237.224', 9394, provider: gsp);
    // // shared.database.removeStation('203.195.224.155', 9394, provider: gsp);
    // shared.database.removeStations(provider: gsp);
  }
  Future<void> _refreshStations() async {
    // disable the refresh button to avoid refresh frequently
    setState(() {
      _refreshing = true;
    });
    // clear expired records
    GlobalVariable shared = GlobalVariable();
    await shared.database.removeExpiredSpeed(null);
    // test all stations
    int sections = _dataSource.getSectionCount();
    int items;
    StationInfo info;
    for (int sec = 0; sec < sections; ++sec) {
      items = _dataSource.getItemCount(sec);
      for (int idx = 0; idx < items; ++idx) {
        info = _dataSource.getItem(sec, idx);
        VelocityMeter.ping(info);
      }
    }
    // enable the refresh button after 5 seconds
    Future.delayed(const Duration(seconds: 5)).then((value) {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    });
  }
}

class _StationListAdapter with SectionAdapterMixin {
  _StationListAdapter({required _StationDataSource dataSource})
      : _dataSource = dataSource;

  final _StationDataSource _dataSource;

  @override
  int numberOfSections() =>
      _dataSource.getSectionCount();

  @override
  bool shouldExistSectionHeader(int section) => section > 0;  // hide 'gsp'

  @override
  bool shouldSectionHeaderStick(int section) => true;

  @override
  Widget getSectionHeader(BuildContext context, int section) => Container(
    color: Facade.of(context).colors.sectionHeaderBackgroundColor,
    padding: Styles.sectionHeaderPadding,
    child: Text(_dataSource.getSection(section),
      style: Facade.of(context).styles.sectionHeaderTextStyle,
    ),
  );

  @override
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _StationCell(_dataSource.getItem(indexPath.section, indexPath.item));

}

class _StationDataSource {

  List<ID> _sections = [];
  final Map<ID, List<StationInfo>> _items = {};

  static List<ID> _sortProviders(List<Pair<ID, int>> records) {
    // 1. sort records
    records.sort((a, b) {
      if (a.first.isBroadcast) {
        if (b.first.isBroadcast) {} else {
          return -1;
        }
      } else if (b.first.isBroadcast) {
        return 1;
      }
      // sort with chosen order
      return b.second - a.second;
    });
    List<ID> providers = [];
    for (var item in records) {
      providers.add(item.first);
    }
    // 2. set GSP to the front
    int pos = providers.indexOf(ProviderDBI.kGSP);
    if (pos < 0) {
      // gsp not exists, insert to the front
      providers.insert(0, ProviderDBI.kGSP);
    } else if (pos > 0) {
      // move to the front
      providers.removeAt(pos);
      providers.insert(0, ProviderDBI.kGSP);
    }
    return providers;
  }

  Future<void> reload() async {
    GlobalVariable shared = GlobalVariable();
    SessionDBI database = shared.sdb;
    var records = await database.getProviders();
    List<ID> providers = _sortProviders(records);
    for (ID pid in providers) {
      var stations = await database.getStations(provider: pid);
      _items[pid] = StationInfo.sortStations(await StationInfo.fromList(stations));
    }
    _sections = providers;
  }

  int getSectionCount() => _sections.length;

  String getSection(int sec) {
    ID pid = _sections[sec];
    return 'Provider ($pid)';
  }

  int getItemCount(int sec) {
    ID pid = _sections[sec];
    return _items[pid]?.length ?? 0;
  }

  StationInfo getItem(int sec, int idx) {
    ID pid = _sections[sec];
    return _items[pid]![idx];
  }
}

/// TableCell for Station
class _StationCell extends StatefulWidget {
  const _StationCell(this.info);

  final StationInfo info;

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

  bool _isCurrentStation(StationInfo info) {
    GlobalVariable shared = GlobalVariable();
    Station? current = shared.terminal.session?.station;
    if (current == null) {
      return false;
    } else {
      return current.port == info.port && current.host == info.host;
    }
  }

  String _getName(StationInfo info) {
    String? name = info.name;
    name ??= info.identifier?.toString();
    if (name != null && name.isNotEmpty) {
      return name;
    } else {
      return '${info.host}:${info.port}';
    }
  }
  Icon _getChosen(StationInfo info) {
    if (_isCurrentStation(info)) {
      return Icon(Styles.currentStationIcon, color: _getColor(info));
    } else if (info.chosen == 0) {
      return Icon(Styles.stationIcon, color: _getColor(info));
    } else {
      return Icon(Styles.chosenStationIcon, color: _getColor(info));
    }
  }
  String _getResult(StationInfo info) {
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
  Color _getColor(StationInfo info) {
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
