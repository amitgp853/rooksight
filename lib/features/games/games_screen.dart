import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/motion/reduce_motion.dart';
import '../../core/routing/app_router.dart';
import '../../core/storage/game_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_mark.dart';
import '../../core/widgets/segmented_switch.dart';
import 'widgets/delete_game_sheet.dart';

/// Every saved game, newest first.
final savedGamesProvider = StreamProvider.autoDispose<List<SavedGame>>(
  (ref) => ref.watch(gameRepositoryProvider).watchAll(),
);

/// Which results the list shows.
enum ResultFilter {
  all('All'),
  won('Won'),
  lost('Lost');

  const ResultFilter(this.label);

  final String label;

  bool matches(SavedGame game) => switch (this) {
    all => true,
    won => game.record.outcome == PlayerOutcome.win,
    lost => game.record.outcome == PlayerOutcome.loss,
  };
}

/// Game history. Not designed yet: built from the design system's tokens and
/// components, flagged for design review.
///
/// With [only], shows just those games under [title] (a weakness from the
/// stats), each opening its review at the move given.
class GamesScreen extends ConsumerStatefulWidget {
  const GamesScreen({super.key, this.title, this.only});

  final String? title;

  /// Game ids, each with the move to open the review at (null: the end).
  final Map<int, int?>? only;

  /// `5-23,7` → {5: 23, 7: null}.
  static Map<int, int?>? parseIds(String? ids) {
    if (ids == null || ids.isEmpty) return null;
    return {
      for (final part in ids.split(',').map((p) => p.split('-')))
        ?int.tryParse(part.first): int.tryParse(part.elementAtOrNull(1) ?? ''),
    };
  }

  @override
  ConsumerState<GamesScreen> createState() => _GamesScreenState();
}

class _GamesScreenState extends ConsumerState<GamesScreen> {
  ResultFilter _filter = ResultFilter.all;

