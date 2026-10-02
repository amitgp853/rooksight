// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../play/widgets/result_copy.dart' show moveNumber;
import '../domain/game_analysis.dart';
import '../domain/move_review.dart';
import 'quality_chip.dart';

/// Filters for the move list: everything, or one kind of mark (`!` includes
/// `!!`).
enum MoveFilter {
  all,
  blunders,
  mistakes,
  inaccuracies,
  good;

  bool matches(MoveQuality? quality) => switch (this) {
    MoveFilter.all => true,
    MoveFilter.blunders => quality == MoveQuality.blunder,
    MoveFilter.mistakes => quality == MoveQuality.mistake,
    MoveFilter.inaccuracies => quality == MoveQuality.inaccuracy,
    MoveFilter.good => quality == MoveQuality.best || quality == MoveQuality.brilliant,
  };
}

/// Filter chips plus the move list as a score sheet: one row per move
/// number, marks beside the moves. Tap a move to show it.
class MoveTable extends StatelessWidget {
  const MoveTable({
    super.key,
    required this.analysis,
    required this.player,
    required this.ply,
    required this.filter,
    required this.onFilter,
    required this.onSelect,
  });

  final GameAnalysis analysis;
  final Side player;

  /// The position on the board (moves played).
  final int ply;
  final MoveFilter filter;
  final ValueChanged<MoveFilter> onFilter;

  /// Called with the ply after the tapped move.
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final game = analysis.game;
    final counts = analysis.counts(player);
    final reviews = {for (final r in analysis.moves) r.index: r};

    // Rows of (number, white move index?, black move index?).
    final rows = <(int, int?, int?)>[];
    for (var i = 0; i < game.moves.length; i++) {
      final number = moveNumber(game, i);
      if (game.moves[i].side == Side.white || rows.isEmpty || rows.last.$1 != number) {
        rows.add(game.moves[i].side == Side.white ? (number, i, null) : (number, null, i));
      } else {
        rows.last = (number, rows.last.$2, i);
      }
    }
    bool shown((int, int?, int?) row) {
      if (filter == MoveFilter.all) return true;
      final own = player == Side.white ? row.$2 : row.$3;
      return own != null && filter.matches(reviews[own]?.quality);
    }

    final visible = rows.where(shown).toList();
    // Named filters, each in its mark's colour (All in focus blue).
    final chips = <(MoveFilter, String, int?, Color)>[
      (MoveFilter.all, 'All', null, colors.focus),
      (MoveFilter.blunders, 'Blunders', counts[MoveQuality.blunder], colors.moveBlunder),
      (MoveFilter.mistakes, 'Mistakes', counts[MoveQuality.mistake], colors.moveMistake),
      (
        MoveFilter.inaccuracies,
        'Inaccuracies',
        counts[MoveQuality.inaccuracy],
        colors.moveInaccuracy,
      ),
      (
        MoveFilter.good,
        'Good moves',
        counts[MoveQuality.best]! + counts[MoveQuality.brilliant]!,
        colors.moveBest,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s3,
      children: [
        // All filters stay visible, wrapping onto a second line if needed.
        Wrap(
          spacing: AppSpacing.s2,
          runSpacing: AppSpacing.s2,
          children: [
            for (final (value, label, count, colour) in chips)
              _Chip(
                label: label,
                count: count,
                colour: colour,
                selected: filter == value,
                onTap: () => onFilter(value),
              ),
          ],
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
            child: Text(
              'No moves like that in this game.',
              textAlign: TextAlign.center,
              style: context.type.body.copyWith(color: colors.textSecondary),
            ),
          )
        else
          ClipRRect(
            borderRadius: AppRadius.mdAll,
            child: ColoredBox(
              color: colors.bgRaised,
              child: Column(
                children: [
                  for (final row in visible)
                    _Row(
                      number: row.$1,
                      cells: [row.$2, row.$3],
                      game: analysis,
                      reviews: reviews,
                      selectedIndex: ply - 1,
                      onSelect: onSelect,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.number,
    required this.cells,
    required this.game,
    required this.reviews,
    required this.selectedIndex,
    required this.onSelect,
  });

  final int number;
  final List<int?> cells;
  final GameAnalysis game;
  final Map<int, MoveReview> reviews;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.type.mono;
    final selectedRow = cells.contains(selectedIndex);

    Widget cell(int? index) {
      if (index == null) return const Expanded(child: SizedBox(height: 44));
      final move = game.game.moves[index];
      final quality = reviews[index]?.quality;
      final isSelected = index == selectedIndex;
      final text = style.copyWith(
        color: isSelected || quality != null ? colors.textPrimary : colors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : null,
      );
      return Expanded(
        child: InkWell(
          onTap: () => onSelect(index + 1),
          child: SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: quality == null
                  ? Text(move.san, style: text)
                  // Marked moves: the mark's colour as a border and wash, with
                  // its symbol kept in the text (never colour alone).
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: qualityColor(colors, quality).withValues(alpha: 0.12),
                        border: Border.all(color: qualityColor(colors, quality), width: 1.5),
                        borderRadius: AppRadius.xsAll,
                      ),
                      child: Text.rich(
                        TextSpan(
                          text: move.san,
                          children: [
                            TextSpan(
                              text: quality.symbol,
                              style: TextStyle(color: qualityColor(colors, quality)),
                            ),
                          ],
                        ),
                        style: text,
                      ),
                    ),
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: selectedRow ? colors.focus.withValues(alpha: 0.12) : Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text('$number.', style: style.copyWith(color: colors.textTertiary)),
            ),
            cell(cells[0]),
            cell(cells[1]),
          ],
        ),
      ),
    );
  }
}

/// A named filter chip (pill, height 36) bordered in its mark's colour and
/// washed with it when selected.
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.colour,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type.label.copyWith(fontSize: 14, color: colors.textPrimary);
    final shape = StadiumBorder(
      side: BorderSide(
        color: selected ? colour : colour.withValues(alpha: 0.55),
        width: selected ? 1.5 : 1,
      ),
    );
    return Semantics(
      selected: selected,
      button: true,
      label: count == null ? label : '$label, $count',
      excludeSemantics: true,
      child: Material(
        color: selected ? colour.withValues(alpha: 0.16) : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            // Sized to the label, never stretched to the row.
            child: Center(
              widthFactor: 1,
              child: Text.rich(
                TextSpan(
                  text: label,
                  children: [
                    if (count != null)
                      TextSpan(
                        text: '  $count',
                        style: context.type.mono.copyWith(
                          fontSize: 13,
                          color: count == 0 ? colors.textTertiary : colour,
                        ),
                      ),
                  ],
                ),
                style: type.copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
