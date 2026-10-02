import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/button_row.dart';
import '../../games/games_screen.dart' show shortDate;
import '../../play/widgets/result_copy.dart';
import '../domain/pass_controller.dart';
import 'pass_copy.dart';

/// Game over in pass & play (`PassGame.dc.html`, state `result`): how it
/// ended, that it's saved, and what to do next.
class PassResultSheet extends ConsumerWidget {
  const PassResultSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(passControllerProvider);
    if (!session.game.isOver) return const SizedBox.shrink();
    final copy = passResultCopy(session);
    final config = session.config;
    final colors = context.colors;
    final type = context.type;
    final overlineColor = copy.tone == ResultTone.draw
        ? colors.textSecondary
        : Color.lerp(colors.focus, colors.textPrimary, 0.3)!;
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
                    Text(copy.title, style: type.title.copyWith(fontSize: 26, height: 32 / 26)),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.s3),
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              spacing: AppSpacing.s3,
              children: [
                Icon(
                  session.saveFailed ? Icons.error_outline : Icons.save_outlined,
                  size: 20,
                  color: session.saveFailed ? colors.coral : colors.focus,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        session.saveFailed ? 'Couldn’t save this game' : 'Saved to Your games',
                        style: type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${config.nameOf(Side.white)} vs ${config.nameOf(Side.black)} · '
                        '${shortDate(session.startedAt ?? DateTime.now())} · engine review '
                        'works offline, AI Coach explanations when you’re online',
                        style: type.label.copyWith(
                          fontSize: 12,
                          height: 17 / 12,
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              FilledButton(
                onPressed: savedId == null ? null : () => open(Routes.review('$savedId')),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: buttonShape,
                  textStyle: type.heading.copyWith(fontSize: 16),
                ),
                child: const Text('Review with AI Coach'),
              ),
              ButtonRow(
                spacing: 10,
                mainLast: false,
                children: [
                  for (final (label, action) in [
                    (
                      'Rematch · swap colours',
                      () {
                        Navigator.of(context).pop();
                        ref.read(passControllerProvider.notifier).rematch();
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
                        backgroundColor: colors.bgElevated,
                        shape: buttonShape,
                        textStyle: type.heading.copyWith(fontSize: 14),
                      ),
                      child: Text(label, textAlign: TextAlign.center),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
