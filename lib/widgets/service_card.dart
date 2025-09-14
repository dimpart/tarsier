/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2025 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2025 Albert Moky
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * =============================================================================
 */
import 'package:flutter/cupertino.dart';

import 'package:dim_flutter/dim_flutter.dart';

import '../views/service/base.dart';


/// ServiceCardView
class ServiceCardView extends StatelessWidget {
  const ServiceCardView(this.info, {this.onTap, this.onLongPress, super.key});

  final ServiceInfo info;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    child: _widget(context),
  );

  Widget _widget(BuildContext context) {
    var icon = iconView(info, width: 48, height: 48,);
    var title = _title(info);
    var subtitle = _subtitle(info);
    return Container(
      color: Styles.colors.pageMessageBackgroundColor,
      padding: Styles.pageMessagePadding,
      width: 220,
      child: Row(
        children: [
          icon,
          const SizedBox(width: 8,),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (subtitle != null)
                  const SizedBox(height: 4,),
                if (subtitle != null)
                  subtitle,
              ],
            ),
          ),
          const SizedBox(width: 8,),
        ],
      ),
    );
  }

  Widget _title(ServiceInfo info) {
    String title = info.title;
    return Text(title,
      maxLines: 1,
      style: Styles.pageTitleTextStyle,
    );
  }

  Widget? _subtitle(ServiceInfo info) {
    String? subtitle = info.subtitle;
    if (subtitle == null || subtitle.isEmpty) {
      subtitle = info.provider;
      if (subtitle == null || subtitle.isEmpty) {
        return null;
      }
    }
    return Text(subtitle,
      maxLines: 1,
      style: Styles.pageDescTextStyle,
    );
  }

  static Widget iconView(ServiceInfo info, {double? width, double? height, BoxFit? fit}) {
    width ??= 48;
    height ??= 48;
    var pnf = info.icon;
    if (pnf == null) {
      return SizedBox(width: width, height: height);
    }
    var factory = NetworkImageFactory();
    Widget view = factory.getImageView(pnf);
    // view = factory.getImageView(pnf, fit: BoxFit.cover);
    // view = SizedBox.expand(child: view,);
    view = Container(
      width: width,
      height: height,
      color: CupertinoColors.white,
      padding: const EdgeInsets.all(4),
      alignment: Alignment.center,
      child: view,
    );
    return ClipRRect(
      borderRadius: BorderRadius.all(
        Radius.elliptical(width / 8, height / 8),
      ),
      child: view,
    );
  }

}
