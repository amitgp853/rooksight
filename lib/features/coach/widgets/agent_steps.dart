import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/coach_tools.dart';

/// The coach's steps as they happen (the design's agent step rows): a
/// spinner while a step runs, a check with its detail once done. The header
/// folds the list away once the answer is in.
class AgentSteps extends StatefulWidget {
  const AgentSteps({super.key, required this.steps, required this.running});

  final List<AgentStep> steps;
  final bool running;

  @override
  State<AgentSteps> createState() => _AgentStepsState();
}

class _AgentStepsState extends State<AgentSteps> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final done = widget.steps.where((s) => s.done).length;
    final title = widget.running
        ? 'Working…'
        : 'Worked through ${widget.steps.length} ${widget.steps.length == 1 ? 'step' : 'steps'}';

    return Semantics(
      container: true,
      label: 'Coach steps',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s1,
          children: [
            InkWell(
              onTap: widget.running ? null : () => setState(() => _open = !_open),
              borderRadius: AppRadius.xsAll,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: type.overline.copyWith(color: colors.textSecondary),
                      ),
                    ),
                    Text(
                      '$done / ${widget.steps.length}',
                      style: type.mono.copyWith(fontSize: 12, color: colors.textTertiary),
                    ),
                    if (!widget.running) ...[
                      const SizedBox(width: AppSpacing.s1),
                      Icon(
                        _open ? Icons.expand_less : Icons.expand_more,
                        size: 18,
                        color: colors.textTertiary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_open || widget.running)
              for (final (i, step) in widget.steps.indexed)
                FadeInUp(
                  key: ValueKey(i),
                  child: _StepRow(step: step),
                ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final AgentStep step;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: AppSpacing.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s3,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox.square(
              dimension: 20,
              child: step.done
                  ? DecoratedBox(
                      decoration: BoxDecoration(color: colors.focus, shape: BoxShape.circle),
                      child: Icon(Icons.check, size: 13, color: colors.onFocus),
                    )
                  : CircularProgressIndicator(strokeWidth: 2, color: colors.focus),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  step.label,
                  style: type.body.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                    color: step.done
                        ? colors.textPrimary
                        : Color.lerp(colors.focus, colors.textPrimary, 0.6),
                  ),
                ),
                if (step.done && step.detail != null)
                  Text(
                    step.detail!,
                    style: type.mono.copyWith(
                      fontSize: 12,
                      height: 17 / 12,
                      color: colors.textTertiary,
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

/// Fades in while rising 4px (the design's `mw-in`); a plain 150ms fade
/// with reduced motion.
class FadeInUp extends ConsumerWidget {
  const FadeInUp({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  final Widget child;
  final Duration duration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reduce = shouldReduceMotion(context, ref);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: reduce ? const Duration(milliseconds: 150) : duration,
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, reduce ? 0 : 4 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
