import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/board_reader.dart';

/// "Reading your board" (`ScanScanning.dc.html`): the dimmed photo with a
/// scan line sweeping it, and each step of the reading as it happens.
class ScanReadingView extends ConsumerWidget {
  const ScanReadingView({
    super.key,
    required this.photo,
    required this.steps,
    required this.onCancel,
  });

  final Uint8List photo;
  final List<ScanStep> steps;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final reduce = shouldReduceMotion(context, ref);
    final finished = steps.isNotEmpty && steps.every((s) => s.done);
    final done = steps.where((s) => s.done).length;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Cancel scan',
                    onPressed: onCancel,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Text('Reading your board', style: type.heading),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 358),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.memory(photo, fit: BoxFit.cover, semanticLabel: 'Your photo'),
                              const ColoredBox(color: Color(0x8C080B0F)),
                              if (!finished && !reduce) const _Sweep(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s5),
                  Semantics(
                    liveRegion: true,
                    container: true,
                    label: 'Scan steps',
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                      decoration: BoxDecoration(
                        color: colors.bgRaised,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 28,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    finished ? 'POSITION READY' : 'WORKING…',
                                    style: type.overline.copyWith(color: colors.textSecondary),
                                  ),
                                ),
                                Text(
                                  '$done / ${steps.length}',
                                  style: type.mono.copyWith(
                                    fontSize: 12,
                                    color: colors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final step in steps) _StepRow(step: step, reduce: reduce),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                spacing: AppSpacing.s2,
                children: [
                  Text(
                    'The photo is sent to Gemini with your key and is never saved on this phone. '
                    'Every square is checked before you continue.',
                    textAlign: TextAlign.center,
                    style: type.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: colors.textTertiary,
                    ),
                  ),
                  TextButton(onPressed: onCancel, child: const Text('Cancel')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.reduce});

  final ScanStep step;
  final bool reduce;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final accent = step.retry ? const Color(0xFFE3B25C) : colors.focus;
    final Widget indicator;
    if (step.done) {
      indicator = Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 13, color: Color(0xFF0B1224)),
      );
    } else if (reduce) {
      indicator = Text('…', style: type.body.copyWith(color: accent, height: 1));
    } else {
      indicator = SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: accent),
      );
    }
    final running = step.retry
        ? Color.lerp(const Color(0xFFE3B25C), colors.textPrimary, 0.5)!
        : Color.lerp(colors.focus, colors.textPrimary, 0.55)!;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: SizedBox(width: 20, child: Center(child: indicator)),
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
                    color: step.done ? colors.textPrimary : running,
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
    if (reduce) return row;
    // Rows fade up 4px as each starts.
    return TweenAnimationBuilder<double>(
      key: ValueKey(step.label),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 4 * (1 - t)), child: child),
      ),
      child: row,
    );
  }
}

/// The scan line going up and down the photo.
class _Sweep extends StatefulWidget {
  const _Sweep();

  @override
  State<_Sweep> createState() => _SweepState();
}

class _SweepState extends State<_Sweep> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Align(
        alignment: Alignment(0, -1 + 2 * Curves.easeInOut.transform(_controller.value)),
        child: Container(
          height: 2,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0x0086A8FF), Color(0xFF86A8FF), Color(0x0086A8FF)],
            ),
            boxShadow: [BoxShadow(color: Color(0x7386A8FF), blurRadius: 16, spreadRadius: 4)],
          ),
        ),
      ),
    );
  }
}
