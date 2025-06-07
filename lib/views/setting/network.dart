import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';
import 'package:lnc/notification.dart' as lnc;


class NetworkSettingPage extends StatefulWidget {
  const NetworkSettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _NetworkState();

}

class _NetworkState extends State<NetworkSettingPage> with Logging implements lnc.Observer {
  _NetworkState() {
    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kStationsUpdated);
  }

  late final _StationListAdapter _adapter = _StationListAdapter();
  bool _refreshing = false;

  final TextEditingController _hostTextController = TextEditingController();
  final TextEditingController _portTextController = TextEditingController();

  final FocusNode _hostFocusNode = FocusNode();
  final FocusNode _portFocusNode = FocusNode();

  Future<void> _reload() async {
    await _adapter.reload();
    if (mounted) {
      setState(() {
      });
    }
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kStationsUpdated);
    _hostTextController.dispose();
    _portTextController.dispose();
    _hostFocusNode.dispose();
    _portFocusNode.dispose();
    GlobalVariable shared = GlobalVariable();
    shared.terminal.reconnect();
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kStationsUpdated) {
      String? action = userInfo?['action'];
      if (action == 'add' || action == 'remove' || action == 'removeAll') {
        await _reload();
      }
    } else {
      logError('notification error: $notification');
    }
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
          icon: const Icon(AppIcons.refreshIcon, size: 16),
          onPressed: _refreshing ? null : () => _confirmRefresh(context)),
    ),
    body: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          flex: 1,
          child: buildSectionListView(
            enableScrollbar: true,
            adapter: _adapter,
          ),
        ),
        Container(
          color: Styles.colors.inputTrayBackgroundColor,
          padding: const EdgeInsets.all(16),
          child: _inputTray(context),
        ),
      ],
    )
  );

  Widget _inputTray(BuildContext context) {
    //
    //  host input
    //
    Widget hostInput = CupertinoTextField(
      minLines: 1,
      maxLines: 1,
      prefix: const Text(' Host'),
      prefixMode: OverlayVisibilityMode.notEditing,
      placeholder: '12.34.56.78',
      decoration: Styles.textFieldDecoration,
      style: Styles.textFieldStyle,
      keyboardType: TextInputType.text,
      controller: _hostTextController,
      focusNode: _hostFocusNode,
      onTapOutside: (event) => _hostFocusNode.unfocus(),
    );
    hostInput = Container(
      width: 200,
      padding: const EdgeInsets.only(left: 12, right: 2),
      child: hostInput,
    );
    //
    //  port input
    //
    Widget portInput = CupertinoTextField(
      minLines: 1,
      maxLines: 1,
      prefix: const Text(' Port'),
      prefixMode: OverlayVisibilityMode.notEditing,
      placeholder: '9394',
      decoration: Styles.textFieldDecoration,
      style: Styles.textFieldStyle,
      keyboardType: TextInputType.number,
      controller: _portTextController,
      focusNode: _portFocusNode,
      onTapOutside: (event) => _portFocusNode.unfocus(),
    );
    portInput = Container(
      width: 112,
      padding: const EdgeInsets.only(left: 2, right: 12),
      child: portInput,
    );
    //
    //  add button
    //
    Widget addButton = CupertinoButton(
      sizeStyle: CupertinoButtonSize.small,
      color: Styles.colors.normalButtonColor,
      onPressed: () => _addStation(context,
        hostController: _hostTextController,
        portController: _portTextController,
      ),
      child: Text('Add'.tr, style: TextStyle(
        color: Styles.colors.buttonTextColor,
      ),),
    );
    //
    //  input tray
    //
    Widget view = Column(
      children: [
        Container(
          width: 360,
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('New Station'.tr),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            hostInput,
            portInput,
            addButton,
          ],
        ),
      ],
    );
    return Center(child: view,);
  }

  void _addStation(BuildContext context, {
    required TextEditingController hostController,
    required TextEditingController portController,
  }) {
    String host = hostController.text.trim();
    String text = portController.text.trim();
    //
    //  check host
    //
    if (host.isEmpty) {
      Alert.show(context, 'Error', 'Please input station host'.tr);
      return;
    } else if (DomainNameServer.isIPAddress(host)) {
      // host is an IP address
    } else if (DomainNameServer.isDomainName(host.toLowerCase())) {
      // host is a domain name
    } else {
      Alert.show(context, 'Error', 'Station host error'.tr);
      return;
    }
    //
    //  check port
    //
    if (text.isEmpty) {
      Alert.show(context, 'Error', 'Please input station port'.tr);
      return;
    }
    int? port = int.tryParse(text);
    if (port == null || port < 15 || port > 65535) {
      Alert.show(context, 'Error', 'Port number error'.tr);
      return;
    }
    //
    //  save into database
    //
    ID sp = ProviderInfo.GSP;
    GlobalVariable shared = GlobalVariable();
    shared.database.addStation(null, host: host, port: port, provider: sp).then((ok) {
      if (ok) {
        hostController.text = '';
        portController.text = '';
      } else {
        logError('failed to add station ($host:$port)');
        if (context.mounted) {
          Alert.show(context, 'Error', 'Failed to add station'.tr);
        }
      }
    }).onError((e, st) {
      logError('failed to add station ($host:$text), error: $e, $st');
      if (context.mounted) {
        Alert.show(context, 'Error', 'Failed to add station'.tr);
      }
    });
  }

  void _confirmRefresh(BuildContext context) {
    Alert.confirm(context, 'Refresh Stations',
      'Refreshing all stations'.tr,
      okAction: _refreshStations,
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
  int numberOfItems(int section) => _dataSource.getItemCount(section);

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _StationCell(_dataSource.getItem(indexPath.section, indexPath.item));

  @override
  bool shouldExistSectionHeader(int section) => section > 0;  // hide 'gsp'

  @override
  bool shouldExistSectionFooter(int section) => section + 1 == numberOfSections();

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
  Widget getSectionFooter(BuildContext context, int section) {
    String prompt = 'RelayStations::Description'.tr;
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

/// TableCell for Station
class _StationCell extends StatefulWidget {
  const _StationCell(this.info);

  final NeighborInfo info;

  @override
  State<StatefulWidget> createState() => _StationCellState();

}

class _StationCellState extends State<_StationCell> with Logging implements lnc.Observer {
  _StationCellState() {

    var nc = lnc.NotificationCenter();
    nc.addObserver(this, NotificationNames.kStationsUpdated);
    nc.addObserver(this, NotificationNames.kStationSpeedUpdated);
  }

  @override
  void dispose() {
    var nc = lnc.NotificationCenter();
    nc.removeObserver(this, NotificationNames.kStationSpeedUpdated);
    nc.removeObserver(this, NotificationNames.kStationsUpdated);
    super.dispose();
  }

  @override
  Future<void> onReceiveNotification(lnc.Notification notification) async {
    String name = notification.name;
    Map? userInfo = notification.userInfo;
    if (name == NotificationNames.kStationSpeedUpdated) {
      VelocityMeter? meter = userInfo?['meter'];
      if (meter?.port != widget.info.port || meter?.host != widget.info.host) {
        return;
      }
      String? state = userInfo?['state'];
      logDebug('test state: $state, $meter');
      if (state == 'start') {
        logDebug('start to test station speed: $meter');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = 0;
          });
        }
      } else if (state == 'connected') {
        logDebug('connected to station: $meter');
      } else if (state == 'failed' || meter?.responseTime == null) {
        logError('speed task failed: $meter, $state');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = -1;
          });
        }
      } else {
        assert(state == 'finished', 'meta state error: $userInfo');
        logDebug('refreshing $meter -> ${widget.info}, $state');
        if (mounted) {
          setState(() {
            widget.info.testTime = DateTime.now();
            widget.info.responseTime = meter?.responseTime;
          });
        }
      }
    } else if (name == NotificationNames.kStationsUpdated) {
      ID? provider = userInfo?['provider'];
      String? host = userInfo?['host'];
      int? port = userInfo?['port'];
      if (port == widget.info.port && host == widget.info.host &&
          provider == widget.info.provider) {
        if (mounted) {
          setState(() {
            //
          });
        }
      }
    } else {
      logError('notification error: $notification');
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
    trailing: _getTrailing(widget.info),
    onTap: () => _switchChosen(widget.info),
    onLongPress: () => _removeError(context, widget.info),
  );

  Widget _getTrailing(NeighborInfo info) {
    Widget timeLabel = Text(_getResult(widget.info),
      style: TextStyle(
        fontSize: 12,
        color: _getColor(widget.info),
      ),
    );
    if (info.chosen == 0) {
      return timeLabel;
    }
    return Row(
      children: [
        timeLabel,
        Icon(AppIcons.selectedIcon,
          color: Styles.colors.primaryTextColor,
        ),
      ],
    );
  }

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
    ID? sid = info.identifier;
    if (sid == null || sid.isBroadcast) {
      // station ID not responded
    } else {
      String? name = info.name;
      name ??= sid.toString();
      if (name.isNotEmpty) {
        return name;
      }
    }
    // String? name = sid?.name;
    // if (name != null && name.isNotEmpty) {
    //   String host = info.host;
    //   return '$name@$host';
    // }
    return info.host;
    // return '${info.host}:${info.port}';
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

  void _removeError(BuildContext context, NeighborInfo info) {
    String result = _getResult(info);
    if (result != 'error' && result != 'unknown') {
      // Alert.show(context, 'Permission Denied', 'Cannot remove this station'.tr);
      return;
    }
    String remote = '${info.host}:${info.port}';
    Alert.confirm(context, 'Confirm Delete', 'Sure to remove this station (@remote)?'.trParams({
      'remote': remote,
    }),
      okAction: () {
        GlobalVariable shared = GlobalVariable();
        shared.database.removeStation(host: info.host, port: info.port, provider: info.provider).then((ok) {
          if (!context.mounted) {
            logWarning('context unmounted: $context');
          } else if (ok) {
            Alert.show(context, 'Success', 'Station (@remote) is removed'.trParams({
              'remote': remote,
            }));
            info.responseTime = null;
          } else {
            Alert.show(context, 'Error', 'Failed to remove station (@remote)'.trParams({
              'remote': remote,
            }));
          }
        });
      }
    );
  }

  void _switchChosen(NeighborInfo info) {
    if (info.chosen > 0) {
      info.chosen = 0;
    } else {
      info.chosen = 1;
    }
    GlobalVariable shared = GlobalVariable();
    shared.database.updateStation(info.identifier, chosen: info.chosen,
      host: info.host, port: info.port, provider: info.provider,);
  }

}
