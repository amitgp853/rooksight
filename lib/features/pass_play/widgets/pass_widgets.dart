import 'dart:ui' show ImageFilter;

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../play/widgets/clock_view.dart';
import '../domain/pass_config.dart';
import '../domain/pass_session.dart';
import 'pass_copy.dart';
import 'side_chip.dart';

String colourName(Side side) => side == Side.white ? 'White' : 'Black';

/// What a player's line says under their name: "Your move · White",
/// "Black · waiting", "White · paused", "White · winner".
({String text, bool active}) playerStatus(PassSession session, Side side) {
  final game = session.game;
  final colour = colourName(side);
  if (game.isOver) {
    final won = game.result!.winner == side;
    return (text: won ? '$colour · winner' : colour, active: won);
  }
  if (session.paused) return (text: '$colour · paused', active: false);
  if (game.turn != side) return (text: '$colour · waiting', active: false);
  return (
    text: game.checkedKing != null ? 'In check · $colour' : 'Your move · $colour',
    active: true,
  );
}

/// One player's line above or below the board (`PassGame.dc.html`): colour
/// chip with their initial, name, status and clock.
class PassPlayerRow extends StatelessWidget {
  const PassPlayerRow({super.key, required this.session, required this.side});

  final PassSession session;
  final Side side;

  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final name = session.config.nameOf(side);
    final status = playerStatus(session, side);
    final inCheck = status.active && session.game.checkedKing != null;
    final clock = session.clock;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter),
        child: Row(
          spacing: AppSpacing.s3,
          children: [
            SideChip(side: side, size: 38, initial: initialOf(name)),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    status.text,
                    style: type.label.copyWith(
                      fontSize: 12,
                      fontWeight: status.active ? FontWeight.w600 : FontWeight.w400,
                      color: inCheck
                          ? colors.coral
                          : status.active
                          ? colors.focus
                          : colors.textTertiary,
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
                style: ClockStyle.largeBox,
              ),
          ],
        ),
      ),
    );
  }
}

/// Covers the board while paused, so nobody gets extra thinking time.
class PausedOverlay extends StatelessWidget {
  const PausedOverlay({
    super.key,
    required this.toMove,
    required this.onResume,
    required this.onLeave,
  });

  /// The name of the player to move.
  final String toMove;
  final VoidCallback onResume;

  /// "Save and finish later".
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: ColoredBox(
          color: colors.bgBase.withValues(alpha: 0.82),
          child: Center(
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: 'Game paused',
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.bgRaised,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s3,
                  children: [
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: colors.bgElevated, shape: BoxShape.circle),
                        child: Icon(Icons.pause_rounded, color: colors.focus),
                      ),
                    ),
                    Text(
                      'Game paused',
                      textAlign: TextAlign.center,
                      style: type.heading.copyWith(fontSize: 20, height: 26 / 20),
                    ),
                    Text(
                      'Both clocks are stopped. The board is hidden so nobody gets extra '
                      'thinking time.',
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(
                        fontSize: 14,
                        height: 20 / 14,
                        color: colors.textSecondary,
                      ),
                    ),
                    FilledButton(
                      onPressed: onResume,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                        textStyle: type.heading.copyWith(fontSize: 15),
                      ),
                      child: Text('Resume · $toMove to move'),
                    ),
                    TextButton(onPressed: onLeave, child: const Text('Save and finish later')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A takeback or draw offer waiting for the other player: scrim plus a sheet
/// from the bottom edge. [turned] shows it upside down, from the top edge,
/// for the player across the table.
class RequestOverlay extends StatelessWidget {
  const RequestOverlay({
    super.key,
    required this.session,
    required this.request,
    required this.onAnswer,
    this.turned = false,
  });

  final PassSession session;
  final PassRequest request;
  final void Function({required bool accept}) onAnswer;
  final bool turned;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final isDraw = request.kind == PassRequestKind.draw;
    final answerer = session.config.nameOf(request.answerer);
    // "You" is the phone's owner: "Do you accept?", not "You, do you accept?".
    final answererIsYou = answerer == PassConfig.defaultFirstName;
    final question = isDraw ? 'accept' : 'agree';
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    final sheet = Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        10,
        AppSpacing.gutter,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, -16)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s4,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.s3,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      (isDraw ? 'Draw offer' : 'Takeback').toUpperCase(),
                      style: type.overline.copyWith(color: colors.brass),
                    ),
                    Text(
                      requestTitle(session, request),
                      style: type.title.copyWith(fontSize: 26, height: 32 / 26),
                    ),
                    Text(
                      answererIsYou ? 'Do you $question?' : '$answerer, do you $question?',
                      style: type.body.copyWith(height: 21 / 15, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isDraw)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text('½–½', style: type.mono.copyWith(fontSize: 22)),
                ),
            ],
          ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onAnswer(accept: false),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: colors.bgElevated,
                    shape: buttonShape,
                    textStyle: type.heading.copyWith(fontSize: 15),
                  ),
                  child: const Text('Decline'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: () => onAnswer(accept: true),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: buttonShape,
                    textStyle: type.heading.copyWith(fontSize: 15),
                  ),
                  child: Text(isDraw ? 'Accept draw' : 'Allow takeback'),
                ),
              ),
            ],
          ),
          Text(
            turned
                ? 'Clocks keep running.'
                : answererIsYou
                ? 'Hand the phone back to answer. Clocks keep running.'
                : 'Hand the phone to $answerer to answer. Clocks keep running.',
            textAlign: TextAlign.center,
            style: type.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );

    final overlay = Stack(
      children: [
        // The same scrim as other sheets; it doesn't dismiss: someone must answer.
        const Positioned.fill(child: ModalBarrier(color: Color(0x8C080B0F), dismissible: false)),
        Align(alignment: Alignment.bottomCenter, child: sheet),
      ],
    );
    return turned ? RotatedBox(quarterTurns: 2, child: overlay) : overlay;
  }
}

/// "Board turned for Opponent. Pass the phone."
class HandoffBanner extends StatelessWidget {
  const HandoffBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: colors.focus.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.focus.withValues(alpha: 0.35)),
        ),
        child: Row(
          spacing: AppSpacing.s3,
          children: [
            Icon(Icons.swap_vert_rounded, size: 20, color: colors.focus),
            Expanded(
              child: Text(
                text,
                style: context.type.body.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  color: Color.lerp(colors.focus, colors.textPrimary, 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
