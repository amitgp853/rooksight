// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/engine/elo_levels.dart';
import 'package:rooksight/engine/uci.dart';

import '../support/fake_engine.dart';

void main() {
  test('offers 400 to 3000 in steps of 200', () {
    expect(EloLevel.all.map((l) => l.elo), [for (var e = 400; e <= 3000; e += 200) e]);
  });

  test('uses Stockfish Elo from 1400, above its ~1320 floor', () {
    for (final level in EloLevel.all) {
      expect(level.usesStockfishElo, level.elo >= 1400, reason: '${level.elo}');
      final limits = level.searchLimits;
      if (level.usesStockfishElo) {
        expect(limits.limitElo, level.elo);
        expect(limits.moveTime, isNotNull);
      } else {
        expect(limits.limitElo, isNull);
        expect(limits.skillLevel, isNull, reason: 'full skill, so the scores are honest');
        expect(limits.depth, isNotNull);
        expect(limits.lines, EloLevel.candidates);
      }
    }
  });

  test('hand-weakened levels never get weaker as Elo rises', () {
    final manual = EloLevel.all.where((l) => !l.usesStockfishElo).toList();
    for (var i = 1; i < manual.length; i++) {
      final (lower, higher) = (manual[i - 1], manual[i]);
      expect(higher.depth!, greaterThanOrEqualTo(lower.depth!));
      expect(higher.toleranceCp!, lessThanOrEqualTo(lower.toleranceCp!));
      expect(higher.randomMoveChance, lessThanOrEqualTo(lower.randomMoveChance));
    }
  });

  test('stronger Stockfish levels think at least as long', () {
    final native = EloLevel.all.where((l) => l.usesStockfishElo).toList();
    for (var i = 1; i < native.length; i++) {
      expect(native[i].moveTime!, greaterThanOrEqualTo(native[i - 1].moveTime!));
    }
  });

  test('of() rounds to the nearest level and clamps', () {
    expect(EloLevel.of(1600).elo, 1600);
    expect(EloLevel.of(1650).elo, 1600);
    expect(EloLevel.of(1700).elo, 1800);
    expect(EloLevel.of(100).elo, 400);
    expect(EloLevel.of(4000).elo, 3000);
  });

  test('labels follow the design', () {
    expect(EloLevel.of(800).label, 'Beginner');
    expect(EloLevel.of(1200).label, 'Casual');
    expect(EloLevel.of(1600).label, 'Club player');
    expect(EloLevel.of(2200).label, 'Strong club');
    expect(EloLevel.of(2600).label, 'Master');
    expect(EloLevel.of(3000).label, 'Super-GM');
  });

  group('chooseMove', () {
    // A middlegame-like spread: a few decent moves, then worse and worse ones.
    // Losses in centipawns against the best move.
    const losses = [0, 20, 40, 60, 100, 150, 200, 300, 400, 600, 900, 1200];
    final lines = [for (final (i, loss) in losses.indexed) line('m$i', rank: i + 1, cp: 50 - loss)];
    final legalMoves = [for (var i = 0; i < 30; i++) 'm$i'];

    /// Share of 4000 picks that were the best move, and that lost 3+ pawns
    /// (random picks outside the candidates count as losing 3+ pawns).
    ({double best, double blunders}) profile(EloLevel level) {
      final random = Random(7);
      var best = 0;
      var blunders = 0;
      const picks = 4000;
      for (var i = 0; i < picks; i++) {
        final move = level.chooseMove(lines, legalMoves, random)!;
        final index = int.parse(move.substring(1));
        if (index == 0) best++;
        if (index >= losses.length || losses[index] >= 300) blunders++;
      }
      return (best: best / picks, blunders: blunders / picks);
    }

    test('lower levels find the best move less and blunder more', () {
      final manual = EloLevel.all.where((l) => !l.usesStockfishElo).map(profile).toList();
      for (var i = 1; i < manual.length; i++) {
        expect(manual[i].best, greaterThan(manual[i - 1].best));
        expect(manual[i].blunders, lessThan(manual[i - 1].blunders));
      }
    });

    test('400 plays like a beginner, 1200 rarely drops material', () {
      final beginner = profile(EloLevel.of(400));
      expect(beginner.best, lessThan(0.25));
      expect(beginner.blunders, greaterThan(0.15));

      final casual = profile(EloLevel.of(1200));
      expect(casual.best, greaterThan(0.3));
      expect(casual.blunders, lessThan(0.03));
    });

    test('a missed mate counts as a huge loss', () {
      final mateLines = [
        const EngineLine(rank: 1, depth: 3, score: EngineScore.mate(1), pv: ['mate']),
        line('quiet', rank: 2, cp: 900),
      ];
      final picks = [
        for (var i = 0; i < 200; i++) EloLevel.of(1000).chooseMove(mateLines, const [], Random(i)),
      ];
      expect(picks.where((m) => m == 'quiet'), isEmpty);
    });

    test('Stockfish-Elo levels always play what Stockfish chose', () {
      expect(EloLevel.of(1400).chooseMove(lines, legalMoves, Random(1)), 'm0');
    });

    test('with no candidates, returns null', () {
      expect(EloLevel.of(400).chooseMove(const [], legalMoves, Random(1)), isNull);
    });
  });
}
