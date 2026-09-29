import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'game_repository.dart';

/// A saved (possibly partial) analysis: per-position entries as JSON maps.
@immutable
class StoredAnalysis {
  const StoredAnalysis({required this.depth, required this.evals, required this.complete});

  final int depth;
  final List<Map<String, Object?>> evals;
  final bool complete;
}

/// A saved AI review: the model's JSON and which model wrote it.
@immutable
class StoredReview {
  const StoredReview({required this.model, required this.json});

  final String model;
  final Map<String, Object?> json;
}

/// Stores analyses and AI reviews per game. Behind an interface for tests.
abstract interface class AnalysisRepository {
  Future<StoredAnalysis?> analysis(int gameId);

  Future<void> saveAnalysis(int gameId, StoredAnalysis analysis);

  Future<StoredReview?> review(int gameId);

  Future<void> saveReview(int gameId, StoredReview review);
}

class DriftAnalysisRepository implements AnalysisRepository {
  DriftAnalysisRepository(this._db);

  final AppDatabase _db;

  @override
  Future<StoredAnalysis?> analysis(int gameId) async {
    final row = await (_db.select(
      _db.gameAnalyses,
    )..where((a) => a.gameId.equals(gameId))).getSingleOrNull();
    if (row == null) return null;
    final evals = (jsonDecode(row.evals) as List<Object?>).whereType<Map<String, Object?>>();
    return StoredAnalysis(depth: row.depth, evals: evals.toList(), complete: row.complete);
  }

  @override
  Future<void> saveAnalysis(int gameId, StoredAnalysis analysis) {
    return _db
        .into(_db.gameAnalyses)
        .insertOnConflictUpdate(
          GameAnalysesCompanion.insert(
            gameId: Value(gameId),
            depth: analysis.depth,
            evals: jsonEncode(analysis.evals),
            complete: analysis.complete,
            updatedAt: DateTime.now(),
          ),
        );
  }

  @override
  Future<StoredReview?> review(int gameId) async {
    final row = await (_db.select(
      _db.gameReviews,
    )..where((r) => r.gameId.equals(gameId))).getSingleOrNull();
    if (row == null) return null;
    return StoredReview(model: row.model, json: jsonDecode(row.json) as Map<String, Object?>);
  }

  @override
  Future<void> saveReview(int gameId, StoredReview review) {
    return _db
        .into(_db.gameReviews)
        .insertOnConflictUpdate(
          GameReviewsCompanion.insert(
            gameId: Value(gameId),
            model: review.model,
            json: jsonEncode(review.json),
            createdAt: DateTime.now(),
          ),
        );
  }
}

final analysisRepositoryProvider = Provider<AnalysisRepository>(
  (ref) => DriftAnalysisRepository(ref.watch(appDatabaseProvider)),
);
