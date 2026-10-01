import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/app.dart';
import 'package:rooksight/core/feedback/sound_player.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/routing/app_router.dart';
import 'package:rooksight/core/settings/display_settings.dart';
import 'package:rooksight/engine/engine_provider.dart';

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
        child: const RooksightApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(RooksightApp)));
  }

  testWidgets('starts on Home in dark mode', (tester) async {
    await pumpApp(tester);

    expect(find.text('Rooksight'), findsOneWidget);
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
      Routes.playSetup: 'New Game',
      Routes.game: 'vs Stockfish · 1600',
      Routes.import: 'Import Games',
      Routes.review('g1'): 'Game Review',
      Routes.coach: 'AI Coach',
      Routes.stats: 'Your Stats',
      Routes.reportCard('g1'): 'Report Card',
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

    await tester.tap(find.text('Import Games'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Import Games')),
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
        child: const RooksightApp(),
      ),
    );
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(RooksightApp)));

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
        child: const RooksightApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.text('Play vs Computer'));
    expect(Theme.of(context).brightness, Brightness.light);
  });
}
