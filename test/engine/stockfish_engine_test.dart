import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/engine/chess_engine.dart';
import 'package:move_wise/engine/elo_levels.dart';
import 'package:move_wise/engine/stockfish_engine.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Answers UCI commands like Stockfish would, and records what it was sent.
class _ScriptedProcess implements UciProcess {
  _ScriptedProcess({this.searchOutput = _defaultSearch});

  static const _defaultSearch = [
    'info depth 1 multipv 1 score cp 20 pv e2e4',
    'info depth 8 multipv 1 score cp 31 pv e2e4 e7e5',
    'info depth 8 multipv 2 score cp 25 pv d2d4 d7d5',
    'bestmove e2e4 ponder e7e5',
  ];

  final List<String> searchOutput;
  final sent = <String>[];
  final _output = StreamController<String>.broadcast(sync: true);
  bool started = false;
  bool didQuit = false;

  @override
  Stream<String> get output => _output.stream;

  @override
  Future<void> start() async => started = true;

  @override
  void send(String command) {
    sent.add(command);
    // Reply asynchronously, as the real engine does.
    scheduleMicrotask(() {
      if (command == 'isready') _output.add('readyok');
      if (command.startsWith('go')) searchOutput.forEach(_output.add);
    });
  }

  @override
  Future<void> quit() async => didQuit = true;
}

void main() {
  test('starts the engine once and returns lines best first', () async {
    final process = _ScriptedProcess();
    final engine = StockfishEngine(process);

    final lines = await engine.search(_startFen, const SearchLimits(depth: 8, lines: 2));

    expect(process.started, isTrue);
    expect(process.sent, isNot(contains('uci')), reason: 'start() does the handshake');
    expect(lines.map((l) => l.move), ['e2e4', 'd2d4']);
    expect(lines.first.depth, 8, reason: 'deeper info replaces shallower');
    expect(process.sent, contains('position fen $_startFen'));
    expect(process.sent.last, 'go depth 8');
  });

  test('Stockfish-Elo levels limit strength natively', () async {
    final process = _ScriptedProcess();
    await StockfishEngine(process).search(_startFen, EloLevel.of(1600).searchLimits);

    expect(
      process.sent,
      containsAllInOrder([
        'setoption name MultiPV value 1',
        'setoption name UCI_LimitStrength value true',
        'setoption name UCI_Elo value 1600',
        'go movetime 500',
      ]),
    );
  });

  test('hand-weakened levels search many candidates at full skill', () async {
    final process = _ScriptedProcess();
    await StockfishEngine(process).search(_startFen, EloLevel.of(800).searchLimits);

    expect(
      process.sent,
      containsAllInOrder([
        'setoption name MultiPV value 12',
        'setoption name UCI_LimitStrength value false',
        'setoption name Skill Level value 20',
        'go depth 3',
      ]),
    );
  });

  test('full strength resets Skill Level to 20', () async {
    final process = _ScriptedProcess();
    await StockfishEngine(process).search(_startFen, fullStrengthLimits);

    expect(process.sent, contains('setoption name Skill Level value 20'));
    expect(process.sent, contains('setoption name UCI_LimitStrength value false'));
  });

  test('queued searches do not interleave', () async {
    final process = _ScriptedProcess();
    final engine = StockfishEngine(process);

    await Future.wait([
      engine.search(_startFen, const SearchLimits(depth: 1)),
      engine.search(_startFen, const SearchLimits(depth: 2)),
    ]);

    final goCommands = process.sent.where((c) => c.startsWith('go')).toList();
    expect(goCommands, ['go depth 1', 'go depth 2']);
    final firstGo = process.sent.indexOf('go depth 1');
    final secondPosition = process.sent.lastIndexOf('position fen $_startFen');
    expect(secondPosition, greaterThan(firstGo), reason: 'second search waits for the first');
  });

  test('returns nothing when there is no legal move', () async {
    final process = _ScriptedProcess(
      searchOutput: ['info depth 0 score mate 0', 'bestmove (none)'],
    );
    final lines = await StockfishEngine(process).search(_startFen, const SearchLimits(depth: 1));
    expect(lines, isEmpty);
  });

  test('falls back to bestmove when no info line matches it', () async {
    final process = _ScriptedProcess(searchOutput: ['bestmove g1f3']);
    final lines = await StockfishEngine(process).search(_startFen, const SearchLimits(depth: 1));
    expect(lines.single.move, 'g1f3');
  });

  test('dispose quits the engine', () async {
    final process = _ScriptedProcess();
    final engine = StockfishEngine(process);
    await engine.warmUp();
    await engine.dispose();
    expect(process.didQuit, isTrue);
  });
}
