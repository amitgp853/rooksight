import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/widgets/dialog_buttons.dart';
import 'package:rooksight/core/feedback/sound_player.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/pass_play/domain/pass_config.dart';
import 'package:rooksight/features/pass_play/domain/pass_controller.dart';
import 'package:rooksight/features/pass_play/pass_game_screen.dart';
import 'package:rooksight/features/pass_play/pass_setup_screen.dart';
import 'package:rooksight/features/play/domain/game_config.dart';
import 'package:rooksight/features/play/domain/game_result.dart';

import '../../support/fake_game_repository.dart';
import '../../support/fake_sound_player.dart';

/// No clock by default: a running clock repaints forever, so `pumpAndSettle`
/// would never settle.
final _untimed = PassConfig.initial.copyWith(timeControl: TimeControl.none);

/// The message under the board is whole in view: not clipped, no scrolling.
void expectMessageFits(WidgetTester tester, Finder text) {
  final card = find.ancestor(of: text, matching: find.byType(Container)).first;
  final strip = find.ancestor(of: text, matching: find.byType(SingleChildScrollView)).first;
  final cardRect = tester.getRect(card);
  final stripRect = tester.getRect(strip);
  expect(cardRect.top, greaterThanOrEqualTo(stripRect.top), reason: 'top cut off');
  expect(cardRect.bottom, lessThanOrEqualTo(stripRect.bottom), reason: 'bottom cut off');
}

