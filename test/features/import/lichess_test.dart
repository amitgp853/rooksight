import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/features/import/data/import_failure.dart';
import 'package:move_wise/features/import/data/lichess_api.dart';
import 'package:move_wise/features/import/data/lichess_models.dart';
import 'package:move_wise/features/import/domain/importer.dart';

import '../../support/fake_game_repository.dart';
import '../../support/fake_lichess.dart';
import 'lichess_fixtures.dart';

LichessGame game({
  String id = 'abcd1234',
  String variant = 'standard',
  String status = 'mate',
  String? black = 'opponent42',
  int createdAt = 1759000000000,
}) => LichessGame.fromJson(
  lichessGame(id: id, variant: variant, status: status, black: black, createdAt: createdAt),
);

void main() {
  group('reading a game', () {
    test('a finished standard game, from the player’s side', () {
      final record = game().toRecord('movewisefan')!;
      expect(record.source, GameSource.lichess);
      expect(record.externalId, 'https://lichess.org/abcd1234');
      expect(record.playerSide, Side.white);
      expect(record.result, '0-1');
      expect(record.outcome, PlayerOutcome.loss);
      expect(record.endReason, 'checkmate');
      expect(record.opponentName, 'opponent42');
      expect((record.playerRating, record.opponentRating), (1650, 1702));
      expect((record.timeClass, record.timeControl), ('blitz', '180+2'));
      expect(record.plyCount, 4);
    });

    test('variants, custom starts and unfinished games are skipped', () {
      expect(game(variant: 'chess960').toRecord('movewisefan'), isNull);
      expect(game(variant: 'fromPosition').toRecord('movewisefan'), isNull);
      expect(game(status: 'aborted').toRecord('movewisefan'), isNull);
      expect(game(status: 'started').toRecord('movewisefan'), isNull);
    });

    test('a game the player didn’t play is skipped', () {
      expect(game().toRecord('someone_else'), isNull);
    });

    test('Lichess’s computer opponent gets a name', () {
      expect(game(black: null).toRecord('movewisefan')!.opponentName, 'Lichess AI level 3');
    });

    test('end reasons and time classes in MoveWise’s terms', () {
      GameRecord from(Map<String, Object?> json) =>
          LichessGame.fromJson(json).toRecord('movewisefan')!;
      expect(from(lichessGame(status: 'outoftime')).endReason, 'timeout');
      expect(from(lichessGame(status: 'timeout')).endReason, 'abandoned');
      final draw = from(lichessGame(status: 'draw', winner: null));
      expect((draw.result, draw.endReason), ('1/2-1/2', 'draw'));
      expect(from(lichessGame(speed: 'ultraBullet')).timeClass, 'bullet');
      final correspondence = from(lichessGame(speed: 'correspondence', clockInitial: null));
      expect((correspondence.timeClass, correspondence.timeControl), ('daily', null));
    });
  });

  group('HTTP', () {
    test('streams games, one per line, asking only since the given time', () async {
      late http.BaseRequest sent;
      final api = HttpLichessApi(
        client: MockClient((request) async {
          sent = request;
          final body = [
            jsonEncode(lichessGame(id: 'one')),
            '',
            jsonEncode(lichessGame(id: 'two')),
          ].join('\n');
          return http.Response(body, 200);
        }),
      );
      final games = await api
          .games('MoveWiseFan', since: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true))
          .toList();

      expect(games.map((g) => g.id), ['one', 'two']);
      expect(sent.url.path, '/api/games/user/movewisefan');
      expect(sent.url.queryParameters['since'], '1000');
      expect(sent.url.queryParameters['pgnInJson'], 'true');
      expect(sent.headers['Accept'], 'application/x-ndjson');
      expect(sent.headers['User-Agent'], contains('MoveWise'));
    });

    test('an unknown or closed account is "not found"', () async {
      final unknown = HttpLichessApi(client: MockClient((_) async => http.Response('', 404)));
      await expectLater(unknown.checkPlayer('nobody'), throwsA(isA<PlayerNotFound>()));

      final closed = HttpLichessApi(
        client: MockClient((_) async => http.Response('{"id":"x","disabled":true}', 200)),
      );
      await expectLater(closed.checkPlayer('x'), throwsA(isA<PlayerNotFound>()));
    });

    test('on 429 it waits a minute and tries once more', () async {
      final waits = <Duration>[];
      var calls = 0;
      final api = HttpLichessApi(
        wait: (d) async => waits.add(d),
        client: MockClient(
          (_) async => ++calls == 1 ? http.Response('', 429) : http.Response('{"id":"fan"}', 200),
        ),
      );
      await api.checkPlayer('fan');
      expect(waits, [const Duration(minutes: 1)]);

      final busy = HttpLichessApi(
        wait: (_) async {},
        client: MockClient((_) async => http.Response('', 429)),
      );
      await expectLater(busy.checkPlayer('fan'), throwsA(isA<RateLimited>()));
    });
  });

  group('importer', () {
    late FakeGameRepository games;
    late SettingsStore settings;
    final now = DateTime.utc(2025, 10, 1);

    setUp(() {
      games = FakeGameRepository();
      settings = SettingsStore.inMemory();
    });

    LichessImporter importer(FakeLichess api) =>
        LichessImporter(api: api, games: games, settings: settings, now: () => now);

    final day = const Duration(days: 1).inMilliseconds;
    int daysAgo(int n) => now.millisecondsSinceEpoch - n * day;

    test('imports standard games, counting the rest as skipped', () async {
      final api = FakeLichess([
        game(id: 'a', createdAt: daysAgo(2)),
        game(id: 'b', createdAt: daysAgo(3), variant: 'chess960'),
        game(id: 'c', createdAt: daysAgo(4)),
      ]);
      final last = await importer(api).run('MoveWiseFan', ImportRange.lastMonth).last;

      expect(last.phase, ImportPhase.done);
      expect(last.platform, ImportPlatform.lichess);
      expect((last.added, last.skipped, last.gamesRead), (2, 1, 3));
      expect(games.games, hasLength(2));
      expect(api.sinceAsked.single!.millisecondsSinceEpoch, daysAgo(30));
    });

    test('next time, only games after the newest imported one', () async {
      final api = FakeLichess([game(id: 'a', createdAt: daysAgo(2))]);
      await importer(api).run('MoveWiseFan', ImportRange.lastMonth).last;
      await importer(api).run('MoveWiseFan', ImportRange.lastMonth).last;

      expect(api.sinceAsked.last!.millisecondsSinceEpoch, daysAgo(2) + 1);
    });

    test('a range reaching further back than before fetches all of it', () async {
      final api = FakeLichess([game(id: 'a', createdAt: daysAgo(2))]);
      await importer(api).run('MoveWiseFan', ImportRange.lastMonth).last;
      await importer(api).run('MoveWiseFan', ImportRange.everything).last;

      expect(api.sinceAsked.last, isNull, reason: 'everything, from the start');
    });

    test('failures are explained', () async {
      final api = FakeLichess(const [], failure: const PlayerNotFound('ghost'));
      final last = await importer(api).run('ghost', ImportRange.lastMonth).last;
      expect((last.phase, last.error), (ImportPhase.failed, ImportError.playerNotFound));
    });
  });
}
