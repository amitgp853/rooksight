// Debug probe: runs real Stockfish searches through StockfishEngine on a
// device or simulator and prints the UCI traffic with timings, then exits.
//
//   flutter run -d <device> -t tool/engine_probe.dart
import 'dart:io';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rooksight/engine/elo_levels.dart';
import 'package:rooksight/engine/stockfish_engine.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_controller.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

final _clock = Stopwatch()..start();

void _log(String message) => debugPrint('PROBE ${_clock.elapsedMilliseconds}ms $message');

class _LoggingProcess implements UciProcess {
  _LoggingProcess(this._inner);

  final UciProcess _inner;

  @override
  Stream<String> get output => _inner.output.map((line) {
    _log('< $line');
    return line;
  });

  @override
  void send(String command) {
    _log('> $command');
    _inner.send(command);
  }

  @override
  Future<void> start() {
    _log('start');
    return _inner.start().then((_) => _log('started'));
  }

  @override
  Future<void> quit() => _inner.quit();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Center(child: Text('Engine probe', textDirection: TextDirection.ltr)));

  final engine = StockfishEngine(_LoggingProcess(MultistockfishProcess()));
  for (final elo in [400, 1200, 1600]) {
    final level = EloLevel.of(elo);
    _log('--- search at $elo');
    try {
      final lines = await engine.search(_fen, level.searchLimits);
      _log('RESULT $elo: ${lines.length} lines, best ${lines.firstOrNull}');
    } catch (error) {
      _log('FAILED $elo: $error');
    }
  }
  await engine.dispose();

  // The same path as the Game screen: real controller, real engine provider.
  _log('--- game controller at 400');
  final container = ProviderContainer();
  container
      .read(gameConfigProvider.notifier)
      .set(GameConfig.initial.copyWith(level: EloLevel.of(400)));
  container.listen(gameControllerProvider, (_, next) {
    _log(
      'session: moves=${next.game.moves.map((m) => m.san).join(' ')} '
      'thinking=${next.engineThinking} error=${next.engineError}',
    );
  });
  container.read(gameControllerProvider.notifier).play(Move.parse('e2e4')!);
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final session = container.read(gameControllerProvider);
    if (session.game.moves.length == 2 || session.engineError) break;
  }
  final session = container.read(gameControllerProvider);
  _log('CONTROLLER RESULT: moves=${session.game.moves.length} error=${session.engineError}');
  container.dispose();
  _log('DONE');
  exit(0);
}
