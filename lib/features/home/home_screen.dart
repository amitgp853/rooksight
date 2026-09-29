import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/move_wise_board.dart';
import '../../core/routing/app_router.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_mark.dart';
import '../games/games_screen.dart' show savedGamesProvider;
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

/// Home (`design/source/Home.dc.html`, `HomeLight.dc.html`): the game to
/// continue, Play vs Computer, Import and Coach, and Stats with the top
/// weakness. Light mode outlines the cards.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final unfinished = ref.watch(unfinishedGameProvider);

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
            if (unfinished != null) ...[
              _ContinueCard(
                game: unfinished,
                onResume: () {
                  ref.read(resumeGameProvider).request();
                  open(Routes.game);
                },
              ),
              const SizedBox(height: AppSpacing.s4),
            ],
            _PlayCard(onTap: () => open(Routes.playSetup)),
            const SizedBox(height: AppSpacing.s4),
            Row(
              spacing: 12,
              children: [
                Expanded(
                  child: _Tile(
                    icon: Icons.download_rounded,
                    iconColor: colors.focus,
                    title: 'Import games',
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
            _StatsCard(onTap: () => open(Routes.stats)),
            const SizedBox(height: AppSpacing.s4),
            _GamesCard(onTap: () => open(Routes.games)),
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

/// A 40px rounded square with an icon, as in the design's tiles.
class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
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
  const _ContinueCard({required this.game, required this.onResume});

  final UnfinishedGame game;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final state = game.game;
    final config = game.config;
    final playerToMove = state.turn == config.playerSide;
    final clock = config.playerSide == Side.white ? game.white : game.black;
    final timeControl = config.timeControl;
    final details = [
      if (timeControl.hasClock) '${timeControl.kind} ${timeControl.label}' else 'No clock',
      'move ${state.position.fullmoves}',
      if (config.practice) 'practice',
    ].join(' · ');

    return Semantics(
      container: true,
      label: 'Continue last game',
      child: _Card(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s4,
            children: [
              MoveWiseStaticBoard(
                fen: state.position.fen,
                size: 124,
                lastMove: state.lastMove,
                orientation: config.playerSide,
                coordinates: false,
                borderRadius: BorderRadius.circular(10),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.s1,
                  children: [
                    Text(
                      'CONTINUE GAME',
                      style: type.overline.copyWith(color: colors.textSecondary),
                    ),
                    Text(
                      'vs Stockfish · ${config.level.elo}',
                      style: type.heading.copyWith(height: 24 / 17),
                    ),
                    Text(
                      details,
                      style: type.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      [
                        ?clock == null ? null : formatClock(clock),
                        playerToMove ? 'your turn' : 'Stockfish to move',
                      ].join(' · '),
                      style: type.mono.copyWith(fontSize: 13, color: colors.textTertiary),
                    ),
                    const Spacer(),
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
        child: SizedBox(
          height: 120,
          child: Padding(
            padding: const EdgeInsets.all(20),
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
      child: SizedBox(
        height: 128 - 32,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
  const _RowHeader({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Row(
      spacing: 12,
      children: [
        _IconTile(icon: icon, color: colors.focus),
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
