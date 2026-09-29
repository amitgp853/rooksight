import 'dart:async';
import 'dart:math' as math;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/board/board_style.dart';
import '../../core/feedback/haptics.dart';
import '../../core/feedback/sound_player.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/settings/display_settings.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/move_wise_sheet.dart';
import 'domain/game_controller.dart';
import 'domain/game_session.dart';
import 'domain/move_feedback.dart';
import 'widgets/game_actions.dart';
import 'widgets/game_board.dart';
import 'widgets/game_sheets.dart';
import 'widgets/move_strip.dart';
import 'widgets/player_row.dart';
import 'widgets/result_copy.dart';

/// A game against Stockfish (`design/source/Game.dc.html`, every state in
/// `GameScreen.dc.html`).
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  /// Player rows, move strip and action bar; the board gets the rest, up to
  /// the full width.
  static const _reservedHeight = 2 * PlayerRow.height + MoveStrip.height + _ActionBar.height;

  /// The final position stays in view this long before the result sheet.
  static const _resultHold = Duration(milliseconds: 600);

  late Side _orientation = ref.read(gameControllerProvider).config.playerSide;
  late final AppLifecycleListener _lifecycle;
  Timer? _resultTimer;

  /// The player's last move was dropped by drag: it lands without sliding.
  bool _dropped = false;

  /// The landing sound and haptic, due when the sliding piece arrives.
  Timer? _landingTimer;
  VoidCallback? _landing;

  /// Plays a landing still due at once, so a quick next move leaves none out.
  void _landNow() {
    _landingTimer?.cancel();
    final landing = _landing;
    _landing = null;
    landing?.call();
  }

  @override
  void initState() {
    super.initState();
    // Pause the clocks while the app is in the background.
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(gameControllerProvider.notifier).pauseClock(),
      onShow: () => ref.read(gameControllerProvider.notifier).resumeClock(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _resultTimer?.cancel();
    _landingTimer?.cancel();
    super.dispose();
  }

  bool get _reduceMotion => shouldReduceMotion(context, ref);

  void _showOptions() => showMoveWiseSheet<void>(
    context,
    reduceMotion: _reduceMotion,
    builder: (_) => const OptionsSheet(),
  );

  void _showResult() => showMoveWiseSheet<void>(
    context,
    reduceMotion: _reduceMotion,
    builder: (_) => const ResultSheet(),
  );

  /// Sound and haptic for each move, from either side, as the piece lands:
  /// after its slide, or at once when dropped by drag or with reduced motion.
  void _onSessionChange(GameSession? previous, GameSession next) {
    final before = previous?.game;
    final game = next.game;
    if (before == null) return;
    if (game.moves.length == before.moves.length + 1) {
      final move = game.moves.last;
      final feedback = MoveFeedback.of(
        move,
        playerSide: next.config.playerSide,
        gameOver: game.isOver,
      );
      final slides = !_reduceMotion && !(move.side == next.config.playerSide && _dropped);
      _dropped = false;
      final sounds = ref.read(soundEnabledProvider) ? ref.read(soundPlayerProvider) : null;

      void land() {
        sounds?.play(feedback.sound);
        ref.haptic(feedback.haptic);
      }

      _landNow();
      if (slides) {
        _landing = land;
        _landingTimer = Timer(moveSlide, _landNow);
      } else {
        land();
      }
    } else if (game.isOver && !before.isOver) {
      ref.haptic(Haptic.medium); // Resignation, timeout or agreed draw.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameControllerProvider, _onSessionChange);
    ref.listen(gameControllerProvider.select((s) => s.game.isOver), (wasOver, isOver) {
      _resultTimer?.cancel();
      if (isOver && wasOver != true) {
        _resultTimer = Timer(_resultHold, () {
          if (mounted && ref.read(gameControllerProvider).game.isOver) _showResult();
        });
      }
    });

    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final colors = context.colors;
    final type = context.type;
    final config = session.config;
    final timeControl = config.timeControl;
    final subtitle = [
      if (timeControl.hasClock) '${timeControl.kind} ${timeControl.label}' else 'No clock',
      if (config.practice) 'Practice',
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'vs Stockfish · ${config.level.elo}',
              style: type.heading.copyWith(fontSize: 16, height: 22 / 16),
            ),
            Text(
              subtitle,
              style: type.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Game options',
            icon: const Icon(Icons.more_horiz),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Full width on a phone; smaller when the height can't fit it.
            final boardSize = [
              constraints.maxWidth,
              constraints.maxHeight - _reservedHeight,
            ].reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);

            return Column(
              children: [
                // Flip: the board and name rows swap with a quick crossfade.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Column(
                    key: ValueKey(_orientation),
                    children: [
                      PlayerRow(session: session, side: _orientation.opposite),
                      GameBoard(
                        orientation: _orientation,
                        size: boardSize,
                        onPlayerMove: ({required dragged}) => _dropped = dragged,
                      ),
                      PlayerRow(session: session, side: _orientation),
                    ],
                  ),
                ),
                MoveStrip(game: session.game),
                Expanded(
                  child: _MessageArea(session: session, onShowResult: _showResult),
                ),
                _ActionBar(
                  session: session,
                  onHint: controller.requestHint,
                  onUndo: controller.undo,
                  onLockedUndo: _showOptions,
                  onFlip: () => setState(() => _orientation = _orientation.opposite),
                  onMore: _showOptions,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Hint text, notices, engine errors, or the result once the sheet is closed.
class _MessageArea extends ConsumerWidget {
  const _MessageArea({required this.session, required this.onShowResult});

  final GameSession session;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;

    final Widget? message;
    if (session.engineError) {
      message = _EngineErrorCard(onRetry: ref.read(gameControllerProvider.notifier).retryEngine);
    } else if (session.game.isOver) {
      message = _Toast(
        text: ResultCopy.of(session).title,
        action: TextButton(onPressed: onShowResult, child: const Text('See result')),
      );
    } else if (session.notice case final notice?) {
      message = _Toast(text: notice);
    } else if (session.hint case final hint?) {
      message = _Toast(tint: colors.brass, icon: Icons.lightbulb_outline, text: hint.text);
    } else {
      message = null;
    }

    // Centred when it fits; scrolls on short screens (the error card is tall).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: 10),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: math.max(0, constraints.maxHeight - 20)),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: message == null
                  ? const SizedBox.shrink()
                  : DefaultTextStyle(
                      style: type.body.copyWith(fontSize: 14, height: 20 / 14),
                      child: message,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stockfish failed to reply (`IX21-EngineError.dc.html`).
class _EngineErrorCard extends StatelessWidget {
  const _EngineErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.coral.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.coral.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s3,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'Stockfish didn’t answer.',
                  style: type.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Color.lerp(colors.coral, colors.textPrimary, 0.35),
                  ),
                ),
                Text(
                  'Your game is saved. Ask again, or come back to it later from Home.',
                  style: type.label.copyWith(
                    fontWeight: FontWeight.w400,
                    height: 19 / 13,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: type.heading.copyWith(fontSize: 14),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A rounded message. With a [tint] (brass for hints, coral for errors) it
/// takes a light wash of that colour; otherwise it sits on a raised surface.
class _Toast extends StatelessWidget {
  const _Toast({required this.text, this.tint, this.icon, this.action});

  final String text;
  final Color? tint;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tint = this.tint;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: 0.10) ?? colors.bgRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tint?.withValues(alpha: 0.35) ?? colors.border),
      ),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          if (icon != null) Icon(icon, size: 20, color: tint),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                // Hint text: brass softened towards the body colour.
                color: tint == null
                    ? colors.textPrimary
                    : Color.lerp(tint, colors.textPrimary, 0.55),
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.session,
    required this.onHint,
    required this.onUndo,
    required this.onLockedUndo,
    required this.onFlip,
    required this.onMore,
  });

  static const height = 8.0 + 64 + 24;

  final GameSession session;
  final VoidCallback onHint;
  final VoidCallback onUndo;
  final VoidCallback onLockedUndo;
  final VoidCallback onFlip;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final canHint = session.isPlayerTurn && session.hint == null;
    final practice = session.config.practice;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      child: Row(
        spacing: AppSpacing.s2,
        children: [
          Expanded(
            child: GameActionButton(
              icon: Icons.lightbulb_outline,
              label: 'Hint',
              brass: true,
              onPressed: canHint ? onHint : null,
            ),
          ),
          Expanded(
            // Outside practice mode Undo is locked; tapping it offers practice.
            child: GameActionButton(
              icon: Icons.undo,
              label: 'Undo',
              locked: !practice,
              onPressed: !practice ? onLockedUndo : (session.canUndo ? onUndo : null),
            ),
          ),
          Expanded(
            child: GameActionButton(icon: Icons.swap_vert, label: 'Flip', onPressed: onFlip),
          ),
          Expanded(
            child: GameActionButton(icon: Icons.more_horiz, label: 'More', onPressed: onMore),
          ),
        ],
      ),
    );
  }
}
