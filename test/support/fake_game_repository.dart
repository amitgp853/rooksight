import 'dart:async';

import 'package:rooksight/core/storage/game_repository.dart';

/// In-memory [GameRepository] for widget and controller tests.
class FakeGameRepository implements GameRepository {
  final games = <int, GameRecord>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  /// When true, saving throws.
  bool fail = false;

  @override
  Future<int> save(GameRecord record, {int? id}) async {
    if (fail) throw StateError('save failed');
    final key = id ?? _nextId++;
    games[key] = record;
    _changes.add(null);
    return key;
  }

  @override
  Future<int> saveAllNew(List<GameRecord> records) async {
    if (fail) throw StateError('save failed');
    final seen = {for (final r in games.values) ?r.externalId};
    var added = 0;
    for (final record in records) {
      if (record.externalId != null && !seen.add(record.externalId!)) continue;
      games[_nextId++] = record;
      added++;
    }
    if (added > 0) _changes.add(null);
    return added;
  }

  @override
  Stream<List<SavedGame>> watchAll() async* {
    yield _all();
    await for (final _ in _changes.stream) {
      yield _all();
    }
  }

  @override
  Future<SavedGame?> byId(int id) async {
    final record = games[id];
    return record == null ? null : SavedGame(id, record);
  }

  @override
  Future<void> delete(int id) async {
    if (games.remove(id) != null) _changes.add(null);
  }

  List<SavedGame> _all() =>
      [for (final entry in games.entries) SavedGame(entry.key, entry.value)]
        ..sort((a, b) => b.record.endedAt.compareTo(a.record.endedAt));
}
