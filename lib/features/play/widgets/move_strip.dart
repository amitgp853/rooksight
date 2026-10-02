// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/game_state.dart';

/// One-line move list. In a game it follows the latest move; in a replay,
/// [ply] marks the move shown on the board and [onSelect] lets the user jump
/// to any move.
class MoveStrip extends StatefulWidget {
  const MoveStrip({super.key, required this.game, this.ply, this.onSelect});

  final GameState game;

  /// Moves played in the position shown (0 is the start). Defaults to all.
  final int? ply;

  /// Called with the ply after the tapped move.
  final ValueChanged<int>? onSelect;

  static const height = 44.0;

  @override
  State<MoveStrip> createState() => _MoveStripState();
}

class _MoveStripState extends State<MoveStrip> {
  final _keys = <int, GlobalKey>{};
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _ply => widget.ply ?? widget.game.moves.length;

  @override
  void initState() {
    super.initState();
    // Opened partway through a replay: start with that move in view.
    if (widget.ply != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_ply - 1, animate: false));
    }
  }

  @override
  void didUpdateWidget(MoveStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // In a replay, keep the selected move in view.
    if (widget.ply != null && widget.ply != oldWidget.ply) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(_ply - 1));
    }
  }

  /// Scrolls this strip (only this one, never the page around it) so move
  /// [index] sits in the middle.
  void _reveal(int index, {bool animate = true}) {
    if (!mounted) return;
    final box = _keys[index]?.currentContext?.findRenderObject();
    if (box == null || !_scroll.hasClients) return;
    final target = RenderAbstractViewport.of(box)
        .getOffsetToReveal(box, 0.5)
        .offset
        .clamp(_scroll.position.minScrollExtent, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
    } else {
      _scroll.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = context.type.mono.copyWith(fontSize: 14);
    final start = widget.game.history.first;
    final moves = widget.game.moves;
    final selected = _ply - 1;

    final items = <Widget>[];
    for (var i = 0; i < moves.length; i++) {
      final ply = i + (start.turn == Side.black ? 1 : 0);
      final isWhite = moves[i].side == Side.white;
      if (isWhite || i == 0) {
        final number = start.fullmoves + ply ~/ 2;
        items.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              isWhite ? '$number.' : '$number…',
              style: style.copyWith(color: colors.textTertiary),
            ),
          ),
        );
      }
      final isSelected = i == selected;
      final san = moves[i].isEnPassant ? '${moves[i].san} e.p.' : moves[i].san;
      final chip = Container(
        key: _keys.putIfAbsent(i, GlobalKey.new),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? colors.bgElevated : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          san,
          style: style.copyWith(color: isSelected ? colors.textPrimary : colors.textSecondary),
        ),
      );
      final onSelect = widget.onSelect;
      items.add(
        onSelect == null
            ? chip
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(i + 1),
                child: chip,
              ),
      );
    }

    return Semantics(
      label: 'Moves',
      child: Container(
        height: MoveStrip.height,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.symmetric(horizontal: BorderSide(color: colors.bgElevated)),
        ),
        child: SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          reverse: true, // Starts with the latest move in view.
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(spacing: 2, children: items),
        ),
      ),
    );
  }
}
