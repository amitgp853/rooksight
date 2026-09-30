import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../engine/uci.dart';
import '../../review/domain/move_review.dart';
import '../../review/widgets/quality_chip.dart';
import '../domain/analysis_session.dart';
import '../domain/analysis_text.dart';
import '../domain/analysis_tree.dart';

/// White / draw / Black chances under the eval bar, from Stockfish's WDL.
class WdlStrip extends ConsumerWidget {
  const WdlStrip({super.key, required this.wdl});

  /// Null until Stockfish has sent one: the strip is empty.
  final ({int white, int draw, int black})? wdl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final w = wdl;
    final style = context.type.label.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: colors.textSecondary,
    );
    final duration = shouldReduceMotion(context, ref)
        ? Duration.zero
        : const Duration(milliseconds: 240);
    return Semantics(
      label: w == null
          ? 'Win chances not known yet'
          : 'White wins ${w.white}%, draw ${w.draw}%, Black wins ${w.black}%',
      excludeSemantics: true,
      child: SizedBox(
        height: 24,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
          child: Row(
            spacing: 10,
            children: [
              SizedBox(width: 72, child: Text('White ${w?.white ?? '–'}%', style: style)),
              Expanded(
                child: Container(
                  height: 6,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: const Color(0xFF1E2530),
                    border: Border.all(color: colors.bgElevated),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) => Row(
                      children: [
                        AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * (w?.white ?? 0) / 100,
                          color: const Color(0xFFEEF1F5),
                        ),
                        AnimatedContainer(
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          width: constraints.maxWidth * (w?.draw ?? 0) / 100,
                          color: const Color(0xFF7C8898),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Text('Draw ${w?.draw ?? '–'}% · Black ${w?.black ?? '–'}%', style: style),
            ],
          ),
        ),
      ),
    );
  }
}

/// Under the board: what Stockfish is doing, the material, Threat and the
/// engine switch.
class AnalysisStatusRow extends ConsumerWidget {
  const AnalysisStatusRow({super.key, required this.session});

  final AnalysisSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final analysis = session.analysis;
    final position = session.position;
    final best = analysis?.lines.firstOrNull;

