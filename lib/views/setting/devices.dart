import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_section_list/flutter_section_list.dart';

import 'package:dim_flutter/dim_flutter.dart';


class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<StatefulWidget> createState() => _DeviceListState();

}

class _DeviceListState extends State<DeviceListPage> with Logging {

  final _DeviceListAdapter _adapter = _DeviceListAdapter();

  @override
  void initState() {
    super.initState();
    _adapter.load().then((ok) {
      if (ok && mounted) {
        setState(() {
        });
      }
      return ok;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Styles.colors.scaffoldBackgroundColor,
    appBar: CupertinoNavigationBar(
      backgroundColor: Styles.colors.appBarBackgroundColor,
      middle: Text('My Devices'.tr, style: Styles.titleTextStyle),
    ),
    body: buildSectionListView(
      enableScrollbar: true,
      adapter: _adapter,
    ),
  );

}

class _DeviceListAdapter with SectionAdapterMixin {

  List<Visa> _documents = [];

  Future<bool> load() async {
    var shared = GlobalVariable();
    var facebook = shared.facebook;
    var user = await facebook.currentUser;
    if (user == null) {
      assert(false, 'current user not found');
      return false;
    }
    List<Visa> visaDocuments = [];
    var docs = await facebook.getDocuments(user.identifier);
    for (final item in docs) {
      if (item is Visa) {
        visaDocuments.add(item);
      }
    }
    _documents = visaDocuments;
    return true;
  }

  @override
  Widget getItem(BuildContext context, IndexPath indexPath) =>
      _DeviceCell(_documents[indexPath.item]);

  @override
  int numberOfItems(int section) => _documents.length;

}

class _DeviceCell extends StatefulWidget {
  const _DeviceCell(this.visa);

  final Visa visa;

  @override
  State<StatefulWidget> createState() => _DeviceState();

}

class _DeviceState extends State<_DeviceCell> {

  @override
  Widget build(BuildContext context) => CupertinoTableCell(
    leadingSize: 72,
    leading: _leading(),
    title: _title(),
    subtitle: _subtitle(),
    trailing: _trailing(),
  );

  Widget _leading() {
    Visa visa = widget.visa;
    const double bigSize = 48;
    const double smallSize = 20;
    // check device type
    IconData? iconData;
    var sys = visa.getProperty('sys');
    if (sys is Map) {
      var os = sys['os'];
      if (os is String) {
        os = os.toLowerCase();
      }
      if (os == 'android') {
        iconData = AppIcons.androidDeviceIcon;
      } else if (os == 'ios') {
        iconData = AppIcons.iosDeviceIcon;
      } else if (os == 'macos') {
        iconData = AppIcons.macosDeviceIcon;
      } else if (os == 'windows') {
        iconData = AppIcons.windowsDeviceIcon;
      }
    }
    iconData ??= AppIcons.unknownDeviceIcon;
    var pnf = visa.avatar;
    if (pnf == null) {
      // show device icon
      return roundedRectangle(Icon(iconData, size: bigSize));
    }
    // show avatar
    var factory = NetworkImageFactory();
    var loader = factory.getImageLoader(pnf);
    Widget avatar = PortableImageView(loader, width: bigSize, height: bigSize,);
    // put on device icon
    Widget icon = Container(
      color: Styles.colors.iconBackgroundColor,
      child: Icon(iconData, size: smallSize),
    );
    return Stack(
      alignment: const AlignmentDirectional(1.5, 1.0),
      children: [
        roundedRectangle(avatar),
        roundedRectangle(icon),
      ],
    );
  }

  Widget roundedRectangle(Widget view, {double radius = 6.0}) => ClipRRect(
    borderRadius: BorderRadius.all(
      Radius.elliptical(radius, radius),
    ),
    child: view,
  );

  Widget _title() {
    var name = widget.visa.name;
    return Text('$name');
  }

  Widget? _subtitle() {
    var sys = widget.visa.getProperty('sys');
    if (sys is! Map) {
      assert(sys == null, 'visa.sys error: $sys');
      return null;
    }
    var device = sys['device'];
    return Text('$device');
  }

  Widget? _trailing() {
    var time = widget.visa.time;
    if (time == null) {
      return null;
    }
    return Text(
      TimeUtils.getTimeString(time),
      // style: _textStyle(),
    );
  }

}
