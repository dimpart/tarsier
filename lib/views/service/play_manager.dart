import 'package:dim_flutter/dim_flutter.dart';


class PlaylistManager with Logging {
  factory PlaylistManager() => _instance;
  static final PlaylistManager _instance = PlaylistManager._internal();
  PlaylistManager._internal();

  SharedMessenger? get messenger {
    GlobalVariable shared = GlobalVariable();
    var mess = shared.messenger;
    assert(mess != null, 'messenger not set, not connect yet?');
    return mess;
  }

  Content? _content;

  final Map<Uri, DateTime> _videoInfoCreatedTimes = {};
  final Map<Uri, DateTime> _videoInfoQueryExpired = {};

  static Duration kVideoInfoQueryExpires = const Duration(minutes: 5);

  Future<Content?> getPlaylistContent(String title, ID bot) async {
    GlobalVariable shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    return await handler.getContent(bot, 'playlist', title);
  }

  Future<Content?> getSeasonContent(Uri page, ID bot) async {
    GlobalVariable shared = GlobalVariable();
    var handler = ServiceContentHandler(shared.database);
    return await handler.getContent(bot, 'season', page.toString());
  }

  void _updateSeasonCreatedTimes(List playlist) {
    Uri? page;
    DateTime? time;
    for (var item in playlist) {
      if (item is! Map) {
        assert(false, 'play item error: $item');
        continue;
      }
      page = HtmlUri.parseUri(item['page']);
      time = Converter.getDateTime(item['time']);
      if (page == null || time == null) {
        assert(false, 'play item error: $item');
        continue;
      }
      // update current time for page
      _videoInfoCreatedTimes[page] = time;
    }
  }

  bool _isSeasonExpired(Content? content) {
    Map? season = content?['season'];
    if (season == null) {
      logError('season not found: $content');
      return true;
    }
    Uri? page = HtmlUri.parseUri(season['page']);
    DateTime? time = Converter.getDateTime(season['time']);
    if (page == null || time == null) {
      assert(false, 'season error: $season');
      return true;
    }
    DateTime? latestTime = _videoInfoCreatedTimes[page];
    if (latestTime == null) {
      assert(false, 'should not happen: $page');
      return true;
    }
    // if latest updated time is after the season time
    // means there is a newer version,
    // so needs to query again
    return latestTime.isAfter(time);
  }

  bool _checkSeasonQueryExpired(Uri page) {
    DateTime now = DateTime.now();
    DateTime? nextTime = _videoInfoQueryExpired[page];
    if (nextTime != null && nextTime.isAfter(now)) {
      // not reach the next query time yet
      return false;
    }
    // update next query time
    _videoInfoQueryExpired[page] = now.add(kVideoInfoQueryExpires);
    return true;
  }

  ///  Check & update playlist from received content
  ///
  /// @param content - customized content
  /// @param bot     - service bot
  /// @return playlist
  Future<List?> updatePlaylist(Content content, ID bot) async {
    DateTime? oldTime = _content?.time;
    DateTime? newTime = content.time;
    if (oldTime != null && newTime != null && oldTime.isAfter(newTime)) {
      logWarning('ignore expired playlist content: $content');
      return null;
    }
    List? playlist = content['playlist'];
    if (playlist == null || playlist.isEmpty) {
      logError('playlist not found: $content');
      return null;
    }
    // build mapping for playlist
    _updateSeasonCreatedTimes(playlist);
    // query to update seasons
    /*await */_queryExpiredSeasons(playlist, bot);
    // OK
    _content = content;
    return playlist;
  }

  Future<Content?> _queryExpiredSeasons(List playlist, ID bot) async {
    var messenger = this.messenger;
    if (messenger == null) {
      logError('messenger not ready');
      return null;
    }
    var pm = PlaylistManager();
    //
    //  check playlist
    //
    List<String> array = [];
    Uri? page;
    Content? content;
    for (var item in playlist) {
      if (item is! Map) {
        assert(false, 'play item error: $item');
        continue;
      }
      page = HtmlUri.parseUri(item['page']);
      if (page == null) {
        assert(false, 'play item error: $item');
        continue;
      }
      content = await pm.getSeasonContent(page, bot);
      //
      //  check season expired
      //
      if (!_isSeasonExpired(content)) {
        var name = item['name'];
        logInfo('season not expired: "$name"');
        continue;
      }
      //
      //  check query expired
      //
      if (!_checkSeasonQueryExpired(page)) {
        var name = item['name'];
        logInfo('query season not expired: "$name"');
        continue;
      }
      array.add(page.toString());
    }
    if (array.isEmpty) {
      logInfo('playlist not expired, size: ${playlist.length}');
      return null;
    }
    //
    //  query the bot
    //
    var query = CustomizedContent.create(
      app: 'chat.dim.video',
      mod: 'season',
      act: 'request',
    );
    query['page_list'] = array;
    query['format'] = 'markdown';
    query['hidden'] = true;
    // TODO: check visa.key
    logInfo('send to query video info as list (${array.length}/${playlist.length}): $array');
    await messenger.sendContent(query, sender: null, receiver: bot);
    return query;
  }

  ///  Check & query video season
  ///
  /// @param content - customized content
  /// @param page    - season page
  /// @param bot     - service bot
  /// @return query content
  Future<Content?> queryVideoInfo(Content? content, Uri page, ID bot) async {
    var messenger = this.messenger;
    if (messenger == null) {
      logError('messenger not ready');
      return null;
    }
    //
    //  check season expired
    //
    if (!_isSeasonExpired(content)) {
      var season = content?['season'];
      var name = season?['name'];
      logInfo('season not expired: "$name"');
      return null;
    }
    //
    //  check query expired
    //
    if (!_checkSeasonQueryExpired(page)) {
      var season = content?['season'];
      var name = season?['name'];
      logInfo('query season not expired: "$name"');
      return null;
    }
    //
    //  query the bot
    //
    var query = CustomizedContent.create(
      app: 'chat.dim.video',
      mod: 'season',
      act: 'request',
    );
    query['page'] = page.toString();
    query['format'] = 'markdown';
    query['hidden'] = true;
    // TODO: check visa.key
    logInfo('send to query video info: $page');
    await messenger.sendContent(query, sender: null, receiver: bot);
    return query;
  }

}
