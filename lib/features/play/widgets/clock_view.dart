import 'dart:async';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_clock.dart';
import '../domain/game_controller.dart';

/// One player's clock. Normal: focus fill when running. Under 30s: brass.
/// Under 10s: coral, breathing 1 → 0.7 opacity while running. Colour changes
/// tween over 200ms.
class ClockView extends ConsumerStatefulWidget {
  const ClockView({super.key, required this.clock, required this.side, required this.isPlayer});

  final GameClock clock;
  final Side side;
  final bool isPlayer;

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
    if (widget.isPlayer &&
        running &&
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
    final background = running ? accent : colors.bgRaised;
    final foreground = running ? colors.onFocus : (warning ? accent : colors.textSecondary);

    final breathe = running && left < ClockView.criticalTime && !shouldReduceMotion(context, ref);
    if (breathe && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!breathe && _breath.isAnimating) {
      _breath
        ..stop()
        ..value = 1;
    }

    return Semantics(
      label:
          '${widget.isPlayer ? 'Your' : 'Stockfish'} clock, ${_spoken(left)}'
          '${running ? ', running' : ''}',
      excludeSemantics: true,
      child: FadeTransition(
        opacity: _breath,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          constraints: const BoxConstraints(minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerRight,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: !running && warning ? accent.withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Text(
            formatClock(left),
            style: context.type.mono.copyWith(fontSize: 20, height: 1, color: foreground),
          ),
        ),
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
