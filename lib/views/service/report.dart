import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../chat/chat_box.dart';


class CustomerService {

  static ContactInfo? _director;

  // protected
  static ContactInfo? getDirector() {
    var info = _director;
    if (info == null) {
      // get first manager
      Config config = Config();
      var managers = config.managers;
      if (managers.isNotEmpty) {
        info = ContactInfo.fromID(managers.first);
        _director = info;
      }
    }
    return info;
  }

  static bool isDirector(ID user) => user == getDirector()?.identifier;

  static bool isManager(ID user) {
    Config config = Config();
    var managers = config.managers;
    return managers.contains(user);
  }

  static void report(BuildContext context, String text) {
    var admin = getDirector();
    if (admin == null) {
      Alert.show(context, 'Error', 'Customer service not found'.tr);
      return;
    }
    ChatBox.open(context, admin, {
      'title': 'Customer Service'.tr,
      'text': text,
    });
  }

  static Widget reportButton(BuildContext context, String text) => IconButton(
    icon: const Icon(
      AppIcons.reportIcon,
      size: Styles.navigationBarIconSize,
      color: CupertinoColors.systemRed,
    ),
    onPressed: () => report(context, text),
  );

}