  /// Asks, then deletes [game]. True if it was deleted.
  Future<bool> _delete(SavedGame game) async {
    final confirmed = await confirmDeleteGame(
      context,
      game.record,
      reduceMotion: shouldReduceMotion(context, ref),
    );
    if (!confirmed) return false;
    await ref.read(gameRepositoryProvider).delete(game.id);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final only = widget.only;
    final games = ref
        .watch(savedGamesProvider)
        .whenData((all) => only == null ? all : all.where((g) => only.containsKey(g.id)).toList());
    final colors = context.colors;
    final type = context.type;

    return Scaffold(
      appBar: AppBar(title: const Text('Games')),
      body: switch (games) {
        AsyncData(value: final games) when games.isEmpty && only == null => const _EmptyState(),
        AsyncData(value: final games) => Builder(
          builder: (context) {
            final shown = games.where(_filter.matches).toList();
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              children: [
                SegmentedSwitch(
                  values: ResultFilter.values,
                  selected: _filter,
                  label: (filter) => filter.label,
                  onSelect: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: AppSpacing.s4),
                if (only != null) ...[
                  _FilterHeader(title: widget.title, count: shown.length),
                  const SizedBox(height: AppSpacing.s2),
                ],
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                    child: Text(
                      _filter == ResultFilter.won ? 'No wins here yet.' : 'No losses here.',
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  ),
                for (final game in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s2),
                    // Swipe left to delete, after asking.
                    child: Dismissible(
                      key: ValueKey(game.id),
                      direction: DismissDirection.endToStart,
                      background: const _DeleteBackground(),
                      confirmDismiss: (_) => _delete(game),
                      child: _GameTile(
                        onLongPress: () => _delete(game),
                        game: game,
                        ply: switch (only?[game.id]) {
                          final move? => move + 1,
                          null => null,
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        AsyncError() => Center(
          child: Text(
            'Couldn’t load your games.',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Behind a game swiped to delete.
class _DeleteBackground extends StatelessWidget {
  const _DeleteBackground();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.s6),
      decoration: BoxDecoration(
        color: colors.coral.withValues(alpha: 0.18),
        borderRadius: AppRadius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s2,
        children: [
          Icon(Icons.delete_outline_rounded, color: colors.coral),
          Text('Delete', style: context.type.label.copyWith(color: colors.coral)),
        ],
      ),
    );
  }
}

/// What a filtered list shows, and the way back to every game.
class _FilterHeader extends StatelessWidget {
  const _FilterHeader({required this.title, required this.count});

  final String? title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text('SHOWING', style: type.overline.copyWith(color: colors.textTertiary)),
                Text(title ?? 'Some games', style: type.heading),
                Text(
                  '$count ${count == 1 ? 'game' : 'games'} · each opens at the move',
                  style: type.label.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.pushReplacement(Routes.games),
            child: const Text('Show all'),
          ),
        ],
      ),
    );
  }
}

class _GameTile extends StatelessWidget {
  const _GameTile({required this.game, this.ply, this.onLongPress});

  /// Offers to delete the game.
  final VoidCallback? onLongPress;

  final SavedGame game;

  /// Where the review opens; the final position if null.
  final int? ply;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final record = game.record;
    final details = [
      if (record.endReason != null) endReasonLabel(record.endReason!),
      movesLabel(record),
      ?timeControlLabel(record),
      if (record.practice) 'Practice',
    ].join(' · ');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.review('${game.id}', ply: ply)),
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s4),
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
                      opponentName(record),
                      style: type.heading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      details,
                      style: type.label.copyWith(color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 6,
                children: [
                  SourceTag(source: record.source),
                  Text(
                    shortDate(record.endedAt),
                    style: type.label.copyWith(color: colors.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `29 Sep`.
String shortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

/// Where a game came from: played here, or imported. Each is labelled, so
/// none looks like the default.
class SourceTag extends StatelessWidget {
  const SourceTag({super.key, required this.source});

  final GameSource source;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (label, icon, tint) = switch (source) {
      GameSource.stockfish || GameSource.passAndPlay => ('MoveWise', null, colors.focus),
      GameSource.chesscom => ('Chess.com', Icons.download_rounded, colors.textSecondary),
      GameSource.lichess => ('Lichess', Icons.download_rounded, colors.textSecondary),
    };
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: tint.withValues(alpha: 0.12), borderRadius: AppRadius.xsAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          if (icon != null) Icon(icon, size: 13, color: tint) else const LogoMark(size: 13),
          Text(
            label,
            style: context.type.label.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tint,
            ),
          ),
        ],
      ),
    );
  }
}

/// W / D / L with the result colour. The letter always shows: never colour alone.
class OutcomeBadge extends StatelessWidget {
  const OutcomeBadge({super.key, required this.outcome});

  final PlayerOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (letter, colour, label) = switch (outcome) {
      PlayerOutcome.win => ('W', colors.resultWin, 'Win'),
      PlayerOutcome.draw => ('D', colors.resultDraw, 'Draw'),
      PlayerOutcome.loss => ('L', colors.resultLoss, 'Loss'),
      PlayerOutcome.unknown => ('?', colors.textTertiary, 'Unknown result'),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colour.withValues(alpha: 0.14),
          borderRadius: AppRadius.smAll,
        ),
        child: Text(
          letter,
          style: context.type.heading.copyWith(fontWeight: FontWeight.w700, color: colour),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s8, 0, AppSpacing.s8, 80),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            const Center(child: Opacity(opacity: 0.5, child: LogoMark(size: 96))),
            Text(
              'No games yet',
              textAlign: TextAlign.center,
              style: type.title.copyWith(fontSize: 22),
            ),
            Text(
              'Every game you finish is kept here, ready for review. Play Stockfish or a '
              'friend, or bring in your online games.',
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 0),
            FilledButton(
              onPressed: () => context.push(Routes.playSetup),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: buttonShape,
                textStyle: type.heading.copyWith(fontSize: 15),
              ),
              child: const Text('Play vs Computer'),
            ),
            OutlinedButton(
              onPressed: () => context.push(Routes.import),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: colors.bgRaised,
                shape: buttonShape,
                textStyle: type.heading.copyWith(fontSize: 15),
              ),
              child: const Text('Import from Chess.com or Lichess'),
            ),
          ],
        ),
      ),
    );
  }
}

/// `47 moves`, or `1 move`: full moves in the game.
String movesLabel(GameRecord record) {
  final moves = (record.plyCount + 1) ~/ 2;
  return moves == 1 ? '1 move' : '$moves moves';
}

/// Who the user played, with their rating when known.
String opponentName(GameRecord record) {
  final name =
      record.opponentName ??
      (record.engineElo != null ? 'Stockfish ${record.engineElo}' : 'Opponent');
  if (record.source == GameSource.passAndPlay) return '$name · pass & play';
  final rating = record.opponentRating;
  return rating == null ? name : '$name ($rating)';
}

/// `3+2` (minutes + increment), `Daily`, or null without a clock.
String? timeControlLabel(GameRecord record) {
  if (record.timeClass == 'daily') return 'Daily';
  final control = record.timeControl;
  if (control == null) return null;
  final match = RegExp(r'^(\d+)\+(\d+)$').firstMatch(control);
  if (match == null) return control;
  final seconds = int.parse(match[1]!);
  // Bullet 30s games read better as ½ than 0.
  final minutes = seconds >= 60 ? '${seconds ~/ 60}' : (seconds == 30 ? '½' : '${seconds}s');
  return '$minutes+${match[2]}';
}

/// A short label for a stored end reason.
String endReasonLabel(String reason) => switch (reason) {
  'checkmate' => 'Checkmate',
  'stalemate' => 'Stalemate',
  'threefoldRepetition' => 'Repetition',
  'fiftyMoveRule' => '50-move rule',
  'insufficientMaterial' => 'Insufficient material',
  'resignation' => 'Resignation',
  'timeout' => 'Timeout',
  'agreement' => 'Draw agreed',
  'abandoned' => 'Abandoned',
  // A Lichess draw of any kind (agreed, repetition, 50 moves…).
  'draw' => 'Draw',
  _ => reason,
};
