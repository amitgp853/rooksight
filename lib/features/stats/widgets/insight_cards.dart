// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/storage/game_repository.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../games/games_screen.dart' show opponentName;
import '../domain/insights.dart';
import '../domain/player_stats.dart';
import 'stats_cards.dart';

/// A small raised tile: label, big number, and a line under it.
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, this.footer, this.onTap});

  final String label;
  final String value;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Material(
      color: colors.bgRaised,
      borderRadius: AppRadius.mdAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.s1,
            children: [
              Text(label.toUpperCase(), style: type.overline.copyWith(color: colors.textTertiary)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.title.copyWith(fontSize: 24, height: 30 / 24),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Two tiles per row.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpacing.s2,
      children: [
        for (var i = 0; i < tiles.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.s2,
              children: [
                Expanded(child: tiles[i]),
                Expanded(child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox()),
              ],
            ),
          ),
      ],
    );
  }
}

/// Win rate, accuracy, blunders per game and the record, each against the
/// games before (arrows in the result colours: blue better, orange worse).
class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.stats, this.previous, required this.periodSize});

  final PlayerStats stats;
  final PlayerStats? previous;

  /// Games in the period, for "vs previous 20".
  final int? periodSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;

    Widget trend(Trend t, {required bool higherIsBetter, required int decimals}) {
      final change = t.change;
      if (change == null) {
        return Text(
          previous == null ? 'no trend yet' : 'no earlier data',
          style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
        );
      }
      final flat = change.abs() < math.pow(10, -decimals) / 2;
      final better = higherIsBetter ? change > 0 : change < 0;
      final color = flat
          ? colors.textTertiary
          : better
          ? Color.lerp(colors.resultWin, colors.textPrimary, 0.2)!
          : colors.resultLoss;
      final arrow = flat ? '=' : (change > 0 ? '↑' : '↓');
      return Text(
        flat
            ? '= vs previous $periodSize'
            : '$arrow ${change.abs().toStringAsFixed(decimals)} vs previous $periodSize',
        style: type.label.copyWith(color: color, fontWeight: FontWeight.w600),
      );
    }

    String number(double? value, {int decimals = 0, String suffix = ''}) =>
        value == null ? '—' : '${value.toStringAsFixed(decimals)}$suffix';

    return _TileGrid(
      tiles: [
        _Tile(
          label: 'Win rate',
          value: number(winRate(stats), suffix: '%'),
          footer: trend(
            Trend(winRate(stats), previous == null ? null : winRate(previous!)),
            higherIsBetter: true,
            decimals: 0,
          ),
        ),
        _Tile(
          label: 'Accuracy',
          value: number(stats.averageAccuracy, decimals: 1),
          footer: trend(
            Trend(stats.averageAccuracy, previous?.averageAccuracy),
            higherIsBetter: true,
            decimals: 1,
          ),
        ),
        _Tile(
          label: 'Blunders / game',
          value: number(stats.blundersPerGame, decimals: 1),
          footer: trend(
            Trend(stats.blundersPerGame, previous?.blundersPerGame),
            higherIsBetter: false,
            decimals: 1,
          ),
        ),
        _Tile(
          label: 'Record',
          value: '${stats.wins}–${stats.draws}–${stats.losses}',
          footer: Text(
            'wins – draws – losses',
            style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}

/// Mistakes and blunders by move number: when in a game things go wrong.
class MoveTimingCard extends StatelessWidget {
  const MoveTimingCard({super.key, required this.buckets, required this.reviewed});

  final List<MoveBucket> buckets;
  final int reviewed;

  static const _chartHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final total = buckets.fold(0, (a, b) => a + b.errors);
    final most = buckets.fold(0, (a, b) => math.max(a, b.errors));
    final caption = type.body.copyWith(fontSize: 13, height: 19 / 13, color: colors.textSecondary);

    Widget key(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s1,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        Text(label, style: type.label.copyWith(fontSize: 12, color: colors.textSecondary)),
      ],
    );

    return StatsSection(
      title: 'When your games go wrong',
      subtitle: 'Mistakes and blunders by move number',
      trailing: total == 0
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 10,
              children: [key('Mistake', colors.moveMistake), key('Blunder', colors.moveBlunder)],
            ),
      children: [
        if (reviewed == 0 || total == 0)
          Text(
            reviewed == 0
                ? 'Review some games to see at which moves your mistakes happen.'
                : 'No mistakes or blunders in your reviewed games.',
            style: caption,
          )
        else ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: AppSpacing.s3,
              children: [
                for (final b in buckets)
                  Expanded(
                    child: Semantics(
                      label: 'Moves ${b.label}: ${b.mistakes} mistakes, ${b.blunders} blunders',
                      excludeSemantics: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        spacing: 4,
                        children: [
                          Text(
                            '${b.errors}',
                            style: type.mono.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: _chartHeight * b.mistakes / most,
                                  color: colors.moveMistake,
                                ),
                                Container(
                                  height: _chartHeight * b.blunders / most,
                                  color: colors.moveBlunder,
                                ),
                                // A sliver for empty stretches, so the axis reads.
                                if (b.errors == 0) Container(height: 2, color: colors.bgElevated),
                              ],
                            ),
                          ),
                          Text(
                            b.label,
                            style: type.label.copyWith(fontSize: 11, color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Text(moveTimingTakeaway(buckets), style: caption),
        ],
      ],
    );
  }
}

/// One line on when things go wrong.
String moveTimingTakeaway(List<MoveBucket> buckets) {
  final total = buckets.fold(0, (a, b) => a + b.errors);
  final worst = buckets.reduce((a, b) => b.errors > a.errors ? b : a);
  final share = (worst.errors / total * 100).round();
  final range = worst.label.endsWith('+')
      ? 'after move ${worst.label.replaceAll('+', '')}'
      : 'between moves ${worst.label.replaceAll('–', ' and ')}';
  return '$share% of your mistakes and blunders come $range.';
}

/// Best accuracy, biggest comeback, longest win streak and peak rating,
/// across every game.
class PersonalBestsCard extends StatelessWidget {
  const PersonalBestsCard({super.key, required this.bests});

  final PersonalBests bests;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    Widget sub(String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400),
    );
    VoidCallback? open(Best? best) => best == null
        ? null
        : () => context.push(Routes.review('${best.game.saved.id}', ply: best.ply));

    final accuracy = bests.bestAccuracy;
    final comeback = bests.biggestComeback;
    final peak = bests.peakRating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s3,
      children: [
        Text('Personal bests', style: type.title.copyWith(fontSize: 20, letterSpacing: -0.2)),
        _TileGrid(
          tiles: [
            _Tile(
              label: 'Best accuracy',
              value: accuracy == null ? '—' : '${accuracy.value.round()}%',
              footer: sub(accuracy == null ? 'Review a game' : 'vs ${_vs(accuracy.game.record)}'),
              onTap: open(accuracy),
            ),
            _Tile(
              label: 'Biggest comeback',
              value: comeback == null ? '—' : '−${comeback.value.toStringAsFixed(1)}',
              footer: sub(
                comeback == null ? 'Win from 3+ pawns down' : 'won vs ${_vs(comeback.game.record)}',
              ),
              onTap: open(comeback),
            ),
            _Tile(
              label: 'Win streak',
              value: bests.longestWinStreak == 0 ? '—' : '${bests.longestWinStreak}',
              footer: sub(bests.longestWinStreak == 1 ? 'win' : 'wins in a row'),
            ),
            _Tile(
              label: 'Peak rating',
              value: peak == null ? '—' : '${peak.value}',
              footer: sub(
                peak == null
                    ? 'From Chess.com or Lichess games'
                    : [
                        ?peak.game.record.timeClass,
                        switch (peak.game.record.source) {
                          GameSource.lichess => 'Lichess',
                          _ => 'Chess.com',
                        },
                      ].join(' · '),
              ),
              onTap: open(peak),
            ),
          ],
        ),
      ],
    );
  }

  static String _vs(GameRecord record) => opponentName(record);
}
