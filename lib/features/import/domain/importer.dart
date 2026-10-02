// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../../../core/storage/game_repository.dart';
import '../../../core/storage/import_log.dart';
import '../../../core/storage/settings_store.dart';
import '../data/chess_com_api.dart';
import '../data/chess_com_models.dart';
import '../data/lichess_api.dart';

/// Where games are imported from.
enum ImportPlatform {
  chessCom('Chess.com'),
  lichess('Lichess');

  const ImportPlatform(this.label);

  final String label;
}

/// How far back to import.
enum ImportRange {
  lastMonth(1, 30, 'Last month', '1 month'),
  last3Months(3, 90, 'Last 3 months', '3 months'),
  last12Months(12, 365, 'Last 12 months', '12 months'),
  everything(null, null, 'Everything', 'Everything');

  const ImportRange(this.months, this.days, this.label, this.shortLabel);

  /// Chess.com: calendar months to include, counting the current one.
  final int? months;

  /// Lichess (which works by date): days back from now.
  final int? days;
  final String label;

  /// On the import form's option cards.
  final String shortLabel;
}

enum ImportPhase { idle, checking, importing, done, cancelled, failed }

/// What went wrong, for the screen to explain.
enum ImportError { playerNotFound, offline, rateLimited, unavailable, storage }

/// A snapshot of an import, emitted as it goes.
@immutable
class ImportProgress {
  const ImportProgress({
    this.phase = ImportPhase.idle,
    this.platform = ImportPlatform.chessCom,
    this.username = '',
    this.gamesRead = 0,
    this.month,
    this.monthsDone = 0,
    this.monthsTotal = 0,
    this.added = 0,
    this.alreadySaved = 0,
    this.skipped = 0,
    this.error,
  });

  final ImportPhase phase;
  final ImportPlatform platform;
  final String username;

  /// Lichess: games read so far (they arrive as a stream, not by month).
  final int gamesRead;

  /// The month being fetched.
  final ArchiveMonth? month;
  final int monthsDone;
  final int monthsTotal;

  /// New games stored.
  final int added;

  /// Games that were already in the library.
  final int alreadySaved;

  /// Games not imported: variants, or without moves.
  final int skipped;
  final ImportError? error;

  bool get isRunning => phase == ImportPhase.checking || phase == ImportPhase.importing;

  ImportProgress copyWith({
    ImportPhase? phase,
    int? gamesRead,
    ArchiveMonth? month,
    int? monthsDone,
    int? monthsTotal,
    int? added,
    int? alreadySaved,
    int? skipped,
    ImportError? error,
  }) => ImportProgress(
    phase: phase ?? this.phase,
    platform: platform,
    username: username,
    gamesRead: gamesRead ?? this.gamesRead,
    month: month ?? this.month,
    monthsDone: monthsDone ?? this.monthsDone,
    monthsTotal: monthsTotal ?? this.monthsTotal,
    added: added ?? this.added,
    alreadySaved: alreadySaved ?? this.alreadySaved,
    skipped: skipped ?? this.skipped,
    error: error ?? this.error,
  );
}

/// Imports a player's Chess.com games month by month, newest first.
///
/// Finished months already imported are skipped without a request; the
/// current month is re-checked with its ETag, which costs almost nothing when
/// no new games were played.
class Importer {
  Importer({
    required ChessComApi api,
    required GameRepository games,
    required ImportLog log,
    required DateTime Function() now,
  }) : _api = api,
       _games = games,
       _log = log,
       _now = now;

  final ChessComApi _api;
  final GameRepository _games;
  final ImportLog _log;
  final DateTime Function() _now;

  /// Runs the import, emitting progress after each step. Stops early when
  /// [isCancelled] turns true.
  Stream<ImportProgress> run(
    String username,
    ImportRange range, {
    bool Function()? isCancelled,
  }) async* {
    final name = username.trim();
    var progress = ImportProgress(phase: ImportPhase.checking, username: name);
    yield progress;
    bool cancelled() => isCancelled?.call() ?? false;

    try {
      await _api.checkPlayer(name);
      final months = _inRange(await _api.archives(name), range).reversed.toList();
      progress = progress.copyWith(phase: ImportPhase.importing, monthsTotal: months.length);
      yield progress;

      final now = _now().toUtc();
      final currentMonth = now.year * 12 + now.month - 1;
      for (final month in months) {
        if (cancelled()) {
          yield progress.copyWith(phase: ImportPhase.cancelled);
          return;
        }
        progress = progress.copyWith(month: month);
        yield progress;

        final logged = await _log.get(name, month.key);
        if (logged?.complete ?? false) {
          progress = progress.copyWith(monthsDone: progress.monthsDone + 1);
          continue;
        }

        final result = await _api.monthGames(month, etag: logged?.etag);
        if (!result.notModified) {
          final records = [for (final game in result.games!) ?game.toRecord(name)];
          final added = await _games.saveAllNew(records);
          progress = progress.copyWith(
            added: progress.added + added,
            alreadySaved: progress.alreadySaved + records.length - added,
            skipped: progress.skipped + result.games!.length - records.length,
          );
          await _log.record(
            name,
            month.key,
            ImportedMonth(
              // Only a month that has ended can't gain more games.
              complete: month.index < currentMonth,
              gameCount: records.length,
              etag: result.etag,
            ),
          );
        }
        progress = progress.copyWith(monthsDone: progress.monthsDone + 1);
        yield progress;
      }
      yield progress.copyWith(phase: ImportPhase.done);
    } on ImportFailure catch (failure) {
      yield progress.copyWith(phase: ImportPhase.failed, error: importError(failure));
    } catch (_) {
      yield progress.copyWith(phase: ImportPhase.failed, error: ImportError.storage);
    }
  }

