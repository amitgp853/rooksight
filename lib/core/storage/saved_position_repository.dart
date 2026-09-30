import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'game_repository.dart' show appDatabaseProvider;

/// A position saved from the analysis board, with the moves explored.
@immutable
class SavedPosition {
  const SavedPosition({
    required this.id,
    required this.title,
    required this.fen,
    required this.moves,
    required this.path,
    required this.source,
    required this.orientation,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;

  /// The start position.
  final String fen;

  /// The move tree as JSON-ready data: `[{"m": "e2e4", "c": [...]}]`.
  final List<Object?> moves;

  /// Child indices from the start to the position last shown.
  final List<int> path;

  /// An `AnalysisSource` name.
  final String source;

  /// `white` or `black`.
  final String orientation;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Moves in the tree, variations included.
  int get moveCount {
    int count(List<Object?> nodes) => nodes.whereType<Map<String, Object?>>().fold(
      0,
      (sum, n) => sum + 1 + count(n['c'] as List<Object?>? ?? const []),
    );
    return count(moves);
  }
}

/// What to save: everything but the id and dates.
typedef PositionDraft = ({
  String title,
  String fen,
  List<Object?> moves,
  List<int> path,
  String source,
  String orientation,
});

/// Saved analysis-board positions, on the phone. Behind an interface so
/// tests can use [MemorySavedPositionRepository].
abstract interface class SavedPositionRepository {
  Future<int> create(PositionDraft draft, DateTime now);

  /// Replaces the moves and the last position shown.
  Future<void> updateMoves(
    int id, {
    required List<Object?> moves,
    required List<int> path,
    required DateTime now,
  });
  Future<void> rename(int id, String title);
  Future<void> delete(int id);
  Future<SavedPosition?> byId(int id);

  /// Most recently changed first.
  Stream<List<SavedPosition>> watchAll();
}

class DriftSavedPositionRepository implements SavedPositionRepository {
  DriftSavedPositionRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> create(PositionDraft draft, DateTime now) {
    return _db
        .into(_db.savedPositions)
        .insert(
          SavedPositionsCompanion.insert(
            title: draft.title,
            fen: draft.fen,
            moves: Value(jsonEncode(draft.moves)),
            path: Value(jsonEncode(draft.path)),
            source: draft.source,
            orientation: draft.orientation,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  @override
  Future<void> updateMoves(
    int id, {
    required List<Object?> moves,
    required List<int> path,
    required DateTime now,
  }) {
    return (_db.update(_db.savedPositions)..where((p) => p.id.equals(id))).write(
      SavedPositionsCompanion(
        moves: Value(jsonEncode(moves)),
        path: Value(jsonEncode(path)),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> rename(int id, String title) {
    return (_db.update(
      _db.savedPositions,
    )..where((p) => p.id.equals(id))).write(SavedPositionsCompanion(title: Value(title)));
  }

  @override
  Future<void> delete(int id) =>
      (_db.delete(_db.savedPositions)..where((p) => p.id.equals(id))).go();

  @override
  Future<SavedPosition?> byId(int id) async {
    final row = await (_db.select(
      _db.savedPositions,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toPosition(row);
  }

  @override
  Stream<List<SavedPosition>> watchAll() {
    final query = _db.select(_db.savedPositions)
      ..orderBy([(p) => OrderingTerm.desc(p.updatedAt), (p) => OrderingTerm.desc(p.id)]);
    return query.watch().map((rows) => [for (final row in rows) _toPosition(row)]);
  }

  static SavedPosition _toPosition(SavedPositionRow row) {
    List<Object?> list(String json) {
      try {
        final decoded = jsonDecode(json);
        return decoded is List<Object?> ? decoded : const [];
      } on FormatException {
        return const [];
      }
    }

    return SavedPosition(
      id: row.id,
      title: row.title,
      fen: row.fen,
      moves: list(row.moves),
      path: list(row.path).whereType<int>().toList(),
      source: row.source,
      orientation: row.orientation,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

/// In memory, for tests.
class MemorySavedPositionRepository implements SavedPositionRepository {
  final _positions = <int, SavedPosition>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  List<SavedPosition> get all =>
      _positions.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<int> create(PositionDraft draft, DateTime now) async {
    final id = _nextId++;
    _positions[id] = SavedPosition(
      id: id,
      title: draft.title,
      fen: draft.fen,
      moves: draft.moves,
      path: draft.path,
      source: draft.source,
      orientation: draft.orientation,
      createdAt: now,
      updatedAt: now,
    );
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updateMoves(
    int id, {
    required List<Object?> moves,
    required List<int> path,
    required DateTime now,
  }) async {
    final p = _positions[id];
    if (p == null) return;
    _positions[id] = SavedPosition(
      id: id,
      title: p.title,
      fen: p.fen,
      moves: moves,
      path: path,
      source: p.source,
      orientation: p.orientation,
      createdAt: p.createdAt,
      updatedAt: now,
    );
    _changes.add(null);
  }

  @override
  Future<void> rename(int id, String title) async {
    final p = _positions[id];
    if (p == null) return;
    _positions[id] = SavedPosition(
      id: id,
      title: title,
      fen: p.fen,
      moves: p.moves,
      path: p.path,
      source: p.source,
      orientation: p.orientation,
      createdAt: p.createdAt,
      updatedAt: p.updatedAt,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(int id) async {
    _positions.remove(id);
    _changes.add(null);
  }

  @override
  Future<SavedPosition?> byId(int id) async => _positions[id];

  @override
  Stream<List<SavedPosition>> watchAll() async* {
    yield all;
    yield* _changes.stream.map((_) => all);
  }
}

final savedPositionRepositoryProvider = Provider<SavedPositionRepository>(
  (ref) => DriftSavedPositionRepository(ref.watch(appDatabaseProvider)),
);

/// Every saved position, most recent first.
final savedPositionsProvider = StreamProvider<List<SavedPosition>>(
  (ref) => ref.watch(savedPositionRepositoryProvider).watchAll(),
);
