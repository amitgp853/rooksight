import 'dart:async';

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
import '../../core/widgets/dialog_buttons.dart';
import '../../core/widgets/move_wise_sheet.dart';
import '../play/domain/move_feedback.dart';
import '../play/widgets/clock_view.dart';
import '../play/widgets/game_actions.dart';
import '../play/widgets/move_strip.dart';
import 'domain/pass_controller.dart';
import 'domain/pass_session.dart';
import 'widgets/pass_board.dart';
import 'widgets/pass_copy.dart';
import 'widgets/pass_result_sheet.dart';
import 'widgets/pass_widgets.dart';
import 'widgets/side_chip.dart';

/// Two players on one phone (`PassGame.dc.html`; face-to-face:
/// `PassTabletop.dc.html`). Fully offline.
class PassGameScreen extends ConsumerStatefulWidget {
  const PassGameScreen({super.key});

  @override
  ConsumerState<PassGameScreen> createState() => _PassGameScreenState();
}

class _PassGameScreenState extends ConsumerState<PassGameScreen> {
  /// The final position stays in view this long before the result sheet.
  static const _resultHold = Duration(milliseconds: 600);

  /// With auto-flip, the board turns this long after a move lands.
  static const _flipDelay = Duration(milliseconds: 400);

  late Side _orientation = _restingOrientation(ref.read(passControllerProvider));

  /// The board has just turned for the next player: "Pass the phone".
  bool _handoff = false;

  late final AppLifecycleListener _lifecycle;
  Timer? _resultTimer;
  Timer? _flipTimer;

  /// The last move was dropped by drag: it lands without sliding.
  bool _dropped = false;

  /// The landing sound and haptic, due when the sliding piece arrives.
  Timer? _landingTimer;
  VoidCallback? _landing;

