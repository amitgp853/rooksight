// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dialog_buttons.dart';
import '../../engine/elo_levels.dart';
import 'domain/game_config.dart';
import 'domain/unfinished_game.dart';
import 'widgets/setup_controls.dart';

/// New game: Stockfish strength, colour and time control
/// (`design/source/PlaySetup.dc.html`).
class PlaySetupScreen extends ConsumerStatefulWidget {
  const PlaySetupScreen({super.key, this.startFen});

  /// The game starts from this position (e.g. "Play from here" on the
  /// analysis board); the standard start when null or not a legal position.
  final String? startFen;

  /// The position the game starts from.
  Position get startPosition {
    final fen = startFen;
    if (fen == null) return Chess.initial;
    try {
      return Chess.fromSetup(Setup.parseFen(fen));
    } on Object {
      return Chess.initial;
    }
  }

  @override
  ConsumerState<PlaySetupScreen> createState() => _PlaySetupScreenState();
}

class _PlaySetupScreenState extends ConsumerState<PlaySetupScreen> {
  late final GameConfig _previous = ref.read(gameConfigProvider);
  late EloLevel _level = _previous.level;
  late TimeControl _timeControl = _previous.timeControl;
  // From a given position, you play the side to move by default.
  late ColourChoice _colour =
      (widget.startFen != null ? widget.startPosition.turn : _previous.playerSide) == Side.white
      ? ColourChoice.white
      : ColourChoice.black;

