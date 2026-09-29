import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chess_engine.dart';
import 'stockfish_engine.dart';

/// The app's chess engine. Override with a fake in tests.
final chessEngineProvider = Provider<ChessEngine>((ref) {
  final engine = StockfishEngine();
  ref.onDispose(engine.dispose);
  return engine;
});
