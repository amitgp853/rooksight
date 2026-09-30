import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../storage/saved_position_repository.dart';

import '../../features/analysis/analysis_screen.dart';
import '../../features/analysis/domain/analysis_args.dart';
import '../../features/analysis/saved_positions_screen.dart';
import '../../features/coach/chats_screen.dart';
import '../../features/coach/coach_screen.dart';
import '../../features/games/games_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/import/domain/importer.dart' show ImportPlatform;
import '../../features/import/import_screen.dart';
import '../../features/pass_play/pass_game_screen.dart';
import '../../features/pass_play/pass_setup_screen.dart';
import '../../features/play/game_screen.dart';
import '../../features/play/play_setup_screen.dart';
import '../../features/report_card/report_card_screen.dart';
import '../../features/review/review_screen.dart';
import '../../features/scan/scan_check_screen.dart';
import '../../features/scan/scan_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/stats/stats_screen.dart';

/// Route paths. Use these instead of string literals.
abstract final class Routes {
  static const home = '/';
  static const playSetup = '/play';

  /// Play setup for a game starting from [fen] (e.g. from the analysis
  /// board).
  static String playFrom(String fen) =>
      Uri(path: playSetup, queryParameters: {'fen': fen}).toString();

  /// Scan a board: camera, crop, reading.
  static const scan = '/scan';

  /// Check or set up a position; takes a `ScanCheckArgs` as `extra`.
  static const scanCheck = '/scan/check';

  /// Positions saved from the analysis board.
  static const savedPositions = '/positions';
  static const game = '/play/game';
  static const passSetup = '/pass';
  static const passGame = '/pass/game';
  static const import = '/import';

  /// The import, opened on Lichess.
  static const importLichess = '/import?from=lichess';
  static const coach = '/coach';

  /// The saved AI Coach chats.
  static const coachChats = '/coach/chats';

  /// A saved AI Coach chat, to read and continue.
  static String coachChat(int id) => '/coach/chats/$id';
  static const stats = '/stats';
  static const games = '/games';
  static const settings = '/settings';

  /// The review of a game, opened [ply] moves in (at the end by default).
  static String review(String gameId, {int? ply}) =>
      ply == null ? '/review/$gameId' : '/review/$gameId?ply=$ply';

  /// Only the games in [shown], under [title]. Each opens its review at the
  /// move given (or at the end).
  static String gamesShowing(String title, Map<int, int?> shown) => Uri(
    path: games,
    queryParameters: {
      'title': title,
      'ids': [
        for (final MapEntry(key: id, value: move) in shown.entries)
          move == null ? '$id' : '$id-$move',
      ].join(','),
    },
  ).toString();

  /// The coach with [question] ready to send.
  static String coachAsking(String question) =>
      Uri(path: coach, queryParameters: {'q': question}).toString();

  /// The coach with a game attached, and a question about move [index] of it
  /// ready to send when given.
  static String coachAbout(int gameId, [int? index]) =>
      index == null ? '/coach?game=$gameId' : '/coach?game=$gameId&move=$index';
  static String reportCard(String gameId) => '/report/$gameId';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: Routes.home,
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: Routes.playSetup,
        builder: (context, state) => PlaySetupScreen(startFen: state.uri.queryParameters['fen']),
      ),
      GoRoute(path: Routes.scan, builder: (context, state) => const ScanScreen()),
      GoRoute(
        path: Routes.scanCheck,
        builder: (context, state) => ScanCheckScreen(
          args: state.extra is ScanCheckArgs
              ? state.extra! as ScanCheckArgs
              : const ScanCheckArgs(edit: true),
        ),
      ),
      GoRoute(
        path: AnalysisArgs.path,
        builder: (context, state) => AnalysisScreen(
          args: AnalysisArgs.fromQuery(state.uri.queryParameters),
          saved: state.extra is SavedPosition ? state.extra! as SavedPosition : null,
        ),
      ),
      GoRoute(
        path: Routes.savedPositions,
        builder: (context, state) => const SavedPositionsScreen(),
      ),
      GoRoute(path: Routes.game, builder: (context, state) => const GameScreen()),
      GoRoute(path: Routes.passSetup, builder: (context, state) => const PassSetupScreen()),
      GoRoute(path: Routes.passGame, builder: (context, state) => const PassGameScreen()),
      GoRoute(
        path: Routes.import,
        builder: (context, state) => ImportScreen(
          platform: state.uri.queryParameters['from'] == 'lichess'
              ? ImportPlatform.lichess
              : ImportPlatform.chessCom,
        ),
      ),
      GoRoute(
        path: '/review/:gameId',
        builder: (context, state) => ReviewScreen(
          gameId: state.pathParameters['gameId']!,
          initialPly: int.tryParse(state.uri.queryParameters['ply'] ?? ''),
        ),
      ),
      GoRoute(
        path: Routes.coach,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return CoachScreen(
            gameId: int.tryParse(query['game'] ?? ''),
            moveIndex: int.tryParse(query['move'] ?? ''),
            question: query['q'],
          );
        },
      ),
      GoRoute(path: Routes.coachChats, builder: (context, state) => const ChatsScreen()),
      GoRoute(
        path: '/coach/chats/:id',
        builder: (context, state) =>
            CoachScreen(chatId: int.tryParse(state.pathParameters['id'] ?? '')),
      ),
      GoRoute(path: Routes.stats, builder: (context, state) => const StatsScreen()),
      GoRoute(
        path: '/report/:gameId',
        builder: (context, state) => ReportCardScreen(gameId: state.pathParameters['gameId']!),
      ),
      GoRoute(
        path: Routes.games,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return GamesScreen(title: query['title'], only: GamesScreen.parseIds(query['ids']));
        },
      ),
      GoRoute(path: Routes.settings, builder: (context, state) => const SettingsScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
