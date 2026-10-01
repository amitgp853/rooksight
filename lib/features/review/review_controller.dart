import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/analytics/analytics.dart';
import '../../core/settings/display_settings.dart';
import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_client.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/game_repository.dart';
import '../../engine/engine_provider.dart';
import '../play/domain/game_state.dart';
import '../play/domain/pgn_import.dart';
import 'domain/game_analysis.dart';
import 'domain/game_analyzer.dart';
import 'domain/position_eval.dart';
import 'domain/review_explainer.dart';

enum ReviewPhase { loading, notFound, analysing, done, failed }

/// Where the AI explanation of the key moments stands.
enum ExplainPhase { none, running, done, failed }

@immutable
class ReviewState {
  const ReviewState({
    this.phase = ReviewPhase.loading,
    this.saved,
    this.analysis,
    this.explainPhase = ExplainPhase.none,
    this.explanations,
    this.explainError,
  });

  final ReviewPhase phase;
  final SavedGame? saved;

  /// Present from the moment the game is loaded; grows while analysing.
  final GameAnalysis? analysis;

  final ExplainPhase explainPhase;

  /// The AI's explanations, once asked for (kept with the game).
  final ReviewExplanations? explanations;

  /// Why the last explanation failed.
  final LlmFailure? explainError;

  GameState? get game => analysis?.game;

  ReviewState copyWith({
    ReviewPhase? phase,
    GameAnalysis? analysis,
    ExplainPhase? explainPhase,
    ReviewExplanations? explanations,
    LlmFailure? Function()? explainError,
  }) => ReviewState(
    phase: phase ?? this.phase,
    saved: saved,
    analysis: analysis ?? this.analysis,
    explainPhase: explainPhase ?? this.explainPhase,
    explanations: explanations ?? this.explanations,
    explainError: explainError != null ? explainError() : this.explainError,
  );
}

/// Loads a saved game and its Stockfish analysis, running (or resuming) the
/// analysis when needed. Stops when the review closes; progress is kept.
final reviewControllerProvider = NotifierProvider.autoDispose
    .family<ReviewController, ReviewState, int>(ReviewController.new);

class ReviewController extends Notifier<ReviewState> {
  ReviewController(this.gameId);

  final int gameId;

  /// Saved every this many positions, so little is lost if the review closes.
  static const saveEvery = 10;

  bool _disposed = false;

  @override
  ReviewState build() {
    ref.onDispose(() => _disposed = true);
    scheduleMicrotask(_load);
    return const ReviewState();
  }

  Future<void> _load() async {
    final repository = ref.read(analysisRepositoryProvider);
    try {
      final saved = await ref.read(gameRepositoryProvider).byId(gameId);
      if (_disposed) return;
      if (saved == null) {
        state = const ReviewState(phase: ReviewPhase.notFound);
        return;
      }
      final game = gameFromPgn(saved.record.pgn);
      final stored = await repository.analysis(gameId);
      final review = await repository.review(gameId);
      final depth = stored?.depth ?? ref.read(analysisDepthProvider).plies;
      final done = [...?stored?.evals.map(PositionEval.fromJson)];
      state = ReviewState(
        phase: stored?.complete ?? false ? ReviewPhase.done : ReviewPhase.analysing,
        saved: saved,
        analysis: GameAnalysis(game, done),
        explainPhase: review == null ? ExplainPhase.none : ExplainPhase.done,
        explanations: review == null ? null : ReviewExplanations.fromJson(review.json),
      );
      if (stored?.complete ?? false) return;

      final analyzer = GameAnalyzer(ref.read(chessEngineProvider));
      var evals = done;
      await for (final next in analyzer.analyze(
        game,
        depth: depth,
        done: done,
        isCancelled: () => _disposed,
      )) {
        evals = next;
        if (evals.length % saveEvery == 0) await _save(repository, depth, evals, complete: false);
        if (_disposed) return;
        state = state.copyWith(analysis: GameAnalysis(game, evals));
      }
      if (_disposed) {
        await _save(repository, depth, evals, complete: false);
        return;
      }
      await _save(repository, depth, evals, complete: true);
      state = state.copyWith(phase: ReviewPhase.done);
    } catch (_) {
      if (!_disposed) state = state.copyWith(phase: ReviewPhase.failed);
    }
  }

  Future<void> _save(
    AnalysisRepository repository,
    int depth,
    List<PositionEval> evals, {
    required bool complete,
  }) => repository.saveAnalysis(
    gameId,
    StoredAnalysis(depth: depth, evals: [for (final e in evals) e.toJson()], complete: complete),
  );

  /// Key moments the AI explains in its one call, at most.
  static const maxExplainedMoments = 8;

  /// Explains the key moments with one language-model call, and keeps the
  /// result with the game. Only once the analysis is complete.
  Future<void> explain() async {
    final analysis = state.analysis;
    final saved = state.saved;
    if (analysis == null || saved == null || !analysis.isComplete) return;
    if (state.explainPhase == ExplainPhase.running) return;

    // The costliest ones (the list comes costliest first), shown as the full
    // cards: a game full of blunders shouldn't make one big request. The rest
    // keep plain text; "Ask AI" covers any move on request.
    final moments = analysis.keyMoments(saved.record.playerSide).take(maxExplainedMoments).toList();
    if (moments.isEmpty) return;
    state = state.copyWith(explainPhase: ExplainPhase.running, explainError: () => null);
    final llm = ref.read(llmClientProvider);
    final analytics = ref.read(analyticsProvider);
    try {
      final explanations = await ReviewExplainer(llm).explain(analysis, saved.record, moments);
      await ref
          .read(analysisRepositoryProvider)
          .saveReview(gameId, StoredReview(model: llm.model, json: explanations.toJson()));
      analytics.track(Events.reviewExplained, {'outcome': 'ok'});
      if (_disposed) return;
      state = state.copyWith(explainPhase: ExplainPhase.done, explanations: explanations);
    } on LlmFailure catch (failure) {
      analytics.track(Events.reviewExplained, {'outcome': outcomeOf(failure)});
      if (!_disposed) {
        state = state.copyWith(explainPhase: ExplainPhase.failed, explainError: () => failure);
      }
    } catch (_) {
      analytics.track(Events.reviewExplained, {'outcome': 'error'});
      if (!_disposed) {
        state = state.copyWith(
          explainPhase: ExplainPhase.failed,
          explainError: () => const LlmUnavailable(),
        );
      }
    }
  }

  /// Try again after a failure.
  void retry() {
    state = const ReviewState();
    unawaited(_load());
  }
}
