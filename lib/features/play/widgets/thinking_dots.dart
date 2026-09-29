import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_theme.dart';

/// Stockfish is thinking: three dots bob on a 1200ms loop, 150ms apart.
/// With reduced motion, a static "Thinking…" chip instead.
class ThinkingDots extends ConsumerStatefulWidget {
  const ThinkingDots({super.key});

  @override
  ConsumerState<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends ConsumerState<ThinkingDots> with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1200);
  static const _stagger = 150 / 1200;
  static const _dotSize = 5.0;
  static const _bob = 3.0;

  late final AnimationController _controller = AnimationController(vsync: this, duration: _period);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (shouldReduceMotion(context, ref)) {
      _controller.stop();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: colors.bgElevated, borderRadius: AppRadius.xsAll),
        child: Text('Thinking…', style: context.type.label.copyWith(color: colors.textSecondary)),
      );
    }

    if (!_controller.isAnimating) _controller.repeat();
    return Semantics(
      label: 'Stockfish is thinking',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 3,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.translate(
                offset: Offset(0, -_bob * _lift((_controller.value - i * _stagger) % 1)),
                child: Container(
                  width: _dotSize,
                  height: _dotSize,
                  decoration: BoxDecoration(color: colors.textSecondary, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Up and back down in the first half of each cycle, then rest.
  static double _lift(double t) => t < 0.5 ? Curves.easeInOut.transform(sin(t * 2 * pi).abs()) : 0;
}
