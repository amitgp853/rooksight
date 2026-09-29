import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../bulk_review_controller.dart';
import '../domain/player_stats.dart';
import '../domain/weaknesses.dart';

/// A raised section card, as the design's stats sections.
class StatsSection extends StatelessWidget {
  const StatsSection({super.key, required this.title, this.trailing, required this.children});

  final String title;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: title,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 18),
        decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s4,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text(title, style: context.type.heading.copyWith(fontSize: 17))),
                ?trailing,
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A rounded bar filled to [value] (0–1).
class _Meter extends StatelessWidget {
  const _Meter({required this.value, required this.color, required this.height});

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: context.colors.bgElevated,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: value.clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}

/// "Top 3 weaknesses".
class WeaknessList extends StatelessWidget {
  const WeaknessList({super.key, required this.weaknesses, required this.reviewed});

  final List<Weakness> weaknesses;

  /// Reviewed games in the period.
  final int reviewed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s3,
      children: [
        Text('Top 3 weaknesses', style: type.title.copyWith(fontSize: 20, letterSpacing: -0.2)),
        if (weaknesses.isEmpty)
          // Not in the design.
          Container(
            padding: const EdgeInsets.all(AppSpacing.s4),
            decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
            child: Text(
              reviewed < 3
                  ? 'Not enough reviewed games to spot patterns yet. Review a few more and '
                        'they show up here.'
                  : 'No pattern shows up in two or more of these games. Nice.',
              style: type.body.copyWith(fontSize: 14, color: colors.textSecondary),
            ),
          ),
        for (final (i, weakness) in weaknesses.indexed)
          WeaknessCard(rank: i + 1, weakness: weakness),
      ],
    );
  }
}

class WeaknessCard extends StatelessWidget {
  const WeaknessCard({super.key, required this.rank, required this.weakness});

  final int rank;
  final Weakness weakness;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final games = weakness.games.length;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 14,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: type.heading.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: colors.resultLoss,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.s2,
              children: [
                Text(weakness.title, style: type.heading.copyWith(fontSize: 16, height: 22 / 16)),
                Text(
                  weakness.detail,
                  style: type.body.copyWith(
                    fontSize: 14,
                    height: 20 / 14,
                    color: colors.textSecondary,
                  ),
                ),
                Semantics(
                  label: 'In $games of ${weakness.considered} games',
                  child: _Meter(value: weakness.share, color: colors.resultLoss, height: 6),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s1),
                  child: Wrap(
                    spacing: AppSpacing.s2,
                    runSpacing: AppSpacing.s2,
                    children: [
                      TextButton(
                        onPressed: () => context.push(Routes.coachAsking(weakness.question)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          backgroundColor: colors.bgElevated,
                          foregroundColor: colors.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Ask AI Coach'),
                      ),
                      TextButton(
                        onPressed: () =>
                            context.push(Routes.gamesShowing(weakness.title, weakness.games)),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('See $games ${games == 1 ? 'game' : 'games'}'),
                      ),
                    ],
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

/// "Blunders by game phase".
class PhaseCard extends StatelessWidget {
  const PhaseCard({super.key, required this.stats});

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final blunders = {
      for (final phase in PlayerStats.phases) phase: stats.errorsByPhase[phase]!.blunders,
    };
    final total = blunders.values.fold(0, (a, b) => a + b);
    final most = blunders.values.fold(0, (a, b) => a > b ? a : b);
    final caption = type.body.copyWith(fontSize: 13, height: 19 / 13, color: colors.textSecondary);

    return StatsSection(
      title: 'Blunders by game phase',
      trailing: Text('$total total', style: caption),
      children: [
        if (stats.reviewed == 0)
          Text('Review some games to see where your blunders happen.', style: caption)
        else ...[
          for (final phase in PlayerStats.phases)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: phaseLabels[phase]!.name,
                          children: [
                            TextSpan(
                              text: ' · ${phaseLabels[phase]!.hint}',
                              style: TextStyle(color: colors.textTertiary),
                            ),
                          ],
                        ),
                        style: type.body.copyWith(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${blunders[phase]}',
                      style: type.mono.copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                _Meter(
                  value: most == 0 ? 0 : blunders[phase]! / most,
                  color: colors.moveBlunder,
                  height: 12,
                ),
              ],
            ),
          Text(phaseTakeaway(blunders), style: caption),
        ],
      ],
    );
  }
}

/// One line on where the blunders happen.
String phaseTakeaway(Map<String, int> blunders) {
  final total = blunders.values.fold(0, (a, b) => a + b);
  if (total == 0) return 'No blunders in your reviewed games. Keep it up.';
  final worst = blunders.entries.reduce((a, b) => b.value > a.value ? b : a);
  if (worst.value * 2 < total) return 'Your blunders are spread across the game.';
  return switch (worst.key) {
    'opening' => 'Most of your blunders come early, before your pieces are out.',
    'middlegame' => 'Most of your blunders come in the middlegame, with most pieces still on.',
    _ => 'Most of your blunders come in the endgame, once the pieces come off.',
  };
}

/// "Results by opening".
class OpeningCard extends StatelessWidget {
  const OpeningCard({super.key, required this.stats});