/// A real phone's status bar and home indicator, which shrink the room
/// left under the board.
Future<void> withPhoneInsets(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(top: 47 * 3, bottom: 34 * 3);
  addTearDown(tester.view.resetPadding);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('setup', () {
    Future<ProviderContainer> pumpSetup(WidgetTester tester) async {
      phoneSize(tester);
      final router = GoRouter(
        initialLocation: '/pass',
        routes: [
          GoRoute(path: '/pass', builder: (_, _) => const PassSetupScreen()),
          GoRoute(path: '/pass/game', builder: (_, _) => const Text('game started')),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [settingsStoreProvider.overrideWithValue(SettingsStore.inMemory())],
          child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(tester.element(find.byType(PassSetupScreen)));
    }

    testWidgets('defaults: You vs Opponent, 10+5, auto-flip and takebacks on', (tester) async {
      await pumpSetup(tester);
      expect(find.text('White · moves first'), findsOneWidget);
      expect(find.text('Start · You plays White'), findsOneWidget);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value);
      expect(switches, [true, false, true]);
    });

    testWidgets('face-to-face turns auto-flip off', (tester) async {
      await pumpSetup(tester);
      await tester.tap(find.text('Face-to-face layout'));
      await tester.pump();
      final switches = tester.widgetList<Switch>(find.byType(Switch)).map((s) => s.value);
      expect(switches, [false, true, true]);
    });

    testWidgets('names, swap and clock are kept for the game', (tester) async {
      final container = await pumpSetup(tester);
      await tester.enterText(find.byType(TextField).last, 'Ann');
      await tester.tap(find.byTooltip('Swap colours'));
      await tester.tap(find.text('5+0'));
      await tester.pump();
      expect(find.text('Start · Ann plays White'), findsOneWidget);

      await tester.tap(find.text('Start · Ann plays White'));
      await tester.pumpAndSettle();

      final config = container.read(passConfigProvider);
      expect(config.firstName, 'You');
      expect(config.secondName, 'Ann');
      expect(config.firstSide, Side.black);
      expect(config.timeControl.label, '5+0');
      expect(find.text('game started'), findsOneWidget);
    });
  });

  group('game', () {
    Future<ProviderContainer> pumpGame(WidgetTester tester, {PassConfig? config}) async {
      phoneSize(tester);
      final store = SettingsStore.inMemory();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(store),
            soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
            gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          ],
          child: MaterialApp(theme: AppTheme.dark(), home: const _Start()),
        ),
      );
      final container = ProviderScope.containerOf(tester.element(find.byType(_Start)));
      container.read(passConfigProvider.notifier).set(config ?? _untimed);
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      return container;
    }

    /// Centre of [square], with [bottom]'s pieces at the bottom.
    Offset squareCentre(WidgetTester tester, Square square, {Side bottom = Side.white}) {
      final rect = tester.getRect(find.byType(Chessboard));
      final size = rect.width / 8;
      final file = bottom == Side.white ? square.file : 7 - square.file;
      final rank = bottom == Side.white ? square.rank : 7 - square.rank;
      return rect.topLeft + Offset((file + 0.5) * size, (7 - rank + 0.5) * size);
    }

    Future<void> tapMove(
      WidgetTester tester,
      Square from,
      Square to, {
      Side bottom = Side.white,
    }) async {
      await tester.tapAt(squareCentre(tester, from, bottom: bottom));
      await tester.pump();
      await tester.tapAt(squareCentre(tester, to, bottom: bottom));
      await tester.pumpAndSettle();
    }

    double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text)).dy;

    testWidgets('after a move the board turns for the other player', (tester) async {
      final container = await pumpGame(tester);
      expect(top(tester, 'Opponent'), lessThan(top(tester, 'You')));
      expect(find.text('Your move · White'), findsOneWidget);

      await tapMove(tester, Square.e2, Square.e4);
      // The board turns 400ms after the piece lands.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      expect(container.read(passControllerProvider).game.moves.single.san, 'e4');
      expect(top(tester, 'You'), lessThan(top(tester, 'Opponent')));
      expect(find.text('Board turned for Opponent. Pass the phone.'), findsOneWidget);
      expect(find.text('Your move · Black'), findsOneWidget);

      // Black plays from their side of the board.
      await tapMove(tester, Square.e7, Square.e5, bottom: Side.black);
      expect(container.read(passControllerProvider).game.moves, hasLength(2));
    });

    testWidgets('without auto-flip the board stays put', (tester) async {
      await pumpGame(tester, config: _untimed.copyWith(autoFlip: false));
      await tapMove(tester, Square.e2, Square.e4);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
      expect(top(tester, 'Opponent'), lessThan(top(tester, 'You')));
      expect(find.textContaining('Pass the phone'), findsNothing);
    });

    testWidgets('Pause hides the board until resumed', (tester) async {
      final container = await pumpGame(tester);
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();
      expect(find.text('Game paused'), findsOneWidget);

      await tester.tap(find.text('Resume · You to move'));
      await tester.pumpAndSettle();
      expect(find.text('Game paused'), findsNothing);
      expect(container.read(passControllerProvider).paused, isFalse);
    });

    testWidgets('a draw offer asks the other player', (tester) async {
      final container = await pumpGame(tester);
      await tester.tap(find.text('Draw'));
      await tester.pumpAndSettle();
      // Asked first: a stray tap shouldn't offer anything.
      expect(find.text('Offer a draw?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Offer draw'));
      await tester.pumpAndSettle();
      expect(find.text('You offer a draw'), findsOneWidget);
      expect(find.text('Opponent, do you accept?'), findsOneWidget);

      await tester.tap(find.text('Accept draw'));
      await tester.pump(const Duration(milliseconds: 600)); // The final position holds.
      await tester.pumpAndSettle();
      expect(
        container.read(passControllerProvider).game.result,
        const GameResult.draw(GameEndReason.agreement),
      );
      expect(find.text('Draw agreed'.toUpperCase()), findsOneWidget, reason: 'result sheet');
      expect(find.text('Rematch · swap colours'), findsOneWidget);
    });

    testWidgets('resigning is asked first; Cancel keeps the game going', (tester) async {
      final container = await pumpGame(tester);
      await tester.tap(find.text('Resign'));
      await tester.pumpAndSettle();
      expect(find.text('Resign this game?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(container.read(passControllerProvider).game.isOver, isFalse);

      await tester.tap(find.text('Resign'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DestructiveButton, 'Resign'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(container.read(passControllerProvider).game.isOver, isTrue);
    });

    testWidgets('a takeback needs the other player to allow it', (tester) async {
      final container = await pumpGame(tester);
      await tapMove(tester, Square.e2, Square.e4);
      await tester.tap(find.text('Takeback'));
      await tester.pumpAndSettle();
      expect(find.text('You ask to take back 1. e4'), findsOneWidget);

      await tester.tap(find.text('Allow takeback'));
      await tester.pumpAndSettle();
      expect(container.read(passControllerProvider).game.moves, isEmpty);
      expect(top(tester, 'Opponent'), lessThan(top(tester, 'You')), reason: 'back to White');
    });

    testWidgets('game over: the result notice fits whole under the board', (tester) async {
      final container = await pumpGame(tester);
      await withPhoneInsets(tester);
      container.read(passControllerProvider.notifier).resign(Side.black);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Rematch · swap colours'))).pop(); // The sheet.
      await tester.pumpAndSettle();

      expect(find.text('See result'), findsOneWidget);
      expectMessageFits(tester, find.text('See result'));
    });

    testWidgets('face to face, game over: a header, and the result on the near side only', (
      tester,
    ) async {
      final container = await pumpGame(tester, config: _untimed.withFaceToFace(true));
      expect(find.byType(AppBar), findsNothing);

      container.read(passControllerProvider.notifier).resign(Side.black);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Rematch · swap colours'))).pop(); // The sheet.
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('See result'), findsOneWidget);
      expect(find.byTooltip('Leave game'), findsNothing, reason: 'the header has Back');
    });

    testWidgets('face to face: a panel each, the top one turned', (tester) async {
      await pumpGame(tester, config: _untimed.withFaceToFace(true));
      expect(find.text('Resign'), findsNWidgets(2));
      // Either player can pause or leave, from their own side.
      expect(find.byTooltip('Pause both clocks'), findsNWidgets(2));
      expect(find.byTooltip('Leave game'), findsNWidgets(2));
      // The board stays put; its pieces turn to face the player to move.
      final board = tester.widget<Chessboard>(find.byType(Chessboard));
      expect(board.settings.pieceOrientationBehavior, PieceOrientationBehavior.sideToPlay);
      final turned = find.ancestor(of: find.text('Opponent'), matching: find.byType(RotatedBox));
      expect(tester.widget<RotatedBox>(turned.first).quarterTurns, 2);
      expect(find.ancestor(of: find.text('You'), matching: find.byType(RotatedBox)), findsNothing);
    });
  });
}

/// Opens the game screen on tap, after the test has set the config.
class _Start extends StatelessWidget {
  const _Start();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const PassGameScreen())),
      child: const Text('start'),
    ),
  );
}
