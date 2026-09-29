import 'dart:io' as io;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/board/board_style.dart';
import 'package:move_wise/core/feedback/sound_player.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/settings/display_settings.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/features/play/domain/game_config.dart';
import 'package:move_wise/features/play/domain/game_controller.dart';
import 'package:move_wise/features/play/game_screen.dart';

import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_sound_player.dart';

/// Starts games with a fixed config.
class _Config extends GameConfigNotifier {
  _Config(this.config);

  final GameConfig config;

  @override
  GameConfig build() => config;
}

/// No clock by default: a running clock repaints forever, so `pumpAndSettle`
/// would never settle.
final _untimed = GameConfig.initial.copyWith(timeControl: TimeControl.none);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pumpGame(
    WidgetTester tester, {
    FakeEngine? engine,
    GameConfig? config,
    FakeSoundPlayer? sounds,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessEngineProvider.overrideWithValue(engine ?? FakeEngine()),
          gameConfigProvider.overrideWith(() => _Config(config ?? _untimed)),
          soundPlayerProvider.overrideWithValue(sounds ?? FakeSoundPlayer()),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        ],
        child: MaterialApp(theme: AppTheme.dark(), home: const GameScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(GameScreen)));
  }

  /// Centre of [square] on the board, with White at the bottom.
  Offset squareCentre(WidgetTester tester, Square square) {
    final rect = tester.getRect(find.byType(Chessboard));
    final size = rect.width / 8;
    return rect.topLeft + Offset((square.file + 0.5) * size, (7 - square.rank + 0.5) * size);
  }

  Future<void> tapMove(WidgetTester tester, Square from, Square to) async {
    await tester.tapAt(squareCentre(tester, from));
    await tester.pump();
    await tester.tapAt(squareCentre(tester, to));
    await tester.pumpAndSettle();
  }

  testWidgets('board fills the phone width', (tester) async {
    await pumpGame(tester);
    expect(tester.getSize(find.byType(Chessboard)).width, 390);
  });

  testWidgets('tap-to-move plays a move and lists it', (tester) async {
    final container = await pumpGame(tester);

    await tapMove(tester, Square.e2, Square.e4);

    final moves = container.read(gameControllerProvider).game.moves;
    expect(moves.first.san, 'e4');
    expect(moves, hasLength(2), reason: 'Stockfish replied');
    expect(find.text('1.'), findsOneWidget);
    expect(find.text('e4'), findsOneWidget);
  });

  testWidgets('an illegal tap does not move', (tester) async {
    final container = await pumpGame(tester);

    await tapMove(tester, Square.e2, Square.e5);

    expect(container.read(gameControllerProvider).game.moves, isEmpty);
  });

  testWidgets('flip swaps the player lines', (tester) async {
    await pumpGame(tester);
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('Stockfish'), lessThan(top('You')));

    await tester.tap(find.text('Flip'));
    await tester.pumpAndSettle();

    expect(top('You'), lessThan(top('Stockfish')));
  });

  testWidgets('Hint shows the brass arrow and its text', (tester) async {
    await pumpGame(tester, engine: FakeEngine(reply: (_) => [line('g1f3')]));

    await tester.tap(find.text('Hint'));
    await tester.pumpAndSettle();

    expect(find.text('Look at your knight on g1.'), findsOneWidget);
    final board = tester.widget<Chessboard>(find.byType(Chessboard));
    expect(board.shapes.whereType<Arrow>().single.dest, Square.f3);
  });

  testWidgets('clocks show the time control and count down', (tester) async {
    await pumpGame(
      tester,
      config: GameConfig.initial.copyWith(timeControl: TimeControl.options.first),
    );
    expect(find.text('03:00'), findsNWidgets(2));
    expect(find.text('Blitz 3+2'), findsOneWidget);
  });

  testWidgets('resigning shows the result sheet after a short hold', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('RESIGNATION'), findsNothing, reason: 'final position held for 600ms');

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text('RESIGNATION'), findsOneWidget);
    expect(find.text('You resigned'), findsWidgets);
    expect(find.text('Review with AI Coach'), findsOneWidget);

    await tester.tap(find.text('Rematch'));
    await tester.pumpAndSettle();
    expect(find.text('RESIGNATION'), findsNothing);
    expect(find.text('Your move'), findsOneWidget);
  });

  testWidgets('locked Undo opens the options sheet to turn on practice', (tester) async {
    final container = await pumpGame(tester);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turn on practice mode'));
    await tester.pumpAndSettle();

    expect(container.read(gameControllerProvider).config.practice, isTrue);
    expect(find.textContaining('Practice'), findsOneWidget);
  });

  testWidgets('a declined draw offer shows a notice', (tester) async {
    await pumpGame(tester);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offer draw'));
    await tester.pumpAndSettle();

    expect(find.text('Stockfish declined the draw.'), findsOneWidget);
  });

  testWidgets('each move plays its sound, from either side', (tester) async {
    final sounds = FakeSoundPlayer();
    await pumpGame(
      tester,
      sounds: sounds,
      engine: FakeEngine(reply: (_) => [line('d7d5')]),
    );

    await tapMove(tester, Square.e2, Square.e4); // Stockfish answers ...d5.
    await tapMove(tester, Square.e4, Square.d5); // exd5

    // Each slides (a glide), then lands with its own sound.
    expect(sounds.played, [
      GameSound.glide,
      GameSound.move,
      GameSound.glide,
      GameSound.move,
      GameSound.glide,
      GameSound.capture,
    ]);
  });

  testWidgets('the landing sound waits for the sliding piece to arrive', (tester) async {
    final sounds = FakeSoundPlayer();
    await pumpGame(tester, sounds: sounds);

    await tester.tapAt(squareCentre(tester, Square.e2));
    await tester.pump();
    await tester.tapAt(squareCentre(tester, Square.e4));
    await tester.pump();
    expect(sounds.played, [GameSound.glide], reason: 'the piece is still travelling');

    await tester.pump(moveSlide);
    expect(sounds.played, [GameSound.glide, GameSound.move]);
    await tester.pump(const Duration(seconds: 1)); // Stockfish replies and lands.
    await tester.pumpAndSettle();
  });

  testWidgets('with reduced motion nothing slides: it lands at once', (tester) async {
    final sounds = FakeSoundPlayer();
    final container = await pumpGame(tester, sounds: sounds);
    container.read(reduceMotionSettingProvider.notifier).set(true);
    await tester.pump();

    await tester.tapAt(squareCentre(tester, Square.e2));
    await tester.pump();
    await tester.tapAt(squareCentre(tester, Square.e4));
    await tester.pump();
    expect(sounds.played, [GameSound.move]);
    await tester.pump(const Duration(seconds: 1)); // Stockfish replies.
    await tester.pumpAndSettle();
    expect(sounds.played, [GameSound.move, GameSound.move], reason: 'its reply lands at once too');
  });

  group('vibration', () {
    late List<String> vibrations;

    setUp(() {
      vibrations = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') vibrations.add('${call.arguments}');
          return null;
        },
      );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
    });

    testWidgets('a move lands with a light tap', (tester) async {
      await pumpGame(tester);
      await tapMove(tester, Square.e2, Square.e4);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(vibrations, contains('HapticFeedbackType.lightImpact'));
    });

    testWidgets('none at all when Vibration is off', (tester) async {
      final container = await pumpGame(tester);
      container.read(hapticsEnabledProvider.notifier).set(false);
      await tapMove(tester, Square.e2, Square.e4);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(vibrations, isEmpty);
    });
  });

  test('every sound has all its takes', () {
    for (final sound in GameSound.values) {
      for (var take = 1; take <= GameSound.takes; take++) {
        expect(io.File(sound.asset(take)).existsSync(), isTrue, reason: sound.asset(take));
      }
    }
  });

  testWidgets('no sounds when sound is off', (tester) async {
    final sounds = FakeSoundPlayer();
    final container = await pumpGame(tester, sounds: sounds);
    container.read(soundEnabledProvider.notifier).set(false);

    await tapMove(tester, Square.e2, Square.e4);

    expect(sounds.played, isEmpty);
  });

  testWidgets('Review on the result sheet is enabled once the game is saved', (tester) async {
    await pumpGame(tester);
    await tapMove(tester, Square.e2, Square.e4); // Stockfish replies.

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resign'));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    final review = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Review with AI Coach'),
    );
    expect(review.onPressed, isNotNull);
  });
}
