import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/app_info.dart';
import 'import_failure.dart';
import 'import_pause.dart';
import 'lichess_models.dart';

/// The public Lichess API (no login, no key). Behind an interface so tests
/// use a fake.
abstract interface class LichessApi {
  /// Throws [PlayerNotFound] if there's no such (open) account.
  Future<void> checkPlayer(String username);

  /// [username]'s games, newest first, from [since] on (all if null).
  Stream<LichessGame> games(String username, {DateTime? since});
}

/// [LichessApi] over HTTP. One request at a time, a descriptive User-Agent,
/// and on 429 a one-minute wait before one more try, as Lichess asks.
class HttpLichessApi implements LichessApi {
  HttpLichessApi({http.Client? client, Future<void> Function(Duration)? wait})
    : _client = client ?? http.Client(),
      _wait = wait ?? Future<void>.delayed;

  static final _base = Uri.parse('https://lichess.org/api/');

  /// Lichess asks clients to wait a full minute after a 429.
  static const rateLimitWait = Duration(minutes: 1);

  static const _timeout = Duration(seconds: 20);

  final http.Client _client;
  final Future<void> Function(Duration) _wait;

  @override
  Future<void> checkPlayer(String username) async {
    final response = await _send(_base.resolve('user/${_path(username)}'), 'application/json');
    final body = await response.stream.bytesToString();
    if (response.statusCode == 404) throw PlayerNotFound(username);
    if (response.statusCode != 200) throw ServiceUnavailable(response.statusCode);
    // Closed accounts answer, but with no games to give.
    try {
      final json = jsonDecode(body) as Map<String, Object?>;
      if (json['disabled'] == true) throw PlayerNotFound(username);
    } on FormatException {
      throw const ServiceUnavailable();
    }
  }

  @override
  Stream<LichessGame> games(String username, {DateTime? since}) async* {
    final url = _base
        .resolve('games/user/${_path(username)}')
        .replace(
          queryParameters: {
            'pgnInJson': 'true',
            'opening': 'true',
            'clocks': 'false',
            'evals': 'false',
            'since': ?since?.millisecondsSinceEpoch.toString(),
          },
        );
    final response = await _send(url, 'application/x-ndjson');
    if (response.statusCode == 404) throw PlayerNotFound(username);
    if (response.statusCode != 200) throw ServiceUnavailable(response.statusCode);
    try {
      await for (final line
          in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        yield LichessGame.fromJson(jsonDecode(line) as Map<String, Object?>);
      }
    } on FormatException {
      throw const ServiceUnavailable();
    } on http.ClientException {
      throw const Offline();
    }
  }

  static String _path(String username) => Uri.encodeComponent(username.trim().toLowerCase());

  Future<http.StreamedResponse> _send(Uri url, String accept) async {
    for (var attempt = 0; ; attempt++) {
      final http.StreamedResponse response;
      try {
        final request = http.Request('GET', url)
          ..headers.addAll({'User-Agent': AppInfo.userAgent, 'Accept': accept});
        response = await _client.send(request).timeout(_timeout);
      } on TimeoutException {
        throw const Offline();
      } on http.ClientException {
        throw const Offline();
      }
      if (response.statusCode != 429) return response;
      await response.stream.drain<void>();
      if (attempt >= 1) throw const RateLimited();
      await _wait(rateLimitWait);
    }
  }
}

/// Waits after a 429 go through [importPauseProvider], so the screen can show them.
final lichessApiProvider = Provider<LichessApi>(
  (ref) => HttpLichessApi(wait: ref.read(importPauseProvider.notifier).wait),
);
