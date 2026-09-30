import 'dart:async';

import 'package:multistockfish/multistockfish.dart';

import 'chess_engine.dart';
import 'uci.dart';

/// A UCI engine process: lines in, lines out. Lets the protocol logic in
/// [StockfishEngine] be tested with a scripted fake.
abstract interface class UciProcess {
  /// Starts the engine; completes once it has finished the UCI handshake
  /// (`uci` → `uciok`) and accepts commands.
  Future<void> start();

  /// Engine output, one line per event. Must be subscribed to before
  /// [send]ing, as output that nobody listens to is dropped.
  Stream<String> get output;

  void send(String command);

  Future<void> quit();
}

/// On-device Stockfish 16 (embedded NNUE) via `multistockfish`, which runs the
/// engine in background isolates.
class MultistockfishProcess implements UciProcess {
  final _stockfish = Stockfish.instance;

  /// `multistockfish` performs the `uci` handshake itself.
  @override
  Future<void> start() => _stockfish.start();

  @override
  Stream<String> get output => _stockfish.stdout;

  @override
  void send(String command) => _stockfish.stdin = command;

  @override
  Future<void> quit() => _stockfish.quit();
}

/// [ChessEngine] speaking UCI to a [UciProcess].
class StockfishEngine implements ChessEngine {
  StockfishEngine([UciProcess? process]) : _process = process ?? MultistockfishProcess();

  final UciProcess _process;

  StreamSubscription<String>? _subscription;
  Future<void>? _started;

  /// Receives output lines while a command waits for its reply.
  void Function(String line)? _onLine;

  /// Tail of the search queue: each search starts when the previous ends.
  Future<void> _queue = Future.value();

  /// A command whose reply takes longer than this is treated as failed. The
  /// slowest timed search (1.5s move time) answers well within it.
  static const _timeout = Duration(seconds: 10);

  /// Deep analysis (depth 24, several lines) can take a while on a phone.
  static const _depthTimeout = Duration(seconds: 90);

  /// A stoppable `go` is running, so `stop` has something to end.
  bool _searching = false;

  @override
  Future<void> warmUp() => _ensureStarted();

  @override
  void stop() {
    if (_searching) _process.send('stop');
  }

  @override
  Future<List<EngineLine>> search(String fen, SearchLimits limits) {
    final result = _queue.then((_) => _search(fen, limits));
    // Keep the queue going even if this search fails.
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<List<EngineLine>> _search(String fen, SearchLimits limits) async {
    await _ensureStarted();

    _setOption('MultiPV', limits.lines);
    final elo = limits.limitElo;
    _setOption('UCI_LimitStrength', elo != null);
    if (elo != null) {
      _setOption('UCI_Elo', elo);
    } else {
      _setOption('Skill Level', limits.skillLevel ?? 20);
    }
    await _command('isready', until: (line) => line == 'readyok');

    _process.send('position fen $fen');

    final lines = <int, EngineLine>{};
    String? bestMove;
    _searching = limits.stoppable;
    try {
      await _command(
        _goCommand(limits),
        timeout: limits.moveTime == null ? _depthTimeout : _timeout,
        until: (line) {
          final info = UciParser.parseInfo(line);
          if (info != null) lines[info.rank] = info; // Deeper lines replace shallower.
          if (!line.startsWith('bestmove')) return false;
          bestMove = UciParser.parseBestMove(line);
          return true;
        },
      );
    } finally {
      _searching = false;
    }

    if (bestMove == null) return const []; // No legal moves.
    final ranked = lines.values.toList()..sort((a, b) => a.rank.compareTo(b.rank));
    // Rare, but an instant reply can skip the info lines.
    if (ranked.isEmpty || ranked.first.move != bestMove) {
      ranked.removeWhere((line) => line.move == bestMove);
      ranked.insert(
        0,
        EngineLine(rank: 1, depth: 0, score: const EngineScore.centipawns(0), pv: [bestMove!]),
      );
    }
    return ranked;
  }

  static String _goCommand(SearchLimits limits) {
    final parts = ['go'];
    if (limits.depth != null) parts.add('depth ${limits.depth}');
    if (limits.moveTime != null) parts.add('movetime ${limits.moveTime!.inMilliseconds}');
    return parts.join(' ');
  }

  void _setOption(String name, Object value) => _process.send('setoption name $name value $value');

  Future<void> _ensureStarted() => _started ??= _start();

  Future<void> _start() async {
    _subscription = _process.output.listen((line) => _onLine?.call(line));
    await _process.start();
    // Win/draw/loss chances with each score, for the analysis board.
    _setOption('UCI_ShowWDL', true);
  }

  /// Sends [command] and completes once an output line satisfies [until].
  Future<void> _command(
    String command, {
    required bool Function(String line) until,
    Duration timeout = _timeout,
  }) {
    final done = Completer<void>();
    _onLine = (line) {
      if (!done.isCompleted && until(line)) done.complete();
    };
    _process.send(command);
    return done.future.timeout(timeout).whenComplete(() => _onLine = null);
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = null;
    await _process.quit();
  }
}
