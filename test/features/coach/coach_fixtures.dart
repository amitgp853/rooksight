import 'package:dartchess/dartchess.dart';
import 'package:rooksight/core/storage/analysis_repository.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/engine/uci.dart';
import 'package:rooksight/features/review/domain/position_eval.dart';

/// Fool's mate played as White: 1. f3 e5 2. g4?? Qh4#.
final foolsMate = GameRecord(
  source: GameSource.stockfish,
  pgn: '[Result "0-1"]\n\n1. f3 e5 2. g4 Qh4# 0-1',
  playerSide: Side.white,
  result: '0-1',
  endReason: 'checkmate',
  engineElo: 1600,
  opponentName: 'Stockfish 1600',
  plyCount: 4,
  startedAt: DateTime(2026, 9, 27),
  endedAt: DateTime(2026, 9, 27),
);

/// Stockfish on each position of [foolsMate]: 1. f3 is an inaccuracy
/// (index 0), 2. g4 a blunder (index 2, best was 2. d4).
final foolsMateAnalysis = StoredAnalysis(
  depth: 16,
  complete: true,
  evals: const [
    PositionEval(score: EngineScore.centipawns(20), bestLine: ['e2e4'], depth: 16),
    PositionEval(score: EngineScore.centipawns(50), bestLine: ['e7e5'], depth: 16),
    PositionEval(score: EngineScore.centipawns(-60), bestLine: ['d2d4', 'g8f6'], depth: 16),
    PositionEval(score: EngineScore.mate(1), bestLine: ['d8h4'], depth: 16),
    PositionEval(score: EngineScore.mate(0), bestLine: []),
  ].map((e) => e.toJson()).toList(),
);

/// A Chess.com win as Black in the Sicilian, not reviewed.
final sicilianWin = GameRecord(
  source: GameSource.chesscom,
  externalId: 'https://www.chess.com/game/live/1',
  pgn:
      '[ECOUrl "https://www.chess.com/openings/Sicilian-Defense-Alapin-Variation-2...Nf6"]\n'
      '[Result "0-1"]\n\n1. e4 c5 2. c3 Nf6 0-1',
  playerSide: Side.black,
  result: '0-1',
  endReason: 'resignation',
  opponentName: 'magnus_fan',
  plyCount: 4,
  startedAt: DateTime(2026, 9, 20),
  endedAt: DateTime(2026, 9, 20),
);

/// The position before 2. g4 in [foolsMate].
const beforeG4 = 'rnbqkbnr/pppp1ppp/8/4p3/8/5P2/PPPPP1PP/RNBQKBNR w KQkq - 0 2';
