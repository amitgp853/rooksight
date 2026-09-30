import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/move_wise_board.dart';
import '../../core/routing/app_router.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/saved_position_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_mark.dart';
import '../games/games_screen.dart' show savedGamesProvider;
import '../pass_play/domain/unfinished_pass_game.dart';
import '../play/domain/game_config.dart';
import '../play/domain/game_state.dart';
import '../play/domain/unfinished_game.dart';
import '../play/widgets/clock_view.dart' show formatClock;
import '../stats/domain/player_stats.dart';
import '../stats/domain/weaknesses.dart';

/// The player's #1 weakness over their last 20 games, for Home's stats card.
final homeWeaknessProvider = FutureProvider.autoDispose<Weakness?>((ref) async {
  final saved = await ref.watch(savedGamesProvider.future);
  final games = await statsGamesOf(saved.take(20), ref.watch(analysisRepositoryProvider));
  return findWeaknesses(games).firstOrNull;
});

/// Home (`Home.dc.html`, `HomeLight.dc.html`): the game to continue, Play vs
/// Computer, Pass & play, Import and AI Coach, and Stats with the top
/// weakness. Light mode outlines the cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final unfinished = ref.watch(unfinishedGameProvider);
    final unfinishedPass = ref.watch(unfinishedPassGameProvider);
    // One Continue card: the game left most recently.
    final continuePass =
        unfinishedPass != null &&
        (unfinished == null || unfinishedPass.savedAt.isAfter(unfinished.savedAt));

    // Back on Home, the top weakness may have changed (new reviews).
    Future<void> open(String route) async {
      await context.push(route);
      ref.invalidate(homeWeaknessProvider);
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s4, 12, AppSpacing.s4, AppSpacing.s6),
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  const LogoMark(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'MoveWise',
                      style: type.title.copyWith(fontSize: 20, letterSpacing: -0.2),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Settings',
                    color: colors.textSecondary,
                    iconSize: 22,
                    constraints: const BoxConstraints.tightFor(width: 44, height: 44),
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => open(Routes.settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            if (continuePass) ...[
              _ContinueCard.pass(
                unfinishedPass,
                onResume: () {
                  ref.read(resumePassGameProvider).request();
                  open(Routes.passGame);
                },
              ),
              const SizedBox(height: AppSpacing.s4),
            ] else if (unfinished != null) ...[
              _ContinueCard.stockfish(
                unfinished,
                onResume: () {
                  ref.read(resumeGameProvider).request();
                  open(Routes.game);
                },
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
            _PlayCard(onTap: () => open(Routes.playSetup)),
            const SizedBox(height: 12),
            _Card(
              onTap: () => open(Routes.passSetup),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: const _RowHeader(
                icon: Icons.people_outline_rounded,
                title: 'Pass & Play',
                subtitle: 'Two players, one phone',
                iconSize: 44,
              ),
            ),
            const SizedBox(height: 12),
            _Card(
              onTap: () => open(Routes.scan),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: const _RowHeader(
                icon: Icons.photo_camera_outlined,
                title: 'Scan a board',
                subtitle: 'Photo of a real board or a book diagram',
                iconSize: 44,
              ),
            ),
            _SavedPositionsRow(onTap: () => open(Routes.savedPositions)),
            const SizedBox(height: AppSpacing.s4),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.download_rounded,
                    iconColor: colors.focus,
                    title: 'Import Games',
                    subtitle: 'Chess.com · Lichess',
                    onTap: () => open(Routes.import),
                  ),
                ),
                Expanded(
                  child: _Tile(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: colors.brass,
                    title: 'AI Coach',
                    subtitle: 'Ask about any game',
                    onTap: () => open(Routes.coach),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s4),
            // Games before Stats: your games matter more than the summary.
            _GamesCard(onTap: () => open(Routes.games)),
            const SizedBox(height: AppSpacing.s4),
            _StatsCard(onTap: () => open(Routes.stats)),
          ],
        ),
      ),
    );
  }
}

