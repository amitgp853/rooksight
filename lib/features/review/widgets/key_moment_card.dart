import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/move_review.dart';
import 'quality_chip.dart';

/// One key moment. The selected one is expanded, with Stockfish's best move
/// and actions; the others are compact.
class KeyMomentCard extends StatelessWidget {
  const KeyMomentCard({
    super.key,
    required this.moment,
    required this.moverName,
    required this.isPlayer,
    required this.title,
    required this.body,
    required this.change,
    required this.selected,
    required this.onTap,
    this.bestMove,
    this.depth,
    this.onPlayBestMove,
    this.onAskCoach,
    this.lesson,
    this.aiWritten = false,
  });

  final MoveReview moment;

  /// Who played it: "You", or the opponent's name.
  final String moverName;
  final bool isPlayer;
  final String title;
  final String body;

  /// `+0.4 → −2.9`.
  final String change;
  final bool selected;
  final VoidCallback onTap;

  /// `23. Rd1`, for errors.
  final String? bestMove;

  /// Stockfish's search depth, for "Verified by Stockfish, depth 16".
  final int? depth;

  /// Shows Stockfish's move instead, on the board.
  final VoidCallback? onPlayBestMove;

  /// Opens the coach with a question about this move.
  final VoidCallback? onAskCoach;

  /// A principle to remember, from the AI.
  final String? lesson;

  /// The title and text were written by the AI (and checked).
  final bool aiWritten;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final quality = moment.quality!;
    // "Best was…" and the actions help with the player's own moves.
    final showBest = selected && isPlayer && quality.isError && bestMove != null;

