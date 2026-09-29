import 'package:dartchess/dartchess.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Where a game came from: played against Stockfish or between two people
/// on this phone, or imported.
enum GameSource { stockfish, passAndPlay, chesscom, lichess }

/// A game as stored: the PGN plus the facts screens need without parsing it.
@immutable
class GameRecord {
  const GameRecord({
    required this.source,
    required this.pgn,
    required this.playerSide,
    required this.result,
    required this.plyCount,
    required this.startedAt,
    required this.endedAt,
    this.externalId,
    this.endReason,
    this.engineElo,
    this.opponentName,
    this.opponentRating,
    this.playerRating,
    this.timeClass,
    this.timeControl,
    this.practice = false,
    this.hintsUsed = 0,
  });

  final GameSource source;
  final String? externalId;
  final String pgn;
  final Side playerSide;

  /// PGN result: `1-0`, `0-1` or `1/2-1/2`.
  final String result;

  /// How the game ended (a `GameEndReason` name), when known.
  final String? endReason;
  final int? engineElo;

  /// Who the user played, e.g. `Stockfish 1600`, a Chess.com username, or
  /// the other player's name in pass & play.
  final String? opponentName;
  final int? opponentRating;
  final int? playerRating;

  /// Chess.com time class: `bullet`, `blitz`, `rapid` or `daily`.
  final String? timeClass;

  /// PGN time control, e.g. `600+0`.
  final String? timeControl;
  final bool practice;
  final int hintsUsed;
  final int plyCount;
  final DateTime startedAt;
  final DateTime endedAt;

  /// Win, draw or loss from the user's side.
  PlayerOutcome get outcome => switch (result) {
    '1/2-1/2' => PlayerOutcome.draw,
    '1-0' => playerSide == Side.white ? PlayerOutcome.win : PlayerOutcome.loss,
    '0-1' => playerSide == Side.black ? PlayerOutcome.win : PlayerOutcome.loss,
    _ => PlayerOutcome.unknown,
  };
}

enum PlayerOutcome { win, draw, loss, unknown }

/// A [GameRecord] with its database id.
@immutable
class SavedGame {
  const SavedGame(this.id, this.record);

  final int id;
  final GameRecord record;
}

/// Stores and reads games. Behind an interface so tests can use a fake.
abstract interface class GameRepository {
  /// Saves the records whose [GameRecord.externalId] isn't stored yet, in one
  /// transaction. Returns how many were added.
  Future<int> saveAllNew(List<GameRecord> records);

  /// Saves [record] and returns its id. With [id], replaces that game (a
  /// practice game that ended again after a take-back).
  Future<int> save(GameRecord record, {int? id});

  /// All games, newest first, updating as games are added.
  Stream<List<SavedGame>> watchAll();

  Future<SavedGame?> byId(int id);

  /// Deletes game [id] with its analysis and AI review.
  Future<void> delete(int id);
}

class DriftGameRepository implements GameRepository {
  DriftGameRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> save(GameRecord record, {int? id}) async {
    final row = _companion(record);
    if (id == null) return _db.into(_db.games).insert(row);
    await (_db.update(_db.games)..where((g) => g.id.equals(id))).write(row);
    return id;
  }

  @override
  Future<int> saveAllNew(List<GameRecord> records) {
    return _db.transaction(() async {
      final ids = {for (final r in records) ?r.externalId};
      final existing =
          await (_db.selectOnly(_db.games)
                ..addColumns([_db.games.externalId])
                ..where(_db.games.externalId.isIn(ids)))
              .map((row) => row.read(_db.games.externalId))
              .get();
      final seen = existing.toSet();
      var added = 0;
      for (final record in records) {
        // Also skips repeats within this batch.
        if (record.externalId != null && !seen.add(record.externalId)) continue;
        await _db.into(_db.games).insert(_companion(record));
        added++;
      }
      return added;
    });
  }

  static GamesCompanion _companion(GameRecord record) => GamesCompanion.insert(
    source: record.source.name,
    externalId: Value(record.externalId),
    pgn: record.pgn,
    playerSide: record.playerSide.name,
    result: record.result,
    endReason: Value(record.endReason),
    engineElo: Value(record.engineElo),
    opponentName: Value(record.opponentName),
    opponentRating: Value(record.opponentRating),
    playerRating: Value(record.playerRating),
    timeClass: Value(record.timeClass),
    timeControl: Value(record.timeControl),
    practice: Value(record.practice),
    hintsUsed: Value(record.hintsUsed),
    plyCount: record.plyCount,
    startedAt: record.startedAt,
    endedAt: record.endedAt,
  );

  @override
  Stream<List<SavedGame>> watchAll() {
    final query = _db.select(_db.games)
      ..orderBy([(g) => OrderingTerm.desc(g.endedAt), (g) => OrderingTerm.desc(g.id)]);
    return query.watch().map((rows) => rows.map(_toSaved).toList());
  }

  @override
  Future<SavedGame?> byId(int id) async {
    final row = await (_db.select(_db.games)..where((g) => g.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toSaved(row);
  }

  @override
  Future<void> delete(int id) async {
    // The analysis and review go with it (ON DELETE CASCADE).
    await (_db.delete(_db.games)..where((g) => g.id.equals(id))).go();
  }

  static SavedGame _toSaved(GameRow row) => SavedGame(
    row.id,
    GameRecord(
      source: GameSource.values.byName(row.source),
      externalId: row.externalId,
      pgn: row.pgn,
      playerSide: Side.values.byName(row.playerSide),
      result: row.result,
      endReason: row.endReason,
      engineElo: row.engineElo,
      opponentName: row.opponentName,
      opponentRating: row.opponentRating,
      playerRating: row.playerRating,
      timeClass: row.timeClass,
      timeControl: row.timeControl,
      practice: row.practice,
      hintsUsed: row.hintsUsed,
      plyCount: row.plyCount,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
    ),
  );
}

/// The app database. Opened in `main()` and provided with an override, so a
/// forgotten override fails loudly instead of silently losing data.
final appDatabaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Open the database in main() and override this provider.'),
);

final gameRepositoryProvider = Provider<GameRepository>(
  (ref) => DriftGameRepository(ref.watch(appDatabaseProvider)),
);
