import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/core/routing/app_router.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/features/scan/domain/board_reader.dart';
import 'package:move_wise/features/scan/domain/board_setup.dart';
import 'package:move_wise/features/scan/domain/scan_photo.dart';
import 'package:move_wise/features/scan/scan_check_screen.dart';
import 'package:move_wise/features/scan/scan_screen.dart';

import '../../support/fake_llm.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pump(WidgetTester tester, Widget home, {bool hasKey = true, LlmClient? llm}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: Routes.scanCheck,
          builder: (_, state) => ScanCheckScreen(args: state.extra! as ScanCheckArgs),
        ),
        GoRoute(path: '/analysis', builder: (_, state) => Text('analysis ${state.uri.query}')),
        GoRoute(path: Routes.settings, builder: (_, _) => const Text('settings')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmConfiguredProvider.overrideWithValue(hasKey),
          if (llm != null) llmClientProvider.overrideWithValue(llm),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('Check the position', () {
    ScanCheckArgs scanned({String? fen, Set<Square> unsure = const {Square.e1}}) => ScanCheckArgs(
      result: ScanResult(setup: BoardSetup.fromFen(fen ?? Chess.initial.fen), unsure: unsure),
    );

    testWidgets('names the squares to check and opens the analysis board', (tester) async {
      await pump(tester, ScanCheckScreen(args: scanned()));
      expect(find.text('Check the position'), findsOneWidget);
      expect(find.text('1 square to check: e1.'), findsOneWidget);
      expect(find.text('Side to move'), findsOneWidget);

      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.textContaining('analysis ')).data!;
      final query = Uri.splitQueryString(text.substring('analysis '.length));
      expect(query['fen'], Chess.initial.fen);
      expect(query['from'], 'scan');
    });

    testWidgets('a second white king disables Analyze and says why', (tester) async {
      await pump(tester, ScanCheckScreen(args: scanned(unsure: const {})));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit position'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('White king'));
      await tester.pump();
      // g1 (the knight's square): column 6 of the bottom row.
      final board = tester.getRect(find.bySemanticsLabel('Board').first);
      final square = board.width / 8;
      await tester.tapAt(Offset(board.left + square * 6.5, board.top + square * 7.5));
      await tester.pumpAndSettle();

      expect(
        find.text('Each side needs exactly one king. White has two, on e1 and g1.'),
        findsOneWidget,
      );
      final analyze = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Analyze'));
      expect(analyze.onPressed, isNull);

      await tester.tap(find.text('Reset to detected'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Analyze')).onPressed,
        isNotNull,
      );
    });

    testWidgets('by hand: starts empty in edit mode', (tester) async {
      await pump(tester, const ScanCheckScreen());
      expect(find.text('Edit position'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Analyze')).onPressed,
        isNull,
      );
    });

    testWidgets('side to move and the turned-round board go into the FEN', (tester) async {
      await pump(tester, ScanCheckScreen(args: scanned(unsure: const {})));
      await tester.tap(find.text('Black'));
      await tester.pump();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analyze'));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.textContaining('analysis ')).data!;
      final query = Uri.splitQueryString(text.substring('analysis '.length));
      // Turned round: the white pieces are now at the top, so no castling.
      expect(query['fen'], 'RNBKQBNR/PPPPPPPP/8/8/8/8/pppppppp/rnbkqbnr b - - 0 1');
      expect(query['side'], 'black');
    });
  });

  group('Scan flow', () {
    late ScanPhoto photo;

    setUpAll(() {
      final image = img.Image(width: 64, height: 48);
      photo = ScanPhoto(bytes: img.encodeJpg(image), width: 64, height: 48);
    });

    testWidgets('without a key: explains, and offers to set up by hand', (tester) async {
      await pump(tester, ScanScreen(photo: photo), hasKey: false);
      expect(find.text('Crop to the board'), findsOneWidget);

      await tester.tap(find.text('Scan board'));
      await tester.pumpAndSettle();
      expect(find.text('Scanning needs your AI Coach key'), findsOneWidget);

      await tester.tap(find.text('Set up the position by hand'));
      await tester.pumpAndSettle();
      expect(find.text('Edit position'), findsOneWidget);
    });

    testWidgets('reads the photo, shows the steps, then the position to check', (tester) async {
      final llm = FakeLlm(
        reply: jsonEncode({
          'board_found': true,
          'image_quality': 'clear',
          'ranks': [
            'rnbqkbnr',
            'pppppppp',
            '........',
            '........',
            '........',
            '........',
            'PPPPPPPP',
            'RNBQKBNR',
          ],
          'white_at_bottom': true,
          'unsure_cells': <Object?>[],
        }),
      );
      await pump(tester, ScanScreen(photo: photo), llm: llm);

      // Cropping runs in an isolate: let it finish for real.
      await tester.runAsync(() async {
        await tester.tap(find.text('Scan board'));
        for (var i = 0; i < 50 && llm.requests.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pump();
      expect(find.text('Reading your board'), findsOneWidget);
      expect(find.text('Board found · 8 × 8 squares'), findsOneWidget);
      expect(find.text('POSITION READY'), findsOneWidget);

      // The moment on "Position ready" runs on a real timer here.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await tester.pumpAndSettle();
      expect(find.text('Check the position'), findsOneWidget);
      expect(find.text('Looks right? Set the details below, then Analyze.'), findsOneWidget);
      expect(llm.requests.single.messages.single.images, hasLength(1));
    });

    testWidgets('offline: set up by hand or try again', (tester) async {
      await pump(
        tester,
        ScanScreen(photo: photo),
        llm: FakeLlm(failure: const LlmOffline()),
      );
      await tester.runAsync(() async {
        await tester.tap(find.text('Scan board'));
        for (var i = 0; i < 50 && find.text('You’re offline').evaluate().isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(find.text('You’re offline'), findsOneWidget);
      expect(find.text('Set up the position by hand'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
