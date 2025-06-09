import 'package:dim_flutter/dim_flutter.dart';


class PlaylistManager with Logging {
  factory PlaylistManager() => _instance;
  static final PlaylistManager _instance = PlaylistManager._internal();
  PlaylistManager._internal();

  Content? _content;

  final Map<Uri, DateTime> _createdTimes = {};
  final Map<Uri, DateTime> _queryExpires = {};

  static Duration kExpires = const Duration(minutes: 32);

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
    _updateCreatedTimes(playlist);
    // query to update all seasons
    await _updateExpiredSeasons(playlist, bot);
    // OK
    _content = content;
    return playlist;
  }
  void _updateCreatedTimes(List playlist) {
    Uri? page;
    DateTime? time;
    for (var item in playlist) {
      if (item is! Map) {
        assert(false, 'play item error: $item');
        continue;
      }
      page = HtmlUri.parseUri(item['page']);
      time = Converter.getDateTime(item['time'], null);
      if (page == null || time == null) {
        assert(false, 'play item error: $item');
        continue;
      }
      // update current time for page
      _createdTimes[page] = time;
    }
  }
  Future<bool> _updateExpiredSeasons(List playlist, ID bot) async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      logError('messenger not set, not connect yet?');
      return false;
    }
    var handler = ServiceContentHandler(shared.database);
    Content? content;
    List<String> array = [];
    Uri? page;
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
      content = await handler.getContent(bot, 'season', page.toString());
      if (!_isSeasonExpired(content)) {
        logInfo('season not expired yet: $item');
        continue;
      }
      if (!_checkQueryExpired(page)) {
        logInfo('query season not expired yet: $item');
        continue;
      }
      array.add(page.toString());
    }
    if (array.isEmpty) {
      logInfo('playlist not expired yet');
      return false;
    }
    //
    //  query the bot
    //
    content = CustomizedContent.create(app: 'chat.dim.video', mod: 'season', act: 'request');
    content['page_list'] = array;
    content['format'] = 'markdown';
    content['hidden'] = true;
    // TODO: check visa.key
    logInfo('send to query video info as list (${array.length}/${playlist.length}): $array');
    await messenger.sendContent(content, sender: null, receiver: bot);
    return true;
  }

  Future<bool> updateSeason(Content? content, Uri page, ID bot) async {
    GlobalVariable shared = GlobalVariable();
    SharedMessenger? messenger = shared.messenger;
    if (messenger == null) {
      logError('messenger not set, not connect yet?');
      return false;
    }
    //
    //  check session expired
    //
    if (!_isSeasonExpired(content)) {
      var season = content?['season'];
      logInfo('season not expired yet: $season');
      return false;
    }
    //
    //  check query expired
    //
    if (!_checkQueryExpired(page)) {
      var season = content?['season'];
      logInfo('query season not expired yet: $season');
      return false;
    }
    //
    //  query the bot
    //
    content = CustomizedContent.create(app: 'chat.dim.video', mod: 'season', act: 'request');
    content['page'] = page.toString();
    content['format'] = 'markdown';
    content['hidden'] = true;
    // TODO: check visa.key
    logInfo('send to query video info: $page');
    await messenger.sendContent(content, sender: null, receiver: bot);
    return true;
  }

  bool _isSeasonExpired(Content? content) {
    Map? season = content?['season'];
    if (season == null) {
      logError('season not found: $content');
      return true;
    }
    Uri? page = HtmlUri.parseUri(season['page']);
    DateTime? time = Converter.getDateTime(season['time'], null);
    if (page == null || time == null) {
      assert(false, 'season error: $season');
      return true;
    }
    DateTime? latestTime = _createdTimes[page];
    if (latestTime == null) {
      assert(false, 'should not happen: $page');
      return true;
    }
    // if latest updated time is after the season time
    // means there is a newer version,
    // so needs to query again
    return latestTime.isAfter(time);
  }

  bool _checkQueryExpired(Uri page) {
    DateTime now = DateTime.now();
    DateTime? nextTime = _queryExpires[page];
    if (nextTime != null && nextTime.isAfter(now)) {
      // not reach the next query time yet
      return false;
    }
    // update next query time
    _queryExpires[page] = now.add(kExpires);
    return true;
  }

}
