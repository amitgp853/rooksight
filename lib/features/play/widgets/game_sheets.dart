import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/button_row.dart';
import '../domain/game_controller.dart';
import 'result_copy.dart';

/// "Game options": offer a draw, turn on practice mode, resign.
class OptionsSheet extends ConsumerWidget {
  const OptionsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final colors = context.colors;
    final type = context.type;
    void close() => Navigator.of(context).pop();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text('Game options', style: type.heading),
        ),
        _OptionRow(
          leading: Text(
            '½',
            style: type.heading.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          title: 'Offer draw',
          onTap: session.canOfferDraw
              ? () {
                  close();
                  controller.offerDraw();
                }
              : null,
        ),
        _OptionRow(
          leading: Icon(
            session.config.practice ? Icons.school : Icons.school_outlined,
            size: 22,
            color: colors.textSecondary,
          ),
          title: session.config.practice ? 'Turn off practice mode' : 'Turn on practice mode',
          subtitle: session.config.practice
              ? 'Undo stays available until you turn it off'
              : 'Unlocks Undo for this game',
          onTap: () {
            controller.setPractice(enabled: !session.config.practice);
            close();
          },
        ),
        _OptionRow(
          leading: Icon(Icons.flag_outlined, size: 22, color: colors.coral),
          title: 'Resign',
          destructive: true,
          onTap: session.game.isOver
              ? null
              : () {
                  close();
                  controller.resign();
                },
        ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Material(
        color: destructive ? colors.coral.withValues(alpha: 0.1) : colors.bgElevated,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
              child: Row(
                spacing: 14,
                children: [
                  SizedBox(width: 24, child: Center(child: leading)),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: type.body.copyWith(
                            fontWeight: destructive ? FontWeight.w600 : FontWeight.w500,
                            color: destructive ? colors.coral : colors.textPrimary,
                          ),
                        ),
                        if (subtitle case final subtitle?)
                          Text(
                            subtitle,
                            style: type.label.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: colors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Game over: how it ended, the score, and what to do next.
class ResultSheet extends ConsumerWidget {
  const ResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(gameControllerProvider);
    if (!session.game.isOver) return const SizedBox.shrink();
    final copy = ResultCopy.of(session);
    final colors = context.colors;
    final type = context.type;
    final overlineColor = switch (copy.tone) {
      ResultTone.win => Color.lerp(colors.focus, colors.textPrimary, 0.3)!,
      ResultTone.draw => colors.textSecondary,
      ResultTone.loss => colors.resultLoss,
    };
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    // Review and share need the stored game; saving takes a moment.
    final savedId = session.savedGameId;
    void open(String route) {
      Navigator.of(context).pop();
      context.push(route);
    }

    return Semantics(
      label: 'Game over',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s4,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 4,
                  children: [
                    Text(
                      copy.overline.toUpperCase(),
                      style: type.overline.copyWith(color: overlineColor),
                    ),
                    Text(
                      copy.title,
                      style: type.title.copyWith(
                        fontSize: 28,
                        height: 34 / 28,
                        letterSpacing: 28 * -0.015,
                      ),
                    ),
                    Text(
                      copy.reason,
                      style: type.body.copyWith(height: 21 / 15, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(copy.score, style: type.mono.copyWith(fontSize: 22)),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s2,
            children: [
              FilledButton(
                onPressed: savedId == null ? null : () => open(Routes.review('$savedId')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: buttonShape,
                  textStyle: type.heading.copyWith(fontSize: 15),
                ),
                child: const Text('Review with AI Coach'),
              ),
              ButtonRow(
                spacing: AppSpacing.s2,
                mainLast: false,
                children: [
                  for (final (label, action) in [
                    (
                      'Rematch',
                      () {
                        Navigator.of(context).pop();
                        ref.read(gameControllerProvider.notifier).rematch();
                      },
                    ),
                    (
                      'Share report card',
                      savedId == null ? null : () => open(Routes.reportCard('$savedId')),
                    ),
                  ])
                    OutlinedButton(
                      onPressed: action,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                        shape: buttonShape,
                        textStyle: type.heading.copyWith(fontSize: 15),
                      ),
                      child: Text(label),
                    ),
                ],
              ),
            ],
          ),
          if (session.saveFailed)
            Text(
              'Couldn’t save this game.',
              textAlign: TextAlign.center,
              style: type.label.copyWith(color: colors.coral),
            ),
        ],
      ),
    );
  }
}
