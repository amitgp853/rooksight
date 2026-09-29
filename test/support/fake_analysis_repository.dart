import 'package:move_wise/core/storage/analysis_repository.dart';

/// In-memory [AnalysisRepository] for tests.
class FakeAnalysisRepository implements AnalysisRepository {
  final analyses = <int, StoredAnalysis>{};
  final reviews = <int, StoredReview>{};

  @override
  Future<StoredAnalysis?> analysis(int gameId) async => analyses[gameId];

  @override
  Future<void> saveAnalysis(int gameId, StoredAnalysis analysis) async =>
      analyses[gameId] = analysis;

  @override
  Future<StoredReview?> review(int gameId) async => reviews[gameId];

  @override
  Future<void> saveReview(int gameId, StoredReview review) async => reviews[gameId] = review;
}
