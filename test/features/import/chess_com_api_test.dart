import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:move_wise/core/config/app_info.dart';
import 'package:move_wise/features/import/data/chess_com_api.dart';
import 'package:move_wise/features/import/data/chess_com_models.dart';

import 'chess_com_fixtures.dart';

http.Response json(Object body, {int status = 200, Map<String, String> headers = const {}}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json', ...headers},
    );

final march = ArchiveMonth.fromUrl('https://api.chess.com/pub/player/fan/games/2026/03')!;

void main() {
  test('sends the MoveWise User-Agent', () async {
    late http.Request seen;
    final api = HttpChessComApi(
      client: MockClient((request) async {
        seen = request;
        return json({'username': 'fan'});
      }),
    );
    await api.checkPlayer('Fan');

    expect(seen.url.toString(), 'https://api.chess.com/pub/player/fan');
    expect(seen.headers['User-Agent'], AppInfo.userAgent);
  });

  test('an unknown player is PlayerNotFound', () {
    final api = HttpChessComApi(client: MockClient((_) async => json({}, status: 404)));
    expect(api.checkPlayer('nobody'), throwsA(isA<PlayerNotFound>()));
  });

  test('lists archive months, oldest first', () async {
    final api = HttpChessComApi(
      client: MockClient(
        (_) async => json({
          'archives': [
            'https://api.chess.com/pub/player/fan/games/2026/03',
            'https://api.chess.com/pub/player/fan/games/2025/11',
          ],
        }),
      ),
    );
    expect((await api.archives('fan')).map((m) => m.key), ['2025/11', '2026/03']);
  });

  test('reads a month of games and its ETag', () async {
    final api = HttpChessComApi(
      client: MockClient(
        (_) async => json(
          {
            'games': [chessComGame()],
          },
          headers: {'etag': 'W/"abc"'},
        ),
      ),
    );
    final month = await api.monthGames(march);
    expect(month.games!.single.white.username, 'MoveWiseFan');
    expect(month.etag, 'W/"abc"');
  });

  test('sends the ETag back and understands 304', () async {
    late http.Request seen;
    final api = HttpChessComApi(
      client: MockClient((request) async {
        seen = request;
        return http.Response('', 304);
      }),
    );
    final month = await api.monthGames(march, etag: 'W/"abc"');
    expect(seen.headers['If-None-Match'], 'W/"abc"');
    expect(month.notModified, isTrue);
  });

  test('requests never overlap', () async {
    var inFlight = 0;
    var maxInFlight = 0;
    final api = HttpChessComApi(
      client: MockClient((_) async {
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        inFlight--;
        return json({'games': <Object>[]});
      }),
    );
    await Future.wait([for (var i = 0; i < 4; i++) api.monthGames(march)]);
    expect(maxInFlight, 1);
  });

  test('backs off on 429, then succeeds', () async {
    final waits = <Duration>[];
    var calls = 0;
    final api = HttpChessComApi(
      wait: (d) async => waits.add(d),
      client: MockClient((_) async => ++calls < 3 ? http.Response('', 429) : json({})),
    );
    await api.checkPlayer('fan');
    expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('gives up after repeated 429s', () {
    final api = HttpChessComApi(
      wait: (_) async {},
      client: MockClient((_) async => http.Response('', 429)),
    );
    expect(api.checkPlayer('fan'), throwsA(isA<RateLimited>()));
  });

  test('no connection is Offline', () {
    final api = HttpChessComApi(
      client: MockClient((_) async => throw http.ClientException('no route')),
    );
    expect(api.checkPlayer('fan'), throwsA(isA<Offline>()));
  });

  test('a server error is ServiceUnavailable', () {
    final api = HttpChessComApi(client: MockClient((_) async => http.Response('', 503)));
    expect(api.archives('fan'), throwsA(isA<ServiceUnavailable>()));
  });
}
