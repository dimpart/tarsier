import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../chat/chat_box.dart';

import 'lives.dart';
import 'playlist.dart';
import 'sites.dart';
import 'users.dart';


//  Service Info Item:
//  {
//      "type": "UserList",
//      "ID": "usher@2wtScvzSouByJm8v7Whbuui1YLZPBHT6wv",
//      "keywords": "active users",
//      "title": "Call Me Maybe",
//      "subtitle": "Don't be shy",
//      "icon": "https://uxwing.com/wp-content/themes/uxwing/download/arts-graphic-shapes/stars-color-icon.png"
//  }

abstract class ServiceInfo extends Dictionary {
  ServiceInfo(super.dict);

  String get type => getString('type') ?? '';

  ID get identifier => ID.parse(this['ID'])!;

  String get title => getString('title') ?? '';

  String? get subtitle => getString('subtitle');

  String? get provider => getString('provider');

  PortableNetworkFile? get icon => PortableNetworkFile.parse(this['icon']);

  /// onTap
  bool open(BuildContext context);

  //
  //  Conveniences
  //

  static List<ServiceInfo> convert(Iterable services) {
    List<ServiceInfo> array = [];
    ServiceInfo? info;
    for (var item in services) {
      info = parse(item);
      if (info == null) {
        // error, ignored
        continue;
      }
      array.add(info);
    }
    return array;
  }

  static List<Map> revert(Iterable<ServiceInfo> services) {
    List<Map> array = [];
    for (var item in services) {
      array.add(item.toMap());
    }
    return array;
  }

  //
  //  Factory methods
  //

  static ServiceInfo? parse(Object? service) {
    if (service == null) {
      return null;
    } else if (service is ServiceInfo) {
      return service;
    }
    Map? info = Wrapper.getMap(service);
    if (info == null) {
      assert(false, 'service info error: $service');
      return null;
    }
    // check bot ID
    var bot = ID.parse(info['ID']);
    if (bot?.type != EntityType.BOT) {
      Log.error('service bot error: $info');
      return null;
    }
    // check type & title
    var type = info['type'];
    var title = info['title'];
    if (title is! String || title.isEmpty) {
      Log.warning('service ignored: $info');
      return null;
    } else if (type is! String || type.isEmpty) {
      Log.warning('service ignored: $info');
      return null;
    }
    Log.info('fetch service: $type, title: $title');
    return _serviceFactory.parseService(info);
  }

}

final _serviceFactory = _ServiceFactory();

class _ServiceFactory {

  ServiceInfo? parseService(Map service) {
    _OpenService callback;
    // check service type
    String? st = Converter.getString(service['type']);
    switch (st) {

      // chat box
      case 'ChatBox':
      case 'ChatBot':
        callback = (ctx, bot, info) => ChatBox.open(ctx, bot, info);
        break;

      // active users
      case 'UserList':
        callback = (ctx, bot, info) => UserListPage.open(ctx, bot, info);
        break;

      // video list
      case 'PlayList':
        callback = (ctx, bot, info) => PlaylistPage.open(ctx, bot, info);
        break;

      // live source list
      case 'LiveSources':
        callback = (ctx, bot, info) => LiveSourceListPage.open(ctx, bot, info);
        break;

      // index page
      case 'WebSites':
        callback = (ctx, bot, info) => WebSitePage.open(ctx, bot, info);
        break;

      default:
        callback = (ctx, bot, info) {
          Log.error('unknown service type: $st, bot: ${bot.name}, info: $info');
          Alert.show(ctx, 'Upgrade', 'Current version not support this service'.tr);
        };
        break;
    }
    // unsupported
    return _ServiceItem(service, callback);
  }

}

typedef _OpenService = void Function(BuildContext ctx, ContactInfo bot, Map info);

class _ServiceItem extends ServiceInfo {
  _ServiceItem(super.dict, this._callback);

  final _OpenService _callback;

  @override
  bool open(BuildContext context) {
    Log.warning('tap: $this');
    ContactInfo? bot = ContactInfo.fromID(identifier);
    if (bot == null) {
      return false;
    }
    _callback(context, bot, toMap());
    return true;
  }

}