  Future<void> _start() async {
    final unfinished = ref.read(unfinishedGameProvider);
    if (unfinished != null) {
      final abandon = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.colors.bgRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Abandon your current game?'),
          content: Text(
            'Your game vs Stockfish ${unfinished.config.level.elo} is saved on Home. '
            'Starting a new one ends it.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            ConfirmRow(
              cancelLabel: 'Keep it',
              onCancel: () => Navigator.of(context).pop(false),
              action: DestructiveButton(
                label: 'Start new',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      );
      if (abandon != true || !mounted) return;
      ref.read(unfinishedGameProvider.notifier).clear();
    }
    ref
        .read(gameConfigProvider.notifier)
        .set(
          _previous.copyWith(
            level: _level,
            playerSide: _colour.resolve(Random()),
            timeControl: _timeControl,
            // Set every time, so a position from the analysis board doesn't
            // carry over to the next ordinary game.
            startPosition: widget.startPosition,
          ),
        );
    // Replace setup, so Back from the game returns Home.
    context.pushReplacement(Routes.game);
  }

  String get _summary {
    final colour = switch (_colour) {
      ColourChoice.random => 'random colour',
      ColourChoice.white => 'you play White',
      ColourChoice.black => 'you play Black',
    };
    final clock = _timeControl.hasClock ? 'your clock ${_timeControl.label}' : 'no clock';
    return 'Stockfish ${_level.elo} · $colour · $clock';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;

    return Scaffold(
      appBar: AppBar(title: const Text('New Game')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.s2,
                  AppSpacing.gutter,
                  AppSpacing.s6,
                ),
                children: [
                  _StrengthCard(level: _level, onChanged: (l) => setState(() => _level = l)),
                  const SizedBox(height: 28),
                  const SectionOverline('Play as'),
                  const SizedBox(height: AppSpacing.s3),
                  _ColourPicker(value: _colour, onChanged: (c) => setState(() => _colour = c)),
                  const SizedBox(height: 28),
                  const SectionOverline('Your clock'),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    'Only you are timed. Stockfish plays without a clock.',
                    style: type.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s3),
                  TimeControlGrid(
                    options: TimeControl.options,
                    value: _timeControl,
                    onChanged: (t) => setState(() => _timeControl = t),
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.bgElevated)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.s4,
                  AppSpacing.gutter,
                  AppSpacing.s3,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s3,
                  children: [
                    Text(
                      _summary,
                      textAlign: TextAlign.center,
                      style: type.label.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    FilledButton(
                      onPressed: _start,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: type.heading,
                      ),
                      child: const Text('Start game'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrengthCard extends StatelessWidget {
  const _StrengthCard({required this.level, required this.onChanged});

  final EloLevel level;
  final ValueChanged<EloLevel> onChanged;

  static const _levels = EloLevel.all;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final index = _levels.indexOf(level);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(20)),
      child: Column(
        spacing: AppSpacing.s3,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionOverline('Stockfish strength'),
              Text(
                level.label,
                style: type.label.copyWith(
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove,
                label: 'Decrease by 200',
                onPressed: index > 0 ? () => onChanged(_levels[index - 1]) : null,
              ),
              Column(
                children: [
                  Text(
                    '${level.elo}',
                    style: type.display.copyWith(
                      fontSize: 56,
                      height: 60 / 56,
                      letterSpacing: 56 * -0.03,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    'Elo',
                    style: type.label.copyWith(
                      color: colors.textTertiary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              _StepButton(
                icon: Icons.add,
                label: 'Increase by 200',
                onPressed: index < _levels.length - 1 ? () => onChanged(_levels[index + 1]) : null,
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: colors.focus,
              inactiveTrackColor: colors.border,
              thumbColor: colors.textPrimary,
              overlayColor: colors.focus.withValues(alpha: 0.12),
              thumbShape: _RingThumb(ring: colors.focus),
              tickMarkShape: SliderTickMarkShape.noTickMark,
              trackShape: const RoundedRectSliderTrackShape(),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: index.toDouble(),
              max: (_levels.length - 1).toDouble(),
              divisions: _levels.length - 1,
              semanticFormatterCallback: (value) => '${_levels[value.round()].elo} Elo',
              onChanged: (value) => onChanged(_levels[value.round()]),
            ),
          ),
          _Ticks(count: _levels.length, filled: index + 1, colors: colors),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in ['${EloLevel.minElo}', '${EloLevel.maxElo}'])
                Text(label, style: type.mono.copyWith(fontSize: 12, color: colors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(48),
        foregroundColor: colors.textPrimary,
        backgroundColor: colors.bgElevated,
        side: BorderSide(color: colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// One tick per level, filled up to the current one.
class _Ticks extends StatelessWidget {
  const _Ticks({required this.count, required this.filled, required this.colors});

  final int count;
  final int filled;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < count; i++)
              Container(
                width: 2,
                height: 6,
                decoration: BoxDecoration(
                  color: i < filled ? colors.focus : colors.border,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 28px light thumb with a 5px focus-blue ring, as in the design.
class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.ring});

  final Color ring;

  static const _radius = 14.0;
  static const _ringWidth = 5.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas
      ..drawCircle(
        center.translate(0, 2),
        _radius,
        Paint()
          ..color = const Color(0x80000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      )
      ..drawCircle(center, _radius, Paint()..color = ring)
      ..drawCircle(center, _radius - _ringWidth, Paint()..color = sliderTheme.thumbColor!);
  }
}

class _ColourPicker extends StatelessWidget {
  const _ColourPicker({required this.value, required this.onChanged});

  final ColourChoice value;
  final ValueChanged<ColourChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(16)),
      child: Row(
        spacing: AppSpacing.s2,
        children: [
          for (final choice in ColourChoice.values)
            Expanded(
              child: ChoiceButton(
                selected: value == choice,
                onTap: () => onChanged(choice),
                height: 56,
                selectedColor: Color.alphaBlend(
                  colors.focus.withValues(alpha: 0.22),
                  colors.bgRaised,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.s2,
                  children: [
                    switch (choice) {
                      ColourChoice.white => Image.asset('assets/pieces/wK.png', width: 26),
                      ColourChoice.black => Image.asset('assets/pieces/bK.png', width: 26),
                      ColourChoice.random => Icon(
                        Icons.shuffle,
                        size: 20,
                        color: colors.textTertiary,
                      ),
                    },
                    Text(
                      switch (choice) {
                        ColourChoice.white => 'White',
                        ColourChoice.random => 'Random',
                        ColourChoice.black => 'Black',
                      },
                      style: context.type.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value == choice ? colors.textPrimary : colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
