import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_clock.dart';
import '../domain/game_controller.dart';

/// How a clock is drawn.
enum ClockStyle {
  /// A 40px box, beside a player row vs Stockfish.
  box,

  /// A 44px box with bigger digits, in pass & play rows.
  largeBox,

  /// Big digits and no box, in the face-to-face panels.
  digits,
}

/// [side]'s clock. Normal: focus fill when running. Under 30s: brass. Under
/// 10s: coral, breathing 1 → 0.7 opacity while running. Colour changes tween
/// over 200ms. Without a box ([ClockStyle.digits]) the digits take the colour.
class ClockView extends ConsumerStatefulWidget {
  const ClockView({
    super.key,
    required this.clock,
    required this.side,
    this.owner = 'Your',
    this.style = ClockStyle.box,
  });

  final GameClock clock;
  final Side side;

  /// Whose clock, for screen readers: "Your" or e.g. "Opponent's".
  final String owner;
  final ClockStyle style;

  static const lowTime = Duration(seconds: 30);
  static const criticalTime = Duration(seconds: 10);

  @override
  ConsumerState<ClockView> createState() => _ClockViewState();
}

class _ClockViewState extends ConsumerState<ClockView> with SingleTickerProviderStateMixin {
  Timer? _ticker;

  /// Time left at the previous build, to notice crossing 10 seconds.
  Duration? _lastLeft;

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
    lowerBound: 0.7,
    upperBound: 1,
    value: 1,
  );

  bool get _running => widget.clock.running == widget.side;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ClockView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTicker();
  }

  /// Repaint while running; seconds are shown, so 4 times a second is plenty.
  void _syncTicker() {
    if (_running && _ticker == null) {
      _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
    } else if (!_running) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final left = widget.clock.remaining(widget.side, ref.read(nowProvider)());
    final running = _running;
    final lastLeft = _lastLeft;
    _lastLeft = left;
    if (running &&
        lastLeft != null &&
        lastLeft >= ClockView.criticalTime &&
        left < ClockView.criticalTime) {
      ref.haptic(Haptic.light);
    }

    final (Color accent, bool warning) = left < ClockView.criticalTime
        ? (colors.coral, true)
        : left < ClockView.lowTime
        ? (colors.brass, true)
        : (colors.focus, false);
    final boxed = widget.style != ClockStyle.digits;
    final background = running && boxed ? accent : colors.bgRaised;
    final foreground = warning && !(running && boxed)
        ? accent
        : running
        ? (boxed ? colors.onFocus : colors.textPrimary)
        : colors.textSecondary;
    final digits = Text(
      formatClock(left),
      style: context.type.mono.copyWith(
        fontSize: switch (widget.style) {
          ClockStyle.box => 20,
          ClockStyle.largeBox => 22,
          ClockStyle.digits => 44,
        },
        height: 1,
        color: foreground,
      ),
    );

    final breathe = running && left < ClockView.criticalTime && !shouldReduceMotion(context, ref);
    if (breathe && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!breathe && _breath.isAnimating) {
      _breath
        ..stop()
        ..value = 1;
    }

    return Semantics(
      label: '${widget.owner} clock, ${_spoken(left)}${running ? ', running' : ''}',
      excludeSemantics: true,
      child: FadeTransition(
        opacity: _breath,
        child: boxed
            ? AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: widget.style == ClockStyle.box ? 40 : 44,
                constraints: BoxConstraints(minWidth: widget.style == ClockStyle.box ? 84 : 92),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: !running && warning ? accent.withValues(alpha: 0.5) : Colors.transparent,
                  ),
                ),
                child: digits,
              )
            : digits,
      ),
    );
  }

  static String _spoken(Duration left) {
    final seconds = (left.inMilliseconds / 1000).ceil();
    final minutes = seconds ~/ 60;
    return minutes > 0 ? '$minutes minutes ${seconds % 60} seconds' : '$seconds seconds';
  }
}

/// `08:42`: mm:ss, rounding up so a clock reads 00:00 only when it has run out.
String formatClock(Duration left) {
  final seconds = (left.inMilliseconds / 1000).ceil();
  return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
      '${(seconds % 60).toString().padLeft(2, '0')}';
}
