// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/import_log.dart';
import 'package:rooksight/features/import/data/chess_com_api.dart';
import 'package:rooksight/features/import/domain/importer.dart';

import '../../support/fake_game_repository.dart';
import '../../support/fake_chess_com.dart';

void main() {
  // "Now" is mid-September 2026: 2026/09 is the current month.
  final now = DateTime.utc(2026, 9, 15);

  Importer importer(FakeChessCom api, FakeGameRepository games, FakeImportLog log) =>
      Importer(api: api, games: games, log: log, now: () => now);

  test('imports newest month first and reports the totals', () async {
    final api = FakeChessCom({
      '2026/08': [game('1'), game('2')],
      '2026/09': [game('3'), game('4', rules: 'chess960')],
    });
    final games = FakeGameRepository();
    final progress = await importer(
      api,
      games,
      FakeImportLog(),
    ).run('fan', ImportRange.last3Months).toList();

    expect(api.fetched, ['2026/09', '2026/08']);
    final last = progress.last;
    expect(last.phase, ImportPhase.done);
    expect(last.added, 3);
    expect(last.skipped, 1, reason: 'the Chess960 game');
    expect(last.monthsDone, 2);
    expect(games.games, hasLength(3));
  });

  test('respects the range', () async {
    final api = FakeChessCom({
      '2026/05': [game('old')],
      '2026/09': [game('new')],
    });
    await importer(
      api,
      FakeGameRepository(),
      FakeImportLog(),
    ).run('fan', ImportRange.last3Months).toList();
    expect(api.fetched, ['2026/09']);
  });

  test('finished months are imported once; the current month is re-checked by ETag', () async {
    final api = FakeChessCom({
      '2026/08': [game('1')],
      '2026/09': [game('2')],
    });
    final games = FakeGameRepository();
    final log = FakeImportLog();

    await importer(api, games, log).run('fan', ImportRange.last3Months).toList();
    expect(log.months['2026/08']!.complete, isTrue);
    expect(log.months['2026/09']!.complete, isFalse);

    api.fetched.clear();
    api.etagsSent.clear();
    final again = await importer(api, games, log).run('fan', ImportRange.last3Months).toList();

    expect(api.fetched, ['2026/09'], reason: 'August is finished and complete');
    expect(api.etagsSent, ['etag-2026/09']);
    expect(again.last.added, 0);
    expect(again.last.alreadySaved, 1);
  });

  test('a month that has not changed adds nothing', () async {
    final api = FakeChessCom({}, unchanged: {'2026/09'});
    final log = FakeImportLog()
      ..months['2026/09'] = const ImportedMonth(complete: false, gameCount: 5, etag: 'e');
    final games = FakeGameRepository();

    final progress = await importer(api, games, log).run('fan', ImportRange.lastMonth).toList();

    expect(api.etagsSent, ['e']);
    expect(progress.last.phase, ImportPhase.done);
    expect(progress.last.added, 0);
    expect(games.games, isEmpty);
    expect(log.months['2026/09']!.gameCount, 5, reason: 'log left as it was');
  });

  test('games already in the library are counted, not added again', () async {
    final games = FakeGameRepository();
    final api = FakeChessCom({
      '2026/09': [game('1'), game('2')],
    });
    await importer(api, games, FakeImportLog()).run('fan', ImportRange.lastMonth).toList();

    // A fresh log (e.g. a reinstall) re-fetches, but the games are known.
    final again = await importer(
      api,
      games,
      FakeImportLog(),
    ).run('fan', ImportRange.lastMonth).toList();
    expect(again.last.added, 0);
    expect(again.last.alreadySaved, 2);
    expect(games.games, hasLength(2));
  });

  test('cancel stops before the next month', () async {
    final api = FakeChessCom({
      '2026/07': [game('1')],
      '2026/08': [game('2')],
      '2026/09': [game('3')],
    });
    var cancelled = false;
    final progress = <ImportProgress>[];
    await for (final p in importer(
      api,
      FakeGameRepository(),
      FakeImportLog(),
    ).run('fan', ImportRange.last3Months, isCancelled: () => cancelled)) {
      progress.add(p);
      if (p.monthsDone == 1) cancelled = true;
    }
    expect(progress.last.phase, ImportPhase.cancelled);
    expect(api.fetched, ['2026/09']);
  });

  test('failures become errors the screen can explain', () async {
    for (final (failure, error) in [
      (const PlayerNotFound('fan'), ImportError.playerNotFound),
      (const Offline(), ImportError.offline),
      (const RateLimited(), ImportError.rateLimited),
      (const ServiceUnavailable(503), ImportError.unavailable),
    ]) {
      final api = FakeChessCom({}, failure: failure);
      final progress = await importer(
        api,
        FakeGameRepository(),
        FakeImportLog(),
      ).run('fan', ImportRange.lastMonth).toList();
      expect(progress.last.phase, ImportPhase.failed);
      expect(progress.last.error, error);
    }
  });

  test('a storage failure is reported too', () async {
    final api = FakeChessCom({
      '2026/09': [game('1')],
    });
    final games = FakeGameRepository()..fail = true;
    final progress = await importer(
      api,
      games,
      FakeImportLog(),
    ).run('fan', ImportRange.lastMonth).toList();
    expect(progress.last.error, ImportError.storage);
  });
}
