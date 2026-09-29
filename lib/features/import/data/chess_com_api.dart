import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_info.dart';
import 'chess_com_models.dart';
import 'import_failure.dart';
import 'import_pause.dart';

export 'import_failure.dart';

/// One archive month: its games, or "not modified" since [etag].
class MonthGames {
  const MonthGames(this.games, {this.etag});

  const MonthGames.notModified({this.etag}) : games = null;

  /// Null when the month hasn't changed since the ETag we sent.
  final List<ChessComGame>? games;
  final String? etag;

  bool get notModified => games == null;
}

/// The public Chess.com API (no login, no key). Behind an interface so tests
/// use a fake.
abstract interface class ChessComApi {
  /// Throws [PlayerNotFound] if there is no such player.
  Future<void> checkPlayer(String username);

  /// The months with games, oldest first.
  Future<List<ArchiveMonth>> archives(String username);

  /// The games of [month]. With [etag], may answer [MonthGames.notModified].
  Future<MonthGames> monthGames(ArchiveMonth month, {String? etag});
}

/// [ChessComApi] over HTTP. Requests run strictly one at a time (parallel
/// requests get 429), carry a descriptive User-Agent, and back off on 429.
class HttpChessComApi implements ChessComApi {
  HttpChessComApi({http.Client? client, Future<void> Function(Duration)? wait})
    : _client = client ?? http.Client(),
      _wait = wait ?? Future<void>.delayed;

  static final _base = Uri.parse('https://api.chess.com/pub/player/');

  /// Waits after successive 429s before giving up.
  static const backoff = [Duration(seconds: 2), Duration(seconds: 4), Duration(seconds: 8)];

  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final Future<void> Function(Duration) _wait;

  /// Tail of the request queue: each request starts when the previous ends.
  Future<void> _queue = Future.value();

  @override
  Future<void> checkPlayer(String username) async {
    final response = await _get(_base.resolve(_path(username)));
    if (response.statusCode == 404) throw PlayerNotFound(username);
    _expectOk(response);
  }

  @override
  Future<List<ArchiveMonth>> archives(String username) async {
    final response = await _get(_base.resolve('${_path(username)}/games/archives'));
    if (response.statusCode == 404) throw PlayerNotFound(username);
    _expectOk(response);
    final urls = (_json(response)['archives'] as List<Object?>?) ?? const [];
    return [for (final url in urls.whereType<String>()) ?ArchiveMonth.fromUrl(url)]..sort();
  }

  @override
  Future<MonthGames> monthGames(ArchiveMonth month, {String? etag}) async {
    final response = await _get(month.url, etag: etag);
    final newEtag = response.headers['etag'] ?? etag;
    if (response.statusCode == 304) return MonthGames.notModified(etag: newEtag);
    if (response.statusCode == 404) return MonthGames(const [], etag: newEtag);
    _expectOk(response);
    final games = (_json(response)['games'] as List<Object?>?) ?? const [];
    return MonthGames([
      for (final game in games.whereType<Map<String, Object?>>()) ChessComGame.fromJson(game),
    ], etag: newEtag);
  }

  static String _path(String username) => Uri.encodeComponent(username.trim().toLowerCase());

  /// Queues the request behind any in flight, retrying on 429.
  Future<http.Response> _get(Uri url, {String? etag}) {
    final result = _queue.then((_) => _send(url, etag: etag));
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<http.Response> _send(Uri url, {String? etag}) async {
    for (var attempt = 0; ; attempt++) {
      final http.Response response;
      try {
        response = await _client
            .get(
              url,
              headers: {
                'User-Agent': AppInfo.userAgent,
                'Accept': 'application/json',
                'If-None-Match': ?etag,
              },
            )
            .timeout(_timeout);
      } on TimeoutException {
        throw const Offline();
      } on http.ClientException {
        throw const Offline();
      }
      if (response.statusCode != 429) return response;
      if (attempt >= backoff.length) throw const RateLimited();
      await _wait(backoff[attempt]);
    }
  }

  static void _expectOk(http.Response response) {
    if (response.statusCode != 200) throw ServiceUnavailable(response.statusCode);
  }

  static Map<String, Object?> _json(http.Response response) {
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, Object?>;
    } on FormatException {
      throw const ServiceUnavailable();
    } on TypeError {
      throw const ServiceUnavailable();
    }
  }
}

/// Waits after a 429 go through [importPauseProvider], so the screen can show them.
final chessComApiProvider = Provider<ChessComApi>(
  (ref) => HttpChessComApi(wait: ref.read(importPauseProvider.notifier).wait),
);
