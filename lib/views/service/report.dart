import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../chat/chat_box.dart';


class CustomerService {

  static ContactInfo? webmaster;

  // protected
  static ContactInfo? getWebmaster() {
    var info = webmaster;
    if (info != null) {
      return info;
    }
    Config config = Config();
    var admin = config.webmaster;
    if (admin == null) {
      return null;
    }
    return webmaster = ContactInfo.fromID(admin);
  }

  static void report(BuildContext context, String text) {
    var admin = getWebmaster();
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
