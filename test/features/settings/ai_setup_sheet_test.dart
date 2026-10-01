import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/routing/app_router.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/settings/widgets/ai_setup_sheet.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// A screen with the setup actions, and a stand-in Settings that shows
  /// which section it was opened at.
  Future<void> pumpActions(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          // In a SafeArea, as on the real screens.
          builder: (_, _) => const Scaffold(
            body: SafeArea(child: Center(child: AiSetupActions())),
          ),
        ),
        GoRoute(
          path: Routes.settings,
          builder: (_, state) => Text('settings ${state.uri.queryParameters['section']}'),
        ),
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
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Why turn on the AI coach?'));
    await tester.pumpAndSettle();
  }

  testWidgets('the ⓘ explains, in plain words, what you get and why it is free', (tester) async {
    await pumpActions(tester);
    await openSheet(tester);

    for (final title in [
      'What you get',
      'Why do I need to do this?',
      'Is it really free?',
      'Is it safe?',
      'Why not just ask ChatGPT?',
      'Want more?',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('no card and no payment'), findsOneWidget);
    expect(find.textContaining('a code that switches the AI on'), findsOneWidget);
  });

  testWidgets('on a small phone the sheet fits: its top shows, the rest scrolls', (tester) async {
    await pumpActions(tester, size: const Size(320, 568));
    await openSheet(tester);

    expect(tester.getTopLeft(find.text('Turn on your AI coach')).dy, greaterThan(24));
    expect(tester.getBottomLeft(find.text('Not now')).dy, lessThan(568));
    await tester.scrollUntilVisible(find.text('Want more?'), 100);
    expect(find.text('Want more?'), findsOneWidget);
  });

  testWidgets('the sheet stays below the Dynamic Island', (tester) async {
    // An iPhone: 59 points of top safe area that the sheet must not cover.
    tester.view.padding = const FakeViewPadding(top: 59 * 3, bottom: 34 * 3);
    addTearDown(tester.view.resetPadding);
    await pumpActions(tester, size: const Size(393, 852));
    await openSheet(tester);

    expect(tester.getTopLeft(find.text('Turn on your AI coach')).dy, greaterThan(59 + 24));
    expect(tester.getBottomLeft(find.text('Not now')).dy, lessThan(852 - 34));
  });

  testWidgets('Turn on AI coach opens Settings at the AI Coach key', (tester) async {
    await pumpActions(tester);
    await openSheet(tester);
    await tester.tap(find.text('Turn on AI coach'));
    await tester.pumpAndSettle();

    expect(find.text('settings ai'), findsOneWidget);
  });

  testWidgets('Not now just closes the sheet', (tester) async {
    await pumpActions(tester);
    await openSheet(tester);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('What you get'), findsNothing);
    expect(find.text('Turn on AI coach (free)'), findsOneWidget);
  });

  testWidgets('Set up AI (free) goes straight to Settings', (tester) async {
    await pumpActions(tester);
    await tester.tap(find.text('Turn on AI coach (free)'));
    await tester.pumpAndSettle();

    expect(find.text('settings ai'), findsOneWidget);
  });
}
