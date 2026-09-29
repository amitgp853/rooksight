import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/app.dart';
import 'package:move_wise/core/feedback/sound_player.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/core/routing/app_router.dart';
import 'package:move_wise/core/settings/display_settings.dart';
import 'package:move_wise/engine/engine_provider.dart';

import 'support/fake_engine.dart';
import 'support/fake_game_repository.dart';
import 'support/fake_sound_player.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessEngineProvider.overrideWithValue(FakeEngine()),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
        ],
        child: const MoveWiseApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(MoveWiseApp)));
  }

  testWidgets('starts on Home in dark mode', (tester) async {
    await pumpApp(tester);

    expect(find.text('MoveWise'), findsOneWidget);
    expect(find.text('Play vs Computer'), findsOneWidget);
    final context = tester.element(find.text('Play vs Computer'));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('switching theme mode rebuilds in light', (tester) async {
    final container = await pumpApp(tester);

    container.read(themeModeProvider.notifier).set(ThemeMode.light);
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Play vs Computer'));
    expect(Theme.of(context).brightness, Brightness.light);
  });

  testWidgets('every route builds', (tester) async {
    final container = await pumpApp(tester);
    final router = container.read(routerProvider);

    final expectedTitles = {
      Routes.playSetup: 'New game',
      Routes.game: 'vs Stockfish · 1600',
      Routes.import: 'Import games',
      Routes.review('g1'): 'Game review',
      Routes.coach: 'AI Coach',
      Routes.stats: 'Your stats',
      Routes.reportCard('g1'): 'Report card',
      Routes.settings: 'Settings',
      Routes.games: 'Games',
    };

    for (final MapEntry(key: path, value: title) in expectedTitles.entries) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text(title)),
        findsOneWidget,
        reason: path,
      );
      expect(tester.takeException(), isNull, reason: path);
    }
  });

  testWidgets('Home cards push a screen and back returns Home', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Import games'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Import games')),
      findsOneWidget,
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Play vs Computer'), findsOneWidget);
  });

  testWidgets('settings are written to the store', (tester) async {
    final store = SettingsStore.inMemory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessEngineProvider.overrideWithValue(FakeEngine()),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          settingsStoreProvider.overrideWithValue(store),
        ],
        child: const MoveWiseApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(MoveWiseApp)));

    container.read(themeModeProvider.notifier).set(ThemeMode.light);
    expect(store.get('themeMode'), 'light');
  });

  testWidgets('saved settings apply from the first frame', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessEngineProvider.overrideWithValue(FakeEngine()),
          soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          settingsStoreProvider.overrideWithValue(SettingsStore.inMemory({'themeMode': 'light'})),
        ],
        child: const MoveWiseApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Play vs Computer'));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
