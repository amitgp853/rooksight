import 'dart:io' as io;

import 'package:dartchess/dartchess.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/storage/analysis_repository.dart';
import 'package:move_wise/core/storage/database.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/storage/import_log.dart';
import 'package:move_wise/core/storage/settings_store.dart';

GameRecord record({
  DateTime? endedAt,
  String result = '1-0',
  Side playerSide = Side.white,
  String? externalId,
}) => GameRecord(
  source: GameSource.stockfish,
  externalId: externalId,
  pgn: '[Result "$result"]\n\n1. e4 e5 $result',
  playerSide: playerSide,
  result: result,
  endReason: 'resignation',
  engineElo: 1600,
  timeControl: '600+0',
  plyCount: 2,
  startedAt: DateTime(2026, 9, 28, 10),
  endedAt: endedAt ?? DateTime(2026, 9, 28, 10, 30),
);

void main() {
  late AppDatabase db;
  late DriftGameRepository games;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    games = DriftGameRepository(db);
  });
  tearDown(() => db.close());

  group('games', () {
    test('saves and reads back every field', () async {
      final id = await games.save(record(externalId: 'https://chess.com/game/1'));
      final saved = (await games.byId(id))!;

      expect(saved.id, id);
      expect(saved.record.source, GameSource.stockfish);
      expect(saved.record.externalId, 'https://chess.com/game/1');
      expect(saved.record.playerSide, Side.white);
      expect(saved.record.result, '1-0');
      expect(saved.record.endReason, 'resignation');
      expect(saved.record.engineElo, 1600);
      expect(saved.record.timeControl, '600+0');
      expect(saved.record.plyCount, 2);
      expect(saved.record.endedAt, DateTime(2026, 9, 28, 10, 30));
      expect(saved.record.pgn, contains('1. e4 e5'));
    });

    test('lists newest first', () async {
      await games.save(record(endedAt: DateTime(2026, 9, 1)));
      await games.save(record(endedAt: DateTime(2026, 9, 3)));
      await games.save(record(endedAt: DateTime(2026, 9, 2)));

      final list = await games.watchAll().first;
      expect(list.map((g) => g.record.endedAt.day), [3, 2, 1]);
    });

    test('saving with an id replaces that game', () async {
      final id = await games.save(record(result: '1-0'));
      await games.save(record(result: '0-1'), id: id);

      final list = await games.watchAll().first;
      expect(list, hasLength(1));
      expect(list.single.record.result, '0-1');
    });

    test('the same external game cannot be stored twice', () async {
      await games.save(record(externalId: 'x'));
      expect(() => games.save(record(externalId: 'x')), throwsA(isA<SqliteException>()));
    });

    test('byId returns null for an unknown game', () async {
      expect(await games.byId(42), isNull);
    });

    test('outcome is from the player’s side', () {
      expect(record(result: '1-0').outcome, PlayerOutcome.win);
      expect(record(result: '1-0', playerSide: Side.black).outcome, PlayerOutcome.loss);
      expect(record(result: '1/2-1/2').outcome, PlayerOutcome.draw);
    });
  });

  group('settings', () {
    test('changes survive a reload', () async {
      final store = await SettingsStore.load(db);
      expect(store.get('themeMode'), isNull);

      store.set('themeMode', 'light');
      await pumpEventQueue();

      final reloaded = await SettingsStore.load(db);
      expect(reloaded.get('themeMode'), 'light');
    });

    test('a changed value overwrites the old one', () async {
      final store = await SettingsStore.load(db);
      store
        ..set('sound', 'true')
        ..set('sound', 'false');
      await pumpEventQueue();

      expect((await SettingsStore.load(db)).get('sound'), 'false');
    });
  });

  test('the current schema creates every table', () async {
    expect(db.schemaVersion, 3);
    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .map((row) => row.read<String>('name'))
        .get();
    expect(
      tables,
      containsAll(['games', 'settings', 'import_months', 'game_analyses', 'game_reviews']),
    );
  });

  group('migrations', () {
    test('v1 → v2 keeps games and names Stockfish opponents', () async {
      final v1Schema = io.File('test/core/storage/schema_v1.sql').readAsStringSync();
      final upgraded = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(v1Schema);
            raw.execute(
              'INSERT INTO games (source, pgn, player_side, result, engine_elo, ply_count, '
              "started_at, ended_at) VALUES ('stockfish', '1. e4 *', 'white', '1-0', 1600, 1, 0, 0)",
            );
            raw.execute('PRAGMA user_version = 1');
          },
        ),
      );
      addTearDown(upgraded.close);

      final game = (await DriftGameRepository(upgraded).watchAll().first).single.record;
      expect(game.pgn, '1. e4 *');
      expect(game.opponentName, 'Stockfish 1600');
      expect(game.timeClass, isNull);

      // The import log is usable after the upgrade.
      final log = DriftImportLog(upgraded);
      await log.record('Someone', '2026/09', const ImportedMonth(complete: true, gameCount: 3));
      expect((await log.get('someone', '2026/09'))!.gameCount, 3);
    });
  });

  group('batch import', () {
    test('saveAllNew skips games already stored, and repeats in the batch', () async {
      await games.save(record(externalId: 'a'));
      final added = await games.saveAllNew([
        record(externalId: 'a'),
        record(externalId: 'b'),
        record(externalId: 'b'),
        record(externalId: 'c'),
      ]);
      expect(added, 2);
      expect(await games.watchAll().first, hasLength(3));
    });
  });

  group('import log', () {
    test('remembers months per user, case-insensitively', () async {
      final log = DriftImportLog(db);
      expect(await log.get('Hikaru', '2026/08'), isNull);

      await log.record(
        'Hikaru',
        '2026/08',
        const ImportedMonth(complete: false, gameCount: 5, etag: 'W/"1"'),
      );
      await log.record(
        'hikaru',
        '2026/08',
        const ImportedMonth(complete: true, gameCount: 7, etag: 'W/"2"'),
      );

      final month = (await log.get('HIKARU', '2026/08'))!;
      expect(month.complete, isTrue);
      expect(month.gameCount, 7);
      expect(month.etag, 'W/"2"');
    });
  });

  group('v2 → v3', () {
    test('keeps games and adds the analysis tables', () async {
      final v2Schema = io.File('test/core/storage/schema_v2.sql').readAsStringSync();
      final upgraded = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(v2Schema);
            raw.execute(
              'INSERT INTO games (source, pgn, player_side, result, ply_count, '
              "started_at, ended_at) VALUES ('chesscom', '1. e4 *', 'white', '1-0', 1, 0, 0)",
            );
            raw.execute('PRAGMA user_version = 2');
          },
        ),
      );
      addTearDown(upgraded.close);

      final games = await DriftGameRepository(upgraded).watchAll().first;
      expect(games.single.record.source, GameSource.chesscom);

      final analyses = DriftAnalysisRepository(upgraded);
      await analyses.saveAnalysis(
        games.single.id,
        const StoredAnalysis(
          depth: 16,
          evals: [
            {'cp': 20},
          ],
          complete: false,
        ),
      );
      expect((await analyses.analysis(games.single.id))!.depth, 16);
    });
  });

  group('analyses and reviews', () {
    test('deleting a game deletes its analysis and review too', () async {
      final id = await games.save(record());
      final kept = await games.save(record());
      final analyses = DriftAnalysisRepository(db);
      for (final game in [id, kept]) {
        await analyses.saveAnalysis(
          game,
          const StoredAnalysis(depth: 12, evals: [], complete: true),
        );
        await analyses.saveReview(game, const StoredReview(model: 'm', json: {}));
      }

      await games.delete(id);

      expect(await games.byId(id), isNull);
      expect(await analyses.analysis(id), isNull);
      expect(await analyses.review(id), isNull);
      expect(await games.byId(kept), isNotNull);
      expect(await analyses.analysis(kept), isNotNull);
    });

    test('round-trip, and saving again replaces', () async {
      final id = await games.save(record());
      final analyses = DriftAnalysisRepository(db);
      expect(await analyses.analysis(id), isNull);

      await analyses.saveAnalysis(
        id,
        const StoredAnalysis(
          depth: 12,
          evals: [
            {
              'cp': 20,
              'pv': ['e2e4'],
            },
          ],
          complete: false,
        ),
      );
      await analyses.saveAnalysis(
        id,
        const StoredAnalysis(
          depth: 12,
          evals: [
            {'cp': 20},
            {'cp': -15},
          ],
          complete: true,
        ),
      );
      final stored = (await analyses.analysis(id))!;
      expect(stored.complete, isTrue);
      expect(stored.evals, hasLength(2));
      expect(stored.evals.last['cp'], -15);

      await analyses.saveReview(id, const StoredReview(model: 'm', json: {'verdict': 'ok'}));
      expect((await analyses.review(id))!.json['verdict'], 'ok');
    });
  });
}
