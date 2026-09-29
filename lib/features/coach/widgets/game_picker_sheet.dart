import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/analysis_repository.dart';
import '../../../core/storage/game_repository.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/move_wise_sheet.dart';
import '../../../core/widgets/segmented_switch.dart';
import '../../games/games_screen.dart'
    show OutcomeBadge, ResultFilter, movesLabel, opponentName, savedGamesProvider;
import 'coach_answer_view.dart' show playedWhen;

/// Ids of the games Stockfish has fully reviewed.
final reviewedGameIdsProvider = FutureProvider.autoDispose<Set<int>>((ref) async {
  final games = await ref.watch(savedGamesProvider.future);
  final analyses = ref.watch(analysisRepositoryProvider);
  return {
    for (final g in games)
      if ((await analyses.analysis(g.id))?.complete ?? false) g.id,
  };
});

/// Lets the player pick one of their games to ask the coach about.
Future<SavedGame?> pickGame(BuildContext context, {required bool reduceMotion}) =>
    showMoveWiseSheet<SavedGame>(
      context,
      reduceMotion: reduceMotion,
      builder: (context) => const _GamePicker(),
    );

class _GamePicker extends ConsumerStatefulWidget {
  const _GamePicker();

  @override
  ConsumerState<_GamePicker> createState() => _GamePickerState();
}

class _GamePickerState extends ConsumerState<_GamePicker> {
  ResultFilter _filter = ResultFilter.all;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final games = ref.watch(savedGamesProvider).value ?? const <SavedGame>[];
    final reviewed = ref.watch(reviewedGameIdsProvider).value ?? const <int>{};
    final query = _search.trim().toLowerCase();
    final shown = [
      for (final g in games)
        if (_filter.matches(g) &&
            (query.isEmpty || opponentName(g.record).toLowerCase().contains(query)))
          g,
    ];
    final border = OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: BorderSide(color: colors.border),
    );

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s3,
        children: [
          Text('Ask about a game', style: type.title.copyWith(fontSize: 22)),
          SegmentedSwitch(
            values: ResultFilter.values,
            selected: _filter,
            label: (filter) => filter.label,
            onSelect: (filter) => setState(() => _filter = filter),
          ),
          TextField(
            onChanged: (text) => setState(() => _search = text),
            style: type.body,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search by opponent',
              hintStyle: type.body.copyWith(color: colors.textTertiary),
              prefixIcon: Icon(Icons.search_rounded, color: colors.textTertiary),
              filled: true,
              fillColor: colors.bgElevated,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.focus)),
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(
                    child: Text(
                      games.isEmpty ? 'No games yet.' : 'No games match.',
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
                    itemBuilder: (context, i) => _GameRow(
                      game: shown[i],
                      reviewed: reviewed.contains(shown[i].id),
                      onTap: () => Navigator.of(context).pop(shown[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GameRow extends StatelessWidget {
  const _GameRow({required this.game, required this.reviewed, required this.onTap});

  final SavedGame game;
  final bool reviewed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final record = game.record;
    final details = [
      playedWhen(record.endedAt, DateTime.now()),
      movesLabel(record),
      switch (record.source) {
        GameSource.stockfish => 'MoveWise',
        GameSource.passAndPlay => 'Pass & Play',
        GameSource.chesscom => 'Chess.com',
        GameSource.lichess => 'Lichess',
      },
    ].join(' · ');
    return Material(
      color: colors.bgElevated,
      borderRadius: AppRadius.smAll,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s3),
          child: Row(
            spacing: AppSpacing.s3,
            children: [
              OutcomeBadge(outcome: record.outcome),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      'vs ${opponentName(record)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.heading.copyWith(fontSize: 15),
                    ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (reviewed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.focus.withValues(alpha: 0.14),
                    borderRadius: AppRadius.xsAll,
                  ),
                  child: Text(
                    'Reviewed',
                    style: type.label.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color.lerp(colors.focus, colors.textPrimary, 0.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