  List<ArchiveMonth> _inRange(List<ArchiveMonth> months, ImportRange range) {
    final count = range.months;
    if (count == null) return months;
    final now = _now().toUtc();
    final first = now.year * 12 + now.month - count;
    return [
      for (final month in months)
        if (month.index >= first) month,
    ];
  }
}

/// What the screen says about a failure.
ImportError importError(ImportFailure failure) => switch (failure) {
  PlayerNotFound() => ImportError.playerNotFound,
  Offline() => ImportError.offline,
  RateLimited() => ImportError.rateLimited,
  ServiceUnavailable() => ImportError.unavailable,
};

/// Imports a player's Lichess games, newest first, as Lichess streams them.
///
/// Remembers, per username, the stretch of time already imported: a later
/// import asks only for games after it, unless the range reaches further
/// back than what was covered.
class LichessImporter {
  LichessImporter({
    required LichessApi api,
    required GameRepository games,
    required SettingsStore settings,
    required DateTime Function() now,
  }) : _api = api,
       _games = games,
       _settings = settings,
       _now = now;

  final LichessApi _api;
  final GameRepository _games;
  final SettingsStore _settings;
  final DateTime Function() _now;

  /// Games stored per batch, so progress shows as they arrive.
  static const batch = 20;

  static String _coveredKey(String username) => 'lichess.covered.${username.toLowerCase()}';

  Stream<ImportProgress> run(
    String username,
    ImportRange range, {
    bool Function()? isCancelled,
  }) async* {
    final name = username.trim();
    var progress = ImportProgress(
      phase: ImportPhase.checking,
      platform: ImportPlatform.lichess,
      username: name,
    );
    yield progress;
    bool cancelled() => isCancelled?.call() ?? false;

    final days = range.days;
    final from = days == null ? 0 : _now().subtract(Duration(days: days)).millisecondsSinceEpoch;
    final covered = _covered(name);
    // Already covered from this far back: only games after that are new.
    final alreadyCovered = covered != null && covered.from <= from;
    final since = alreadyCovered ? covered.to + 1 : from;

    try {
      await _api.checkPlayer(name);
      progress = progress.copyWith(phase: ImportPhase.importing);
      yield progress;

      var newest = alreadyCovered ? covered.to : from;
      final pending = <GameRecord>[];
      Future<ImportProgress> store(ImportProgress progress) async {
        final added = await _games.saveAllNew(pending);
        final stored = pending.length;
        pending.clear();
        return progress.copyWith(
          added: progress.added + added,
          alreadySaved: progress.alreadySaved + stored - added,
        );
      }

      await for (final game in _api.games(
        name,
        since: since == 0 ? null : DateTime.fromMillisecondsSinceEpoch(since, isUtc: true),
      )) {
        if (cancelled()) {
          yield (await store(progress)).copyWith(phase: ImportPhase.cancelled);
          return;
        }
        final record = game.toRecord(name);
        progress = progress.copyWith(
          gamesRead: progress.gamesRead + 1,
          skipped: progress.skipped + (record == null ? 1 : 0),
        );
        if (record != null) {
          pending.add(record);
          final created = game.createdAt.millisecondsSinceEpoch;
          if (created > newest) newest = created;
        }
        if (pending.length >= batch) progress = await store(progress);
        yield progress;
      }
      progress = await store(progress);
      _settings.set(_coveredKey(name), '${alreadyCovered ? covered.from : from}:$newest');
      yield progress.copyWith(phase: ImportPhase.done);
    } on ImportFailure catch (failure) {
      yield progress.copyWith(phase: ImportPhase.failed, error: importError(failure));
    } catch (_) {
      yield progress.copyWith(phase: ImportPhase.failed, error: ImportError.storage);
    }
  }

  /// The stretch already imported for [username], in ms since the epoch.
  ({int from, int to})? _covered(String username) {
    final parts = _settings.get(_coveredKey(username))?.split(':');
    if (parts == null || parts.length != 2) return null;
    final (from, to) = (int.tryParse(parts[0]), int.tryParse(parts[1]));
    return from == null || to == null ? null : (from: from, to: to);
  }
}
