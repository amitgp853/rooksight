// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/segmented_switch.dart';
import 'bulk_review_controller.dart';
import 'stats_controller.dart';
import 'domain/insights.dart';
import 'widgets/insight_cards.dart';
import 'widgets/stats_cards.dart';

/// Weakness stats (`design/source/Stats.dc.html`): the top 3 weaknesses,
/// blunders by game phase and results by opening, for the recent games.
/// Everything is computed on the phone, with no AI calls.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final view = ref.watch(statsViewProvider);
    // Each game the bulk review finishes updates the stats.
    ref.listen(bulkReviewProvider.select((s) => s.finished), (_, _) {
      ref.invalidate(statsViewProvider);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Your Stats')),
      body: switch (view) {
        AsyncData(value: final view) when view.games.isEmpty => const _NoGames(),
        AsyncValue(value: final view?) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s1, AppSpacing.s4, 32),
          children: [
            const _PeriodSwitch(),
            const SizedBox(height: AppSpacing.s2),
            _PeriodCaption(view: view),
            const SizedBox(height: 28),
            if (view.unreviewed.isNotEmpty || ref.watch(bulkReviewProvider).running) ...[
              BulkReviewCard(unreviewed: view.unreviewed),
              const SizedBox(height: 28),
            ],
            SummaryStrip(
              stats: view.stats,
              previous: view.previousStats,
              periodSize: ref.watch(statsPeriodProvider).limit,
            ),
            const SizedBox(height: 28),
            WeaknessList(
              weaknesses: view.weaknesses.take(3).toList(),
              reviewed: view.stats.reviewed,
            ),
            const SizedBox(height: 28),
            MoveTimingCard(buckets: errorsByMoveNumber(view.games), reviewed: view.stats.reviewed),
            const SizedBox(height: AppSpacing.s4),
            PhaseCard(stats: view.stats),
            const SizedBox(height: AppSpacing.s4),
            OpeningCard(stats: view.stats),
            if (!view.bests.isEmpty) ...[
              const SizedBox(height: 28),
              PersonalBestsCard(bests: view.bests),
            ],
          ],
        ),
        AsyncError() => Center(
          child: Text(
            'Couldn’t load your stats.',
            style: context.type.body.copyWith(color: colors.textSecondary),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// What the period covers: "Your 20 most recent games · 4 reviewed".
class _PeriodCaption extends ConsumerWidget {
  const _PeriodCaption({required this.view});

  final StatsView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = view.games.length;
    final games = count == 1 ? 'game' : 'games';
    final which = ref.watch(statsPeriodProvider) == StatsPeriod.all
        ? 'All $count of your $games'
        : 'Your $count most recent $games';
    return Text(
      '$which · ${view.stats.reviewed} reviewed',
      textAlign: TextAlign.center,
      style: context.type.label.copyWith(
        color: context.colors.textSecondary,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

/// Last 20 · Last 50 · All time.
class _PeriodSwitch extends ConsumerWidget {
  const _PeriodSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) => SegmentedSwitch(
    values: StatsPeriod.values,
    selected: ref.watch(statsPeriodProvider),
    label: (period) => period.label,
    onSelect: ref.read(statsPeriodProvider.notifier).select,
  );
}

/// Before any game (not in the design).
class _NoGames extends StatelessWidget {
  const _NoGames();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s3,
          children: [
            Text('No games yet', style: type.title),
            Text(
              'Play or import a few games, and your results and habits show up here.',
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s2),
            FilledButton(
              onPressed: () => context.push(Routes.playSetup),
              child: const Text('Play vs Computer'),
            ),
            OutlinedButton(
              onPressed: () => context.push(Routes.import),
              style: OutlinedButton.styleFrom(
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
              ),
              child: const Text('Import games'),
            ),
          ],
        ),
      ),
    );
  }
}