    final String text;
    if (!session.engineOn) {
      text = 'off';
    } else if (session.failed) {
      text = 'didn’t answer';
    } else if (analysis != null && analysis.isTerminal) {
      text = position.isCheckmate ? 'checkmate' : 'no legal moves · draw';
    } else if (session.thinking) {
      text = 'thinking · depth ${analysis?.depth ?? 0} / ${AnalysisSession.targetDepth}';
    } else if (best?.score.mate case final mate? when mate != 0) {
      text = 'mate in ${mate.abs()} · d${analysis!.depth}';
    } else {
      text = 'depth ${analysis?.depth ?? 0}';
    }

    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s4, 0, AppSpacing.s2, 0),
        child: Row(
          spacing: AppSpacing.s2,
          children: [
            _EngineDot(
              thinking: session.engineOn && session.thinking,
              color: session.engineOn && (session.thinking || best?.score.mate != null)
                  ? colors.focus
                  : colors.textTertiary,
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Stockfish',
                      style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    TextSpan(text: ' · $text'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            ),
            Tooltip(
              message: 'Material balance',
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.bgElevated,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(materialText(position), style: type.mono.copyWith(fontSize: 12)),
              ),
            ),
            Semantics(
              toggled: session.threatOn,
              child: OutlinedButton.icon(
                onPressed: session.engineOn ? () => session.setThreat(on: !session.threatOn) : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  fixedSize: const Size.fromHeight(30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: const StadiumBorder(),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  foregroundColor: session.threatOn ? colors.coral : colors.textSecondary,
                  backgroundColor: session.threatOn ? colors.coral.withValues(alpha: 0.14) : null,
                  side: BorderSide(
                    color: session.threatOn ? colors.coral.withValues(alpha: 0.45) : colors.border,
                  ),
                  textStyle: type.label.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                icon: const Icon(Icons.north_east_rounded, size: 14),
                label: const Text('Threat'),
              ),
            ),
            Semantics(
              label: 'Engine',
              child: Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: session.engineOn,
                  onChanged: (on) => session.setEngine(on: on),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Breathes while Stockfish thinks; steady otherwise (and with reduced
/// motion).
class _EngineDot extends ConsumerStatefulWidget {
  const _EngineDot({required this.thinking, required this.color});

  final bool thinking;
  final Color color;

  @override
  ConsumerState<_EngineDot> createState() => _EngineDotState();
}

class _EngineDotState extends ConsumerState<_EngineDot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animate = widget.thinking && !shouldReduceMotion(context, ref);
    if (animate && !_pulse.isAnimating) {
      unawaited(_pulse.repeat(reverse: true));
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) => Opacity(
        opacity: 1 - 0.65 * _pulse.value,
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

/// A move just played that Stockfish rates an error: how much it cost, the
/// better move, and Take back.
class MoveFeedbackCard extends StatelessWidget {
  const MoveFeedbackCard({
    super.key,
    required this.node,
    required this.review,
    required this.session,
  });

  final AnalysisNode node;
  final MoveReview review;
  final AnalysisSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final quality = review.quality!;
    final colour = qualityColor(colors, quality);
    final before = session.analysisOf(node.before)!;
    final after = session.analysisOf(node.position)!;
    final beforeText = before.lines.isEmpty
        ? ''
        : whiteEvalText(before.lines.first.score, node.before.turn);
    final afterText = after.lines.isEmpty
        ? (node.position.isCheckmate ? '#' : '0.0')
        : whiteEvalText(after.lines.first.score, node.position.turn);
    final best = before.lines.isEmpty
        ? null
        : lineTokens(node.before, before.lines.first.pv, max: 1);
    final bestText = best == null || best.isEmpty ? null : best.map((t) => t.text).join(' ');

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colour.withValues(alpha: 0.45)),
        ),
        child: Row(
          spacing: 10,
          children: [
            QualityChip(quality: quality),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                spacing: 1,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${node.label} '),
                        TextSpan(
                          text: '$beforeText → $afterText',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.mono.copyWith(fontSize: 13),
                  ),
                  if (bestText != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Best was '),
                          TextSpan(
                            text: bestText,
                            style: type.mono.copyWith(fontSize: 12, color: colors.focus),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: session.takeBack,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
                fixedSize: const Size.fromHeight(40),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                backgroundColor: colors.bgRaised,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: type.label.copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text('Take back'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Stockfish's top lines (and the threat, when on). Tap a move to play the
/// line up to it.
class EngineLinesCard extends StatelessWidget {
  const EngineLinesCard({super.key, required this.session, required this.viewer});

  final AnalysisSession session;

  /// The side at the bottom: its pieces are "your" pieces in the threat line.
  final Side viewer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final light = Theme.of(context).brightness == Brightness.light;
    final position = session.position;
    final analysis = session.analysis;

    Widget note(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        text,
        style: type.label.copyWith(fontWeight: FontWeight.w400, color: colors.textSecondary),
      ),
    );

    final rows = <Widget>[];
    if (!session.engineOn) {
      rows.add(note('The engine is off. Turn it on to see Stockfish’s best lines.'));
    } else if (session.failed) {
      rows.add(note('Stockfish didn’t answer. Move or turn the engine off and on to try again.'));
    } else if (analysis != null && analysis.isTerminal) {
      rows.add(
        note(
          position.isCheckmate
              ? 'Checkmate. ${position.turn == Side.white ? 'Black' : 'White'} wins.'
              : 'Stalemate: no legal moves, so it’s a draw.',
        ),
      );
    } else {
      final lines = analysis?.lines ?? const <EngineLine>[];
      for (var i = 0; i < AnalysisSession.lineCount; i++) {
        final line = i < lines.length ? lines[i] : null;
        if (line == null && !session.thinking) break;
        rows.add(
          _LineRow(
            line: line,
            position: position,
            depth: analysis?.depth,
            first: i == 0,
            light: light,
            onPlay: (uci) => session.playLine(uci),
          ),
        );
      }
    }

    final threat = session.threat;
    return Semantics(
      container: true,
      label: 'Engine lines',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: colors.bgRaised,
          borderRadius: BorderRadius.circular(14),
          border: light ? Border.all(color: colors.border) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (session.threatOn && session.engineOn)
              Container(
                constraints: const BoxConstraints(minHeight: 32),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.bgElevated)),
                ),
                child: Row(
                  spacing: 8,
                  children: [
                    Icon(Icons.north_east_rounded, size: 16, color: colors.coral),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Threat: ',
                              style: TextStyle(fontWeight: FontWeight.w600, color: colors.coral),
                            ),
                            TextSpan(
                              text: threat == null
                                  ? (position.isCheck
                                        ? 'none while in check'
                                        : (session.thinking ? 'looking…' : 'nothing serious'))
                                  : threatText(position, threat, viewer: viewer),
                            ),
                          ],
                        ),
                        style: type.label.copyWith(fontSize: 12, fontWeight: FontWeight.w400),
                      ),
                    ),
                  ],
                ),
              ),
            for (final (i, row) in rows.indexed) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: colors.bgElevated),
              row,
            ],
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.line,
    required this.position,
    required this.depth,
    required this.first,
    required this.light,
    required this.onPlay,
  });

  /// Null while Stockfish hasn't found it yet (a shimmer).
  final EngineLine? line;
  final Position position;
  final int? depth;
  final bool first;
  final bool light;
  final ValueChanged<List<String>> onPlay;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final line = this.line;
    final white = line == null || whiteAhead(line.score, position.turn);
    final tokens = line == null ? const <LineToken>[] : lineTokens(position, line.pv);

    return SizedBox(
      height: 38,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          spacing: 8,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 48),
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: line == null
                    ? colors.bgElevated
                    : (white ? const Color(0xFFF5F7FA) : const Color(0xFF1E2530)),
                borderRadius: BorderRadius.circular(7),
                border: line == null
                    ? null
                    : Border.all(color: light ? const Color(0xFFD5DBE3) : const Color(0xFF2A3441)),
              ),
              child: line == null
                  ? null
                  : Text(
                      whiteEvalText(line.score, position.turn),
                      style: type.mono.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: white ? const Color(0xFF1E2530) : const Color(0xFFF5F7FA),
                      ),
                    ),
            ),
            Expanded(
              child: line == null
                  ? const Align(alignment: Alignment.centerLeft, child: _Shimmer())
                  : ClipRect(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final t in tokens)
                              t.isNumber
                                  ? Padding(
                                      padding: const EdgeInsets.only(left: 2),
                                      child: Text(
                                        t.text,
                                        style: type.mono.copyWith(
                                          fontSize: 13,
                                          color: colors.textTertiary,
                                        ),
                                      ),
                                    )
                                  : InkWell(
                                      borderRadius: BorderRadius.circular(6),
                                      onTap: () => onPlay(line.pv.take(t.index + 1).toList()),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 6,
                                        ),
                                        child: Text(
                                          t.text,
                                          style: type.mono.copyWith(
                                            fontSize: 13,
                                            fontWeight: t.index <= 1
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                            color: t.index <= 1
                                                ? colors.textPrimary
                                                : colors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                          ],
                        ),
                      ),
                    ),
            ),
            Text(
              line == null || depth == null ? '' : 'd$depth',
              style: type.mono.copyWith(fontSize: 11, color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends ConsumerStatefulWidget {
  const _Shimmer();

  @override
  ConsumerState<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends ConsumerState<_Shimmer> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = shouldReduceMotion(context, ref);
    if (!reduce && !_controller.isAnimating) unawaited(_controller.repeat(reverse: true));
    if (reduce) _controller.stop();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Opacity(
        opacity: reduce ? 0.6 : 0.45 + 0.45 * _controller.value,
        child: Container(
          height: 10,
          width: 180,
          decoration: BoxDecoration(
            color: context.colors.bgElevated,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ),
    );
  }
}

/// The moves explored: the main line, variations indented under the move
/// they replace. Tap to go there; long-press for the variation menu.
class AnalysisMoveList extends StatelessWidget {
  const AnalysisMoveList({
    super.key,
    required this.session,
    required this.emptyText,
    required this.onLongPress,
  });

  final AnalysisSession session;

  /// Shown before any move is played.
  final String emptyText;
  final void Function(AnalysisNode node, Offset globalPosition) onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final blocks = session.tree.blocks();
    final current = session.current;
    final mono = type.mono.copyWith(fontSize: 13);

    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Text(emptyText, style: mono.copyWith(color: colors.textTertiary)),
      );
    }

    return Semantics(
      container: true,
      label: 'Moves',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final block in blocks)
              Container(
                margin: EdgeInsets.only(left: 10.0 * block.depth),
                padding: EdgeInsets.only(left: block.depth > 0 ? 8 : 0),
                decoration: block.depth > 0
                    ? BoxDecoration(
                        border: Border(left: BorderSide(color: colors.border, width: 2)),
                      )
                    : null,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 1,
                  runSpacing: 2,
                  children: [
                    if (block.depth > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 2),
                        child: Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    for (final token in block.tokens)
                      if (token.node == null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(token.text, style: mono.copyWith(color: colors.textTertiary)),
                        )
                      else
                        _MoveChip(
                          text: token.text,
                          current: token.node == current,
                          variation: block.depth > 0,
                          quality: session.reviewOf(token.node!)?.quality,
                          onTap: () => session.goTo(token.node!),
                          onLongPress: (position) => onLongPress(token.node!, position),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoveChip extends StatelessWidget {
  const _MoveChip({
    required this.text,
    required this.current,
    required this.variation,
    required this.quality,
    required this.onTap,
    required this.onLongPress,
  });

  final String text;
  final bool current;
  final bool variation;
  final MoveQuality? quality;
  final VoidCallback onTap;
  final ValueChanged<Offset> onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      button: true,
      selected: current,
      label: '$text${quality == null ? '' : ', ${quality!.label}'}',
      excludeSemantics: true,
      child: GestureDetector(
        onLongPressStart: (d) => onLongPress(d.globalPosition),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: current ? colors.focus.withValues(alpha: 0.2) : null,
              borderRadius: BorderRadius.circular(6),
              border: current ? Border.all(color: colors.focus, width: 1.5) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 4,
              children: [
                Text(
                  text,
                  style: type.mono.copyWith(
                    fontSize: 13,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                    color: variation && !current ? colors.textSecondary : colors.textPrimary,
                  ),
                ),
                if (quality != null && (quality!.isError || quality == MoveQuality.brilliant))
                  QualityDisc(quality: quality!, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Start, back, the move shown, forward, end.
class AnalysisNavBar extends StatelessWidget {
  const AnalysisNavBar({super.key, required this.session});

  final AnalysisSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final node = session.current;
    final review = session.reviewOf(node);
    final atStart = node.isRoot;
    final atEnd = node.children.isEmpty;

    final title = node.isRoot ? 'Start' : '${node.label}${review?.quality?.symbol ?? ''}';
    final side = node.position.turn == Side.white ? 'White' : 'Black';
    final subtitle = node.isRoot
        ? (node.children.isEmpty ? 'no moves yet · $side to play' : 'start · $side to play')
        : '${node.isMainLine ? 'main line' : 'side line'} · $side to play';

    Widget button(IconData icon, String tooltip, VoidCallback? onPressed, {bool raised = false}) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon),
          style: IconButton.styleFrom(
            fixedSize: Size(raised ? 56 : 48, 44),
            foregroundColor: raised ? colors.textPrimary : colors.textSecondary,
            backgroundColor: raised ? colors.bgRaised : Colors.transparent,
            disabledForegroundColor: colors.textTertiary.withValues(alpha: 0.4),
            disabledBackgroundColor: raised ? colors.bgRaised : Colors.transparent,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.bgElevated)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Row(
          spacing: 4,
          children: [
            button(Icons.first_page, 'Go to start', atStart ? null : session.toStart),
            button(
              Icons.chevron_left,
              'Back one move',
              atStart ? null : session.back,
              raised: true,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.mono.copyWith(fontSize: 14),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.label.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            button(
              Icons.chevron_right,
              'Forward one move',
              atEnd ? null : session.forward,
              raised: true,
            ),
            button(Icons.last_page, 'Go to end', atEnd ? null : session.toEnd),
          ],
        ),
      ),
    );
  }
}
