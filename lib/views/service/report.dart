import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../chat/chat_box.dart';


class CustomerService {

  static ContactInfo? webmaster;

  // protected
  static Future<ContactInfo?> getWebmaster() async {
    var info = webmaster;
    if (info != null) {
      return info;
    }
    Config config = await Config().load();
    var admin = config.webmaster;
    if (admin == null) {
      return null;
    }
    return webmaster = ContactInfo.fromID(admin);
  }

  static void report(BuildContext context, String text) => getWebmaster().then((admin) {
    if (admin == null) {
      Log.error('failed to get webmaster');
      return;
    }
    ChatBox.open(context, admin, {
      'title': 'Customer Service'.tr,
      'text': text,
    });
  });

  static Widget reportButton(BuildContext context, String text) => IconButton(
    icon: const Icon(
      AppIcons.reportIcon,
      size: Styles.navigationBarIconSize,
      color: CupertinoColors.systemRed,
    ),
    onPressed: () => report(context, text),
  );

}
