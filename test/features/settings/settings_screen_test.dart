import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/llm/gemini_key.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/core/theme/board_themes.dart';
import 'package:move_wise/core/settings/display_settings.dart';
import 'package:move_wise/features/import/import_controller.dart';
import 'package:move_wise/features/settings/settings_screen.dart';

import '../../support/fake_llm.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late SettingsStore store;
  late FakeLlm llm;
  late MemoryGeminiKeyStorage keys;

  const key = 'AIzaSyD-example-key-3f9a';

  setUp(() {
    store = SettingsStore.inMemory();
    llm = FakeLlm(reply: 'OK');
    keys = MemoryGeminiKeyStorage(key);
  });

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/import',
          builder: (_, state) => Text(
            state.uri.queryParameters['from'] == 'lichess'
                ? 'import screen lichess'
                : 'import screen',
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(store),
          llmClientProvider.overrideWithValue(llm),
          geminiKeyStorageProvider.overrideWithValue(keys),
          savedGeminiKeyAtStartProvider.overrideWithValue(keys.key),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)));
  }

  /// Scrolls [finder] fully into view.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('Import saves the username and opens the import', (tester) async {
    final container = await pumpSettings(tester);
    await tester.enterText(find.byType(TextField).first, '  magnus_fan ');
    await tester.tap(find.text('Import').first);
    await tester.pumpAndSettle();

    expect(container.read(chessComUsernameProvider), 'magnus_fan');
    expect(find.text('import screen'), findsOneWidget);
  });

  group('Gemini key (developer mode)', () {
    Finder keyField() => find.widgetWithText(TextField, 'Paste your key');

    setUp(() => store = SettingsStore.inMemory({'developerMode': 'true'}));

    /// Scrolls down to the AI Coach section, at the bottom.
    Future<void> toKeyCard(WidgetTester tester) => reveal(tester, find.text('AI Coach key (Gemini)'));

    testWidgets('a saved key is masked, and can be shown', (tester) async {
      await pumpSettings(tester);
      await toKeyCard(tester);
      expect(find.text('••••••••••••3f9a'), findsOneWidget);
      expect(find.text(key), findsNothing);

      await reveal(tester, find.byTooltip('Show key'));
      await tester.tap(find.byTooltip('Show key'));
      await tester.pump();
      expect(find.text(key), findsOneWidget);
    });

    testWidgets('Test key: one request, and the badge when it works', (tester) async {
      await pumpSettings(tester);
      await reveal(tester, find.text('Test key'));
      await tester.tap(find.text('Test key'));
      await tester.pumpAndSettle();
      expect(llm.requests, hasLength(1));
      expect(find.text('Key works'), findsOneWidget);
    });

    testWidgets('a rejected key says so', (tester) async {
      llm.failure = const LlmInvalidKey();
      await pumpSettings(tester);
      await reveal(tester, find.text('Test key'));
      await tester.tap(find.text('Test key'));
      await tester.pumpAndSettle();
      expect(find.textContaining('rejected'), findsOneWidget);
      expect(find.text('Key works'), findsNothing);
    });

    testWidgets('without a key: paste one, it is saved and tested', (tester) async {
      keys = MemoryGeminiKeyStorage();
      final container = await pumpSettings(tester);
      await toKeyCard(tester);
      expect(find.text('Test key'), findsNothing);

      await reveal(tester, keyField());
      await tester.enterText(keyField(), '  AIzaNewKey1234 ');
      await tester.pump(); // Save turns on once there's text.
      await reveal(tester, find.text('Save key'));
      await tester.tap(find.text('Save key'));
      await tester.pumpAndSettle();

      expect(keys.key, 'AIzaNewKey1234');
      expect(container.read(geminiKeyProvider), 'AIzaNewKey1234');
      expect(container.read(llmConfiguredProvider), isTrue);
      expect(llm.requests, hasLength(1), reason: 'tested straight away');
      expect(find.text('Key works'), findsOneWidget);
    });

    testWidgets('Remove forgets the key, with an undo', (tester) async {
      final container = await pumpSettings(tester);
      await reveal(tester, find.text('Remove'));
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(keys.key, isNull);
      expect(container.read(llmConfiguredProvider), isFalse);
      expect(keyField(), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(keys.key, key);
      expect(find.text('Test key'), findsOneWidget);
    });

    testWidgets('without a key the steps are open, with links', (tester) async {
      keys = MemoryGeminiKeyStorage();
      await pumpSettings(tester);
      await reveal(tester, find.text('About the free-tier limits'));
      expect(find.text('How to get a free key'), findsOneWidget);
      expect(find.text('aistudio.google.com/apikey'), findsOneWidget);
    });

    testWidgets('with a key they fold away, a tap from open', (tester) async {
      await pumpSettings(tester);
      await reveal(tester, find.text('How to get a free key'));
      expect(find.text('aistudio.google.com/apikey'), findsNothing);
      await tester.tap(find.text('How to get a free key'));
      await tester.pumpAndSettle();
      expect(find.text('aistudio.google.com/apikey'), findsOneWidget);
    });
  });

  testWidgets('Haptic feedback can be turned off', (tester) async {
    final container = await pumpSettings(tester);
    final haptics = find.widgetWithText(SwitchListTile, 'Haptic feedback');
    await reveal(tester, haptics);
    await tester.tap(haptics);
    await tester.pumpAndSettle();
    expect(container.read(hapticsEnabledProvider), isFalse);
  });

  testWidgets('the AI Coach key setup shows only in developer mode', (tester) async {
    final container = await pumpSettings(tester);
    final developer = find.widgetWithText(SwitchListTile, 'Developer mode');
    await reveal(tester, developer);
    expect(find.text('AI Coach key (Gemini)'), findsNothing, reason: 'hidden by default');

    await tester.tap(developer);
    await tester.pumpAndSettle();
    expect(container.read(developerModeProvider), isTrue);
    await reveal(tester, find.text('AI Coach key (Gemini)'));
    expect(find.textContaining('dart-define'), findsNothing, reason: 'no build details');
  });

  testWidgets('picking a board theme and a mode', (tester) async {
    final container = await pumpSettings(tester);
    await reveal(tester, find.text('Ember'));
    await tester.tap(find.text('Ember'));
    await tester.pumpAndSettle();
    expect(container.read(boardThemeProvider), BoardTheme.ember);

    await reveal(tester, find.text('Light'));
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(container.read(themeModeProvider), ThemeMode.light);
  });

  testWidgets('the footer shows the version', (tester) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(
      find.textContaining('Stockfish runs on your device'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('MoveWise 0.1.0 · Stockfish runs on your device'), findsOneWidget);
  });

  testWidgets('one username per site, each with its own Import', (tester) async {
    final container = await pumpSettings(tester);
    expect(find.text('Chess.com username'), findsOneWidget);
    expect(find.text('Lichess username'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), 'lichess_fan');
    await tester.tap(find.text('Import').at(1));
    await tester.pumpAndSettle();

    expect(container.read(lichessUsernameProvider), 'lichess_fan');
    expect(container.read(chessComUsernameProvider), isEmpty);
    expect(find.text('import screen lichess'), findsOneWidget);
  });
}