  @override
  void initState() {
    super.initState();
    // Leaving the app pauses the game: both clocks stop, the board hides.
    _lifecycle = AppLifecycleListener(
      onHide: () => ref.read(passControllerProvider.notifier).pause(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _resultTimer?.cancel();
    _flipTimer?.cancel();
    _landingTimer?.cancel();
    super.dispose();
  }

  bool get _reduceMotion => shouldReduceMotion(context, ref);

  /// Where the board sits when nothing is moving: facing the player to move
  /// with auto-flip, otherwise facing the first player.
  static Side _restingOrientation(PassSession session) =>
      session.config.autoFlip ? session.game.turn : session.config.firstSide;

  void _showResult() => showMoveWiseSheet<void>(
    context,
    reduceMotion: _reduceMotion,
    builder: (_) => const PassResultSheet(),
  );

  /// Plays a landing still due at once, so a quick next move leaves none out.
  void _landNow() {
    _landingTimer?.cancel();
    final landing = _landing;
    _landing = null;
    landing?.call();
  }

  /// Sound and haptic for each move, the board turning for the next player,
  /// and the result sheet at the end.
  void _onSessionChange(PassSession? previous, PassSession next) {
    final before = previous?.game;
    final game = next.game;
    if (before == null) return;

    if (game.moves.length == before.moves.length + 1) {
      final move = game.moves.last;
      // A check lands hardest on the player who now has to answer it.
      final feedback = MoveFeedback.of(move, playerSide: move.side.opposite, gameOver: game.isOver);
      final slides = !_reduceMotion && !_dropped;
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

      _flipTimer?.cancel();
      setState(() => _handoff = false);
      if (next.config.autoFlip && !game.isOver) {
        _flipTimer = Timer((slides ? moveSlide : Duration.zero) + _flipDelay, () {
          if (!mounted) return;
          final session = ref.read(passControllerProvider);
          setState(() {
            _orientation = _restingOrientation(session);
            _handoff = true;
          });
        });
      }
    } else if (game.moves.length < before.moves.length) {
      // A takeback, or a rematch: straight back to the resting position.
      _flipTimer?.cancel();
      setState(() {
        _orientation = _restingOrientation(next);
        _handoff = false;
      });
    }

    if (game.isOver && !before.isOver) {
      if (game.moves.length == before.moves.length) ref.haptic(Haptic.medium);
      _resultTimer?.cancel();
      _resultTimer = Timer(_resultHold, () {
        if (mounted && ref.read(passControllerProvider).game.isOver) _showResult();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passControllerProvider, _onSessionChange);
    final session = ref.watch(passControllerProvider);
    final controller = ref.read(passControllerProvider.notifier);
    final request = session.request;

    final layout = session.config.faceToFace
        ? _FaceToFace(session: session, onShowResult: _showResult)
        : _Standard(
            session: session,
            orientation: _orientation,
            handoff: _handoff,
            onMove: ({required dragged}) => _dropped = dragged,
            onShowResult: _showResult,
          );

    return Stack(
      children: [
        layout,
        if (request != null)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: RequestOverlay(
                session: session,
                request: request,
                onAnswer: controller.answer,
                // Face to face, the offer turns towards the player across.
                turned: session.config.faceToFace && request.answerer != session.config.firstSide,
              ),
            ),
          ),
      ],
    );
  }
}

/// The board, with the pause card over it while paused.
class _BoardArea extends ConsumerWidget {
  const _BoardArea({
    required this.session,
    required this.orientation,
    required this.size,
    this.onMove,
    this.facePlayerToMove = false,
  });

  final PassSession session;
  final Side orientation;
  final double size;
  final void Function({required bool dragged})? onMove;

  /// Face to face: pieces face the player to move, across the table too.
  final bool facePlayerToMove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(passControllerProvider.notifier);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          PassBoard(
            orientation: orientation,
            size: size,
            onMove: onMove,
            facePlayerToMove: facePlayerToMove,
          ),
          if (session.paused)
            Positioned.fill(
              child: PausedOverlay(
                toMove: session.config.nameOf(session.game.turn),
                onResume: controller.resume,
                onLeave: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// One phone passed between the players: name rows, board, moves, actions.
class _Standard extends ConsumerWidget {
  const _Standard({
    required this.session,
    required this.orientation,
    required this.handoff,
    required this.onMove,
    required this.onShowResult,
  });

  final PassSession session;
  final Side orientation;
  final bool handoff;
  final void Function({required bool dragged}) onMove;
  final VoidCallback onShowResult;

  static const _actionBarHeight = 8.0 + 64 + 24;
  static const _reservedHeight =
      2 * PassPlayerRow.height + MoveStrip.height + _actionBarHeight + 56;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(passControllerProvider.notifier);
    final game = session.game;
    final toMove = game.turn;

    final Widget? message;
    if (game.isOver) {
      message = _Notice(
        text: passResultCopy(session).title,
        action: TextButton(onPressed: onShowResult, child: const Text('See result')),
      );
    } else if (session.notice case final notice?) {
      message = _Notice(text: notice);
    } else if (handoff && orientation == toMove && !session.paused) {
      message = HandoffBanner(
        text: 'Board turned for ${session.config.nameOf(toMove)}. Pass the phone.',
      );
    } else {
      message = null;
    }

    return Scaffold(
      appBar: _PassAppBar(session: session),
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
                // The board and name rows swap with a quick crossfade.
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Column(
                    key: ValueKey(orientation),
                    children: [
                      PassPlayerRow(session: session, side: orientation.opposite),
                      _BoardArea(
                        session: session,
                        orientation: orientation,
                        size: boardSize,
                        onMove: onMove,
                      ),
                      PassPlayerRow(session: session, side: orientation),
                    ],
                  ),
                ),
                MoveStrip(game: game),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.gutter,
                      vertical: 10,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        child: message ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  child: Row(
                    spacing: AppSpacing.s2,
                    children: [
                      Expanded(
                        child: GameActionButton(
                          icon: Icons.pause_rounded,
                          label: 'Pause',
                          pressed: session.paused,
                          onPressed: game.isOver
                              ? null
                              : session.paused
                              ? controller.resume
                              : controller.pause,
                        ),
                      ),
                      Expanded(
                        child: GameActionButton(
                          icon: Icons.undo_rounded,
                          label: 'Takeback',
                          onPressed: session.takebackSide == null
                              ? null
                              : controller.requestTakeback,
                        ),
                      ),
                      Expanded(
                        // Offered by the player to move, who holds the phone.
                        child: GameActionButton(
                          icon: Icons.drag_handle_rounded,
                          label: 'Draw',
                          pressed: session.request?.kind == PassRequestKind.draw,
                          onPressed: session.canOfferDraw(toMove)
                              ? () => _confirmDraw(context, session, toMove, controller)
                              : null,
                        ),
                      ),
                      Expanded(
                        child: GameActionButton(
                          icon: Icons.flag_outlined,
                          label: 'Resign',
                          onPressed: session.canMove
                              ? () => _confirmResign(context, session, toMove, controller)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// "Pass & play" over the clock, with a back button.
class _PassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PassAppBar({required this.session});

  final PassSession session;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final timeControl = session.config.timeControl;
    return AppBar(
      leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
      centerTitle: true,
      title: Column(
        children: [
          Text('Pass & Play', style: type.heading.copyWith(fontSize: 16, height: 22 / 16)),
          Text(
            '${timeControl.hasClock ? '${timeControl.kind} ${timeControl.label}' : 'No clock'}'
            ' · offline',
            style: type.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
      // Keeps the title centred against the back button.
      actions: const [SizedBox(width: 56)],
    );
  }
}

/// The phone flat between the players: a panel each, the top one turned
/// towards the player across, and a board that never flips.
class _FaceToFace extends ConsumerWidget {
  const _FaceToFace({required this.session, required this.onShowResult});

  final PassSession session;
  final VoidCallback onShowResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final near = session.config.firstSide;
    final over = session.game.isOver;
    return Scaffold(
      // Once the game is over nobody is across the table any more: a normal
      // header, and the result button only on the near side.
      appBar: over ? _PassAppBar(session: session) : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardSize = [
              constraints.maxWidth,
              constraints.maxHeight - 2 * _TablePanel.minHeight,
            ].reduce((a, b) => a < b ? a : b).clamp(0.0, double.infinity);
            return Column(
              children: [
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: _TablePanel(
                      session: session,
                      side: near.opposite,
                      onShowResult: onShowResult,
                      across: true,
                    ),
                  ),
                ),
                _BoardArea(
                  session: session,
                  orientation: near,
                  size: boardSize,
                  // The pieces turn to face whoever's move it is, until the end.
                  facePlayerToMove: !over,
                ),
                Expanded(
                  child: _TablePanel(session: session, side: near, onShowResult: onShowResult),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One player's half of the table: name, big clock, and their own buttons.
class _TablePanel extends ConsumerWidget {
  const _TablePanel({
    required this.session,
    required this.side,
    required this.onShowResult,
    this.across = false,
  });

  final PassSession session;
  final Side side;
  final VoidCallback onShowResult;

  /// The panel turned towards the player across the table.
  final bool across;

  static const minHeight = 176.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(passControllerProvider.notifier);
    final colors = context.colors;
    final type = context.type;
    final game = session.game;
    final name = session.config.nameOf(side);
    final status = playerStatus(session, side);
    final active = !game.isOver && game.turn == side;
    final clock = session.clock;
    final buttonFill = active
        ? Color.alphaBlend(colors.focus.withValues(alpha: 0.2), colors.bgRaised)
        : colors.bgElevated;
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final label = type.label.copyWith(fontWeight: FontWeight.w600);

    Widget action(String text, VoidCallback? onPressed) => Expanded(
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          padding: EdgeInsets.zero,
          backgroundColor: buttonFill,
          foregroundColor: colors.textPrimary,
          shape: buttonShape,
          textStyle: label,
        ),
        child: Text(text),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: active
            ? Color.alphaBlend(colors.focus.withValues(alpha: 0.12), colors.bgRaised)
            : colors.bgRaised,
        border: Border(
          top: BorderSide(color: active ? colors.focus : Colors.transparent, width: 3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            spacing: AppSpacing.s3,
            children: [
              // Either player can leave; the game is kept for later. Once
              // it's over, the header has the back button.
              if (!game.isOver)
                SizedBox.square(
                  dimension: 40,
                  child: IconButton(
                    tooltip: 'Leave game',
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    color: colors.textSecondary,
                    icon: const Icon(Icons.arrow_back_rounded, size: 22),
                  ),
                ),
              SideChip(side: side, size: 40, initial: initialOf(name)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      session.notice ?? status.text,
                      style: type.label.copyWith(
                        fontSize: 12,
                        fontWeight: status.active ? FontWeight.w600 : FontWeight.w400,
                        color: status.active ? colors.focus : colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (clock != null)
                ClockView(
                  clock: clock,
                  side: side,
                  owner: possessive(name),
                  style: ClockStyle.digits,
                ),
            ],
          ),
          if (game.isOver)
            across ? const SizedBox.shrink() : Row(children: [action('See result', onShowResult)])
          else
            Row(
              spacing: AppSpacing.s2,
              children: [
                // Either player can pause; filled for the player to move.
                SizedBox(
                  width: 56,
                  height: 48,
                  child: IconButton(
                    tooltip: 'Pause both clocks',
                    onPressed: session.paused ? null : controller.pause,
                    style: IconButton.styleFrom(
                      shape: buttonShape,
                      backgroundColor: active ? colors.focus : colors.bgElevated,
                      foregroundColor: active ? colors.onFocus : colors.textPrimary,
                    ),
                    icon: const Icon(Icons.pause_rounded, size: 24),
                  ),
                ),
                action(
                  'Takeback',
                  session.takebackSide == side ? controller.requestTakeback : null,
                ),
                action(
                  'Offer draw',
                  session.canOfferDraw(side)
                      ? () => _confirmDraw(context, session, side, controller, turned: across)
                      : null,
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: session.canMove
                        ? () => _confirmResign(context, session, side, controller, turned: across)
                        : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: EdgeInsets.zero,
                      foregroundColor: colors.coral,
                      side: BorderSide(color: colors.coral.withValues(alpha: active ? 0.5 : 0.4)),
                      shape: buttonShape,
                      textStyle: label,
                    ),
                    child: const Text('Resign'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A rounded message under the moves, with an optional action.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.s3),
      decoration: BoxDecoration(
        color: colors.bgRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          Expanded(
            child: Text(text, style: context.type.body.copyWith(fontSize: 14, height: 20 / 14)),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Resigning ends the game at once: asked first, since a stray tap happens.
Future<void> _confirmResign(
  BuildContext context,
  PassSession session,
  Side side,
  PassController controller, {
  bool turned = false,
}) async {
  final name = session.config.nameOf(side);
  final winner = session.config.nameOf(side.opposite);
  final ok = await _confirm(
    context,
    title: 'Resign this game?',
    body: '$name resigns and $winner wins. This can’t be undone.',
    action: 'Resign',
    danger: true,
    turned: turned,
  );
  if (ok) controller.resign(side);
}

/// Offering a draw hands the phone's question to the other player: asked
/// first, so a stray tap doesn't.
Future<void> _confirmDraw(
  BuildContext context,
  PassSession session,
  Side side,
  PassController controller, {
  bool turned = false,
}) async {
  final other = session.config.nameOf(side.opposite);
  final ok = await _confirm(
    context,
    title: 'Offer a draw?',
    body: '$other will be asked to accept or decline.',
    action: 'Offer draw',
    turned: turned,
  );
  if (ok) controller.offerDraw(side);
}

/// A yes/no question in the app's dialog style. [turned] shows it upside
/// down, for the player across the table.
Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool danger = false,
  bool turned = false,
}) async {
  final answer = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      final type = context.type;
      final dialog = AlertDialog(
        backgroundColor: colors.bgRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: type.heading),
        content: Text(body, style: type.body.copyWith(color: colors.textSecondary)),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        actions: [
          ConfirmRow(
            onCancel: () => Navigator.of(context).pop(false),
            action: danger
                ? DestructiveButton(label: action, onPressed: () => Navigator.of(context).pop(true))
                : ConfirmButton(label: action, onPressed: () => Navigator.of(context).pop(true)),
          ),
        ],
      );
      return turned ? RotatedBox(quarterTurns: 2, child: dialog) : dialog;
    },
  );
  return answer ?? false;
}