    return Material(
      color: colors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: selected
            ? BorderSide(
                color: Color.alphaBlend(colors.focus.withValues(alpha: 0.3), colors.bgRaised),
              )
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: selected ? 18 : AppSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: selected ? AppSpacing.s3 : AppSpacing.s2,
            children: [
              // Chip and who played it on the left; the eval change on the
              // right, or on its own line when a long name needs the room.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s2,
                runSpacing: AppSpacing.s2,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.s2,
                    children: [
                      QualityChip(quality: quality),
                      Flexible(
                        child: MoverTag(name: moverName, side: moment.side, isPlayer: isPlayer),
                      ),
                    ],
                  ),
                  Text(
                    change,
                    style: type.mono.copyWith(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ),
              Text.rich(
                TextSpan(
                  children: [
                    if (aiWritten)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Semantics(
                            label: 'Explained by AI',
                            child: Icon(Icons.auto_awesome, size: 16, color: colors.focus),
                          ),
                        ),
                      ),
                    TextSpan(text: title),
                  ],
                ),
                style: type.heading.copyWith(
                  fontSize: selected ? 18 : 16,
                  height: selected ? 24 / 18 : null,
                ),
              ),
              if (body.isNotEmpty)
                Text(
                  body,
                  style: type.body.copyWith(
                    fontSize: selected ? 15 : 14,
                    color: selected
                        ? Color.lerp(colors.textSecondary, colors.textPrimary, 0.5)
                        : colors.textSecondary,
                  ),
                ),
              if (lesson case final lesson?) _LessonBox(lesson: lesson),
              if (showBest)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s3),
                  decoration: BoxDecoration(
                    color: colors.bgElevated,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.s3,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(color: colors.focus, shape: BoxShape.circle),
                        child: Icon(Icons.check, size: 14, color: colors.onFocus),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: 'Best was ',
                                children: [
                                  TextSpan(
                                    text: bestMove,
                                    style: type.mono.copyWith(
                                      fontSize: 14,
                                      color: Color.lerp(colors.focus, colors.textPrimary, 0.3),
                                    ),
                                  ),
                                ],
                              ),
                              style: type.body.copyWith(fontSize: 14),
                            ),
                            if (depth != null && depth! > 0)
                              Text(
                                'Verified by Stockfish, depth $depth.',
                                style: type.label.copyWith(
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (selected && isPlayer) ...[
                FilledButton.icon(
                  onPressed: onAskCoach,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                  label: const Text('Ask AI Coach about this move'),
                ),
                if (onPlayBestMove != null)
                  TextButton(
                    onPressed: onPlayBestMove,
                    style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    child: const Text('Play the best move'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The key moment on the board, in short, right under it: so what it says
/// sits next to the position, with the full card one tap away.
class KeyMomentNote extends StatelessWidget {
  const KeyMomentNote({
    super.key,
    required this.quality,
    required this.title,
    required this.body,
    required this.onReadMore,
    this.onShowBestMove,
    this.aiWritten = false,
  });

  final MoveQuality quality;
  final String title;
  final String body;

  /// Scrolls to the full card.
  final VoidCallback onReadMore;

  /// Shows Stockfish's move instead, on the board.
  final VoidCallback? onShowBestMove;

  /// The title and text were written by the AI (and checked).
  final bool aiWritten;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final action = TextButton.styleFrom(
      minimumSize: const Size(0, 36),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: type.label,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(AppSpacing.gutter, 0, AppSpacing.gutter, AppSpacing.s2),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              spacing: AppSpacing.s2,
              children: [
                QualityChip(quality: quality),
                if (aiWritten)
                  Semantics(
                    label: 'Explained by AI',
                    child: Icon(Icons.auto_awesome, size: 16, color: colors.focus),
                  ),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.heading.copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: type.body.copyWith(fontSize: 14, color: colors.textSecondary),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (onShowBestMove != null)
                TextButton(
                  onPressed: onShowBestMove,
                  style: action,
                  child: const Text('Show best move'),
                ),
              TextButton(onPressed: onReadMore, style: action, child: const Text('Read more')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Who played a move: a disc in their piece colour and their name. The
/// player's own tag is tinted focus blue.
class MoverTag extends StatelessWidget {
  const MoverTag({super.key, required this.name, required this.side, required this.isPlayer});

  final String name;
  final Side side;
  final bool isPlayer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: isPlayer ? colors.focus.withValues(alpha: 0.14) : colors.bgElevated,
        borderRadius: AppRadius.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              // The design's porcelain and ink piece colours.
              color: side == Side.white ? const Color(0xFFF5F7FA) : const Color(0xFF1E2530),
              shape: BoxShape.circle,
              border: Border.all(color: colors.textTertiary, width: 1),
            ),
          ),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.label.copyWith(
                fontWeight: FontWeight.w600,
                color: isPlayer
                    ? Color.lerp(colors.focus, colors.textPrimary, 0.3)
                    : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A principle to remember: brass, the design's colour for moments worth
/// keeping.
class _LessonBox extends StatelessWidget {
  const _LessonBox({required this.lesson});

  final String lesson;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.brass.withValues(alpha: 0.10),
        borderRadius: AppRadius.smAll,
        border: Border.all(color: colors.brass.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s3,
        children: [
          Icon(Icons.lightbulb_outline, size: 20, color: colors.brass),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('LESSON', style: type.overline.copyWith(color: colors.brass)),
                Text(
                  lesson,
                  style: type.body.copyWith(
                    fontSize: 14,
                    color: Color.lerp(colors.brass, colors.textPrimary, 0.55),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A key moment in one line, for the moments after the first cards: the
/// mark, the move, who played it and what it cost. Tap to see it on the
/// board (where it opens as a full card).
class KeyMomentRow extends StatelessWidget {
  const KeyMomentRow({
    super.key,
    required this.quality,
    required this.move,
    required this.mover,
    required this.change,
    required this.onTap,
  });

  final MoveQuality quality;

  /// `23. Qxd4??`
  final String move;

  /// `You`, `Stockfish` or the opponent's name.
  final String mover;

  /// `+1.2 → −3.4`
  final String change;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final light = Theme.of(context).brightness == Brightness.light;
    return Semantics(
      button: true,
      label: '${quality.label}, $move by $mover, $change',
      excludeSemantics: true,
      child: Material(
        color: colors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.mdAll,
          side: light ? BorderSide(color: colors.border) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 8, 0),
              child: Row(
                spacing: AppSpacing.s3,
                children: [
                  QualityDisc(quality: quality),
                  Text(move, style: type.mono.copyWith(fontSize: 14)),
                  Expanded(
                    child: Text(
                      mover,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    change,
                    style: type.mono.copyWith(
                      fontSize: 13,
                      color: quality.isError ? qualityColor(colors, quality) : colors.textSecondary,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
