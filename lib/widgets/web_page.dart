/* license: https://mit-license.org
 *
 *  DIM-SDK : Decentralized Instant Messaging Software Development Kit
 *
 *                               Written in 2023 by Moky <albert.moky@gmail.com>
 *
 * =============================================================================
 * The MIT License (MIT)
 *
 * Copyright (c) 2023 Albert Moky
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
import 'package:flutter/widgets.dart';

import 'package:dim_flutter/dim_flutter.dart';


/// WebPageView
class PageContentView extends StatelessWidget {
  const PageContentView({super.key, required this.content, this.onTap, this.onLongPress});

  final PageContent content;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;

  Widget? get icon {
    var small = content['icon'];
    if (small is String) {
      return ImageUtils.getImage(small);
    }
    assert(small == null, 'page icon error: %small');
    return null;
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap ?? () => HtmlUri.showWebPage(context, content: content),
    onLongPress: onLongPress,
    child: _widget(context),
  );

  Widget _widget(BuildContext context) {
    var colors = Styles.colors;
    String url = content.url.toString();
    String title = content.title;
    String desc = content.desc ?? '';
    Widget image = icon ?? Icon(AppIcons.webpageIcon, color: colors.pageMessageColor,);
    if (title.isEmpty) {
      title = url;
      url = '';
    } else if (desc.isEmpty) {
      desc = url;
      url = '';
    }
    return Container(
      color: colors.pageMessageBackgroundColor,
      padding: Styles.pageMessagePadding,
      // width: 256,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
            maxLines: 2,
            style: Styles.pageTitleTextStyle,
          ),
          Row(
            children: [
              Expanded(
                child: Text(desc,
                  maxLines: 3,
                  style: Styles.pageDescTextStyle,
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.all(
                    Radius.elliptical(8, 8)
                ),
                child: SizedBox(
                  width: 48, height: 48,
                  // color: CupertinoColors.systemIndigo,
                  child: image,
                ),
              ),
            ],
          ),
          if (url.isNotEmpty)
            Text(url,
              style: Styles.pageDescTextStyle,
            ),
        ],
      ),
    );
  }

}