/// A raised card with the design's radius; outlined in light mode.
class _Card extends StatelessWidget {
  const _Card({required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final light = Theme.of(context).brightness == Brightness.light;
    return Material(
      color: colors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: light ? BorderSide(color: colors.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A rounded square (40px by default) with an icon, as in the design's tiles.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.bgElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// The unfinished game: its position, and Resume.
class _ContinueCard extends StatelessWidget {
  const _ContinueCard({
    required this.game,
    required this.orientation,
    required this.title,
    required this.details,
    required this.status,
    required this.onResume,
  });

  /// A game against Stockfish: "vs Stockfish · 1600", the player's clock.
  factory _ContinueCard.stockfish(UnfinishedGame saved, {required VoidCallback onResume}) {
    final state = saved.game;
    final config = saved.config;
    final clock = config.playerSide == Side.white ? saved.white : saved.black;
    return _ContinueCard(
      game: state,
      orientation: config.playerSide,
      title: 'vs Stockfish · ${config.level.elo}',
      details: [
        _clockLabel(config.timeControl),
        'move ${state.position.fullmoves}',
        if (config.practice) 'practice',
      ].join(' · '),
      status: [
        ?clock == null ? null : formatClock(clock),
        state.turn == config.playerSide ? 'your turn' : 'Stockfish to move',
      ].join(' · '),
      onResume: onResume,
    );
  }

  /// A pass & play game: both names, and the clock of whoever is to move.
  factory _ContinueCard.pass(UnfinishedPassGame saved, {required VoidCallback onResume}) {
    final state = saved.game;
    final config = saved.config;
    final clock = state.turn == Side.white ? saved.white : saved.black;
    return _ContinueCard(
      game: state,
      orientation: config.firstSide,
      title: '${config.nameOf(Side.white)} vs ${config.nameOf(Side.black)}',
      details: [
        'Pass & Play',
        _clockLabel(config.timeControl),
        'move ${state.position.fullmoves}',
      ].join(' · '),
      status: [
        ?clock == null ? null : formatClock(clock),
        '${config.nameOf(state.turn)} to move',
      ].join(' · '),
      onResume: onResume,
    );
  }

  final GameState game;
  final Side orientation;
  final String title;
  final String details;
  final String status;
  final VoidCallback onResume;

  static String _clockLabel(TimeControl timeControl) =>
      timeControl.hasClock ? '${timeControl.kind} ${timeControl.label}' : 'No clock';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;

    return Semantics(
      container: true,
      label: 'Continue last game',
      // Sized by its content, not by the board: a line that wraps or a
      // larger system font can't push Resume out of the card.
      child: _Card(
        child: Row(
          spacing: AppSpacing.s4,
          children: [
            MoveWiseStaticBoard(
              fen: game.position.fen,
              size: 124,
              lastMove: game.lastMove,
              orientation: orientation,
              coordinates: false,
              borderRadius: BorderRadius.circular(10),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.s1,
                children: [
                  Text('CONTINUE GAME', style: type.overline.copyWith(color: colors.textSecondary)),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.heading.copyWith(height: 24 / 17),
                  ),
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                  Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.mono.copyWith(fontSize: 13, color: colors.textTertiary),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  FilledButton(
                    onPressed: onResume,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: type.heading.copyWith(fontSize: 15),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.s2,
                      children: [Text('Resume'), Icon(Icons.arrow_forward_rounded, size: 18)],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The main action, in the design's blue.
class _PlayCard extends StatelessWidget {
  const _PlayCard({required this.onTap});

  final VoidCallback onTap;

  // Not tokens: the design's own shades for this one card.
  static const _dark = (bg: Color(0xFF1C2A4A), border: Color(0xFF34466F), sub: Color(0xFFB4C4E8));
  static const _light = (bg: Color(0xFFDCE5FB), border: Color(0xFFB9C9F2), sub: Color(0xFF2A3F7A));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final tint = Theme.of(context).brightness == Brightness.dark ? _dark : _light;
    return Material(
      color: tint.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: tint.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        // At least 96 high; taller with a larger system font.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 96),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: AppSpacing.s3),
            child: Row(
              spacing: AppSpacing.s4,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors.focus,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.memory_rounded, size: 28, color: colors.onFocus),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.s1,
                    children: [
                      Text(
                        'Play vs Computer',
                        style: type.title.copyWith(fontSize: 20, height: 26 / 20, letterSpacing: 0),
                      ),
                      Text(
                        'Stockfish, 400 to 3000 Elo',
                        style: type.body.copyWith(fontSize: 14, color: tint.sub),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: tint.sub),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Import or Coach: icon on top, title and line underneath.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = context.type;
    return _Card(
      onTap: onTap,
      // At least 96 high inside the padding; taller with a larger system font.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 128 - 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.s4,
          children: [
            _IconTile(icon: icon, color: iconColor),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(title, style: type.heading.copyWith(fontSize: 16)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.label.copyWith(
                    fontWeight: FontWeight.w400,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// An icon, a title and a line, with a chevron: the stats and games rows.
class _RowHeader extends StatelessWidget {
  const _RowHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconSize = 40,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Row(
      spacing: 12,
      children: [
        _IconTile(icon: icon, color: colors.focus, size: iconSize),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(title, style: type.heading.copyWith(fontSize: 16)),
              Text(
                subtitle,
                style: type.label.copyWith(
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
      ],
    );
  }
}

/// Stats, with the top weakness from the last 20 games.
class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final light = Theme.of(context).brightness == Brightness.light;
    final weakness = ref.watch(homeWeaknessProvider);
    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          const _RowHeader(
            icon: Icons.bar_chart_rounded,
            title: 'Stats',
            subtitle: 'Last 20 games',
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: light ? colors.bgBase : colors.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.s2,
              children: [
                Text('TOP WEAKNESS', style: type.overline.copyWith(color: colors.resultLoss)),
                Text(switch (weakness) {
                  AsyncData(value: final w?) => '${w.title} — ${w.detail}',
                  AsyncData() => 'Review a few games to find your patterns.',
                  _ => '…',
                }, style: type.body.copyWith(height: 21 / 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The games list: not in the design, which has no way to it.
/// Under Scan a board, once something is saved: the saved positions.
class _SavedPositionsRow extends ConsumerWidget {
  const _SavedPositionsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(savedPositionsProvider).value?.length ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Card(
        onTap: onTap,
        child: _RowHeader(
          icon: Icons.bookmark_border_rounded,
          title: 'Saved positions',
          subtitle: '$count saved · carry on analysing',
        ),
      ),
    );
  }
}

class _GamesCard extends ConsumerWidget {
  const _GamesCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(savedGamesProvider).value?.length;
    return _Card(
      onTap: onTap,
      child: _RowHeader(
        icon: Icons.history_rounded,
        title: 'Games',
        subtitle: count == null ? 'Your saved games' : '$count saved · all, won and lost',
      ),
    );
  }
}