  /// Openings shown, most played first.
  static const shown = 5;

  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    Widget key(String label, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s1,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        Text(label, style: type.label.copyWith(fontSize: 12, color: colors.textSecondary)),
      ],
    );

    return StatsSection(
      title: 'Results by opening',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 10,
        children: [
          key('Win', colors.resultWin),
          key('Draw', colors.resultDraw),
          key('Loss', colors.resultLoss),
        ],
      ),
      children: [for (final opening in stats.byOpening.take(shown)) _OpeningRow(opening: opening)],
    );
  }
}

class _OpeningRow extends StatelessWidget {
  const _OpeningRow({required this.opening});

  final OpeningResults opening;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final score = (opening.score * 100).round();
    final side = opening.side == Side.white ? 'White' : 'Black';
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.bgElevated)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: AppSpacing.s2,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opening.name,
                      style: type.body.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      'as $side · ${opening.games} ${opening.games == 1 ? 'game' : 'games'}',
                      style: type.label.copyWith(fontSize: 12, color: colors.textTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                '$score%',
                style: type.mono.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: score >= 50
                      ? Color.lerp(colors.resultWin, colors.textPrimary, 0.3)
                      : colors.resultLoss,
                ),
              ),
            ],
          ),
          Semantics(
            label: '${opening.wins} wins, ${opening.draws} draws, ${opening.losses} losses',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: SizedBox(
                height: 10,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 2,
                  children: [
                    for (final (count, color) in [
                      (opening.wins, colors.resultWin),
                      (opening.draws, colors.resultDraw),
                      (opening.losses, colors.resultLoss),
                    ])
                      if (count > 0)
                        Expanded(
                          flex: count,
                          child: ColoredBox(color: color),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Games Stockfish hasn't reviewed yet, and a way to review them all (not in
/// the design).
class BulkReviewCard extends ConsumerWidget {
  const BulkReviewCard({super.key, required this.unreviewed});

  final List<StatsGame> unreviewed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final bulk = ref.watch(bulkReviewProvider);
    final count = unreviewed.length;
    final caption = type.body.copyWith(fontSize: 13, height: 19 / 13, color: colors.textSecondary);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: colors.bgRaised,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.focus.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s2,
        children: [
          if (bulk.running) ...[
            Text(
              'Reviewing game ${bulk.finished + 1} of ${bulk.total}',
              style: type.heading.copyWith(fontSize: 16),
            ),
            if (bulk.current != null) Text(bulk.current!, style: caption),
            _Meter(
              value: (bulk.finished + bulk.progress) / bulk.total,
              color: colors.focus,
              height: 6,
            ),
            Text('Keep this screen open. What’s done is kept if you leave.', style: caption),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: ref.read(bulkReviewProvider.notifier).stop,
                child: const Text('Stop'),
              ),
            ),
          ] else ...[
            Text(
              count == 1 ? '1 game isn’t reviewed yet' : '$count games aren’t reviewed yet',
              style: type.heading.copyWith(fontSize: 16),
            ),
            Text(
              'Weaknesses come from Stockfish’s review of each game. It runs on your '
              'phone, about half a minute a game.',
              style: caption,
            ),
            const SizedBox(height: AppSpacing.s1),
            FilledButton(
              onPressed: () => ref.read(bulkReviewProvider.notifier).start(unreviewed),
              child: Text(count == 1 ? 'Review it' : 'Review them'),
            ),
          ],
        ],
      ),
    );
  }
}
