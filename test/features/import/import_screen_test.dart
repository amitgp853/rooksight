import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/core/storage/import_log.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/import/data/chess_com_api.dart';
import 'package:rooksight/features/import/data/lichess_api.dart';
import 'package:rooksight/features/import/data/lichess_models.dart';
import 'package:rooksight/features/import/domain/importer.dart';
import 'package:rooksight/features/import/import_screen.dart';
import 'package:rooksight/features/play/domain/game_controller.dart';

import '../../support/fake_chess_com.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_lichess.dart';
import 'lichess_fixtures.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<SettingsStore> pumpImport(
    WidgetTester tester,
    FakeChessCom api, {
    String? savedUser,
    String? savedLichessUser,
    FakeLichess? lichess,
  }) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = SettingsStore.inMemory({
      'chesscom.username': ?savedUser,
      'lichess.username': ?savedLichessUser,
    });
    final router = GoRouter(
      initialLocation: '/import',
      routes: [
        GoRoute(path: '/import', builder: (_, _) => const ImportScreen()),
        GoRoute(path: '/games', builder: (_, _) => const Text('games list')),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chessComApiProvider.overrideWithValue(api),
          lichessApiProvider.overrideWithValue(lichess ?? FakeLichess(const [])),
          gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
          importLogProvider.overrideWithValue(FakeImportLog()),
          settingsStoreProvider.overrideWithValue(store),
          nowProvider.overrideWithValue(() => DateTime.utc(2026, 9, 15)),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('imports and offers to see the games', (tester) async {
    final api = FakeChessCom({
      '2026/09': [game('1'), game('2')],
    });
    final store = await pumpImport(tester, api);

    await tester.enterText(find.byType(TextField), 'fan');
    await tester.pump(); // The button enables on the next frame.
    await tester.tap(find.widgetWithText(FilledButton, 'Import games'));
    await tester.pumpAndSettle();

    expect(find.text('2 games imported'), findsOneWidget);
    expect(find.text('From Chess.com, last 3 months.'), findsOneWidget);
    expect(store.get('chesscom.username'), 'fan');

    await tester.tap(find.text('See your games'));
    await tester.pumpAndSettle();
    expect(find.text('games list'), findsOneWidget);
  });

  testWidgets('an unknown player gets a clear message', (tester) async {
    await pumpImport(tester, FakeChessCom({}, failure: const PlayerNotFound('nobodyy')));

    await tester.enterText(find.byType(TextField), 'nobodyy');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import games'));
    await tester.pumpAndSettle();

    // Shown on the form, under the field.
    expect(find.textContaining('No Chess.com player called “nobodyy”'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();
    expect(find.textContaining('No Chess.com player'), findsNothing, reason: 'cleared by editing');
  });

  testWidgets('offline: says so, and the form stays ready to try again', (tester) async {
    await pumpImport(tester, FakeChessCom({}, failure: const Offline()));

    await tester.enterText(find.byType(TextField), 'fan');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Import games'));
    await tester.pumpAndSettle();

    expect(find.text('You’re offline'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Import games'), findsOneWidget);
  });

  testWidgets('remembers the last username', (tester) async {
    await pumpImport(tester, FakeChessCom({}), savedUser: 'fan');
    expect(find.text('fan'), findsOneWidget);
  });

  group('Lichess', () {
    testWidgets('the switch keeps each site’s own username', (tester) async {
      await pumpImport(
        tester,
        FakeChessCom(const {}),
        savedUser: 'chess_fan',
        savedLichessUser: 'lichess_fan',
      );
      expect(find.text('CHESS.COM USERNAME'), findsOneWidget);
      expect(find.text('chess_fan'), findsOneWidget);

      await tester.tap(find.text('Lichess'));
      await tester.pumpAndSettle();
      expect(find.text('LICHESS USERNAME'), findsOneWidget);
      expect(find.text('lichess_fan'), findsOneWidget);
    });

    testWidgets('imports from Lichess and saves that username', (tester) async {
      final store = await pumpImport(
        tester,
        FakeChessCom(const {}),
        lichess: FakeLichess([
          LichessGame.fromJson(
            lichessGame(
              white: 'lichess_fan',
              createdAt: DateTime.utc(2026, 9, 10).millisecondsSinceEpoch,
            ),
          ),
        ]),
      );
      await tester.tap(find.text('Lichess'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'lichess_fan');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Import games'));
      await tester.pumpAndSettle();

      expect(find.text('1 game imported'), findsOneWidget);
      expect(find.text('From Lichess, last 3 months.'), findsOneWidget);
      expect(store.get('lichess.username'), 'lichess_fan');
      expect(store.get('chesscom.username'), isNull);
    });
  });

  test('each range says what it covers, by month or by date', () {
    final now = DateTime(2026, 9, 29);
    expect(rangeDetail(ImportRange.last3Months, ImportPlatform.chessCom, now), 'Since Jul 2026');
    expect(rangeDetail(ImportRange.lastMonth, ImportPlatform.chessCom, now), 'Since Sep 2026');
    expect(rangeDetail(ImportRange.last3Months, ImportPlatform.lichess, now), 'Since 1 Jul');
    expect(rangeDetail(ImportRange.last12Months, ImportPlatform.lichess, now), 'Since 29 Sep 2025');
    expect(rangeDetail(ImportRange.everything, ImportPlatform.lichess, now), 'Your whole history');
  });
}
