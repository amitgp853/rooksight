import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:rooksight/core/llm/gemini_client.dart';
import 'package:rooksight/core/llm/llm_client.dart';
import 'package:rooksight/core/routing/app_router.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/scan/domain/board_reader.dart';
import 'package:rooksight/features/scan/domain/board_setup.dart';
import 'package:rooksight/features/scan/domain/photo_check.dart';
import 'package:rooksight/features/scan/domain/scan_usage.dart';
import 'package:rooksight/features/scan/domain/scan_photo.dart';
import 'package:rooksight/features/scan/scan_check_screen.dart';
import 'package:rooksight/features/scan/scan_screen.dart';
import 'package:rooksight/features/scan/widgets/setup_board.dart';

import '../../support/fake_llm.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// What the phone's own photo check says; a clear board unless a test
  /// sets otherwise.
  var check = const PhotoCheck(brightness: 150, contrast: 60, sharpness: 400, boardScore: 0.8);
  late SettingsStore store;
  setUp(() {
    check = const PhotoCheck(brightness: 150, contrast: 60, sharpness: 400, boardScore: 0.8);
    store = SettingsStore.inMemory();
  });

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
          photoCheckerProvider.overrideWithValue((_) async => check),
          settingsStoreProvider.overrideWithValue(store),
        ],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The centre of the board square in column [col], row [row] (from the
  /// top, White at the bottom).
  Offset squareAt(WidgetTester tester, int col, int row) {
    final board = tester.getRect(find.bySemanticsLabel('Board').first);
    final square = board.width / 8;
    return Offset(board.left + square * (col + 0.5), board.top + square * (row + 0.5));
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

      // g1 (the knight's square): column 6 of the bottom row. Square first,
      // then the piece.
      await tester.tapAt(squareAt(tester, 6, 7));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('White king'));
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

    testWidgets('editing: tapping the board only selects; the palette sets the piece', (
      tester,
    ) async {
      await pump(tester, const ScanCheckScreen()); // Empty board, editing.
      // Nothing selected yet: the palette is off.
      await tester.tap(find.bySemanticsLabel('White queen'));
      await tester.pumpAndSettle();
      expect(find.text('Tap a square first, then choose its piece.'), findsOneWidget);

      // d1: select it, then choose the queen.
      await tester.tapAt(squareAt(tester, 3, 7));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose the piece for d1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('White queen'));
      await tester.pumpAndSettle();

      // e1: selecting another square puts nothing on it…
      await tester.tapAt(squareAt(tester, 4, 7));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose the piece for e1'), findsOneWidget);
      // …and choosing a piece now changes e1 only, not d1.
      await tester.tap(find.bySemanticsLabel('White king'));
      await tester.pumpAndSettle();
      // Changing your mind on the same square replaces it.
      await tester.tap(find.bySemanticsLabel('White rook'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('White king'));
      await tester.pumpAndSettle();

      // The board as placed: queen d1, king e1, nothing else.
      final fen = tester.widget<SetupBoard>(find.byType(SetupBoard)).board.fen;
      expect(fen, '8/8/8/8/8/8/8/3QK3');

      // The eraser empties the selected square.
      await tester.tap(find.bySemanticsLabel('Eraser: remove a piece'));
      await tester.pumpAndSettle();
      expect(tester.widget<SetupBoard>(find.byType(SetupBoard)).board.fen, '8/8/8/8/8/8/8/3Q4');
    });

    testWidgets('editing: the photo can stand in for the board, and squares pick from it', (
      tester,
    ) async {
      final photo = img.encodeJpg(img.Image(width: 64, height: 64));
      await pump(
        tester,
        ScanCheckScreen(
          args: ScanCheckArgs(
            result: ScanResult(setup: BoardSetup.fromFen(Chess.initial.fen), unsure: const {}),
            photo: photo,
          ),
        ),
      );
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Tap the photo to compare.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Compare with your photo'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Your photo, in place of the board'), findsOneWidget);
      expect(find.byType(SetupBoard), findsNothing);
      expect(find.textContaining('Your photo, lined up with the board'), findsOneWidget);

      // g1 on the photo (bottom row, column 6), then its piece.
      final rect = tester.getRect(find.bySemanticsLabel('Your photo, in place of the board'));
      final cell = rect.width / 8;
      await tester.tapAt(Offset(rect.left + cell * 6.5, rect.top + cell * 7.5));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose the piece for g1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('White king'));
      await tester.pumpAndSettle();
      expect(find.textContaining('White has two, on e1 and g1'), findsOneWidget);

      // Back to the board, with the change on it.
      await tester.tap(find.bySemanticsLabel('Show the board'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SetupBoard>(find.byType(SetupBoard)).board.fen,
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBKR',
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
          'rows': [
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

    /// Taps Scan board and lets the crop (an isolate) and the reading finish.
    Future<void> scanBoard(WidgetTester tester, {required bool Function() until}) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Scan board'));
        for (var i = 0; i < 100 && !until(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
    }

    String noBoardReply() => jsonEncode({
      'board_found': false,
      'image_quality': 'clear',
      'rows': <String>[],
      'white_at_bottom': true,
      'unsure_cells': <Object?>[],
    });

    testWidgets('a dark or blurry photo is caught on the phone: no request', (tester) async {
      check = const PhotoCheck(brightness: 12, contrast: 8, sharpness: 400, boardScore: 0.8);
      final llm = FakeLlm(reply: noBoardReply());
      await pump(tester, ScanScreen(photo: photo), llm: llm);
      await scanBoard(
        tester,
        until: () => find.text('Too dark or too blurry').evaluate().isNotEmpty,
      );

      expect(find.text('Too dark or too blurry'), findsOneWidget);
      expect(find.textContaining('no AI request was used'), findsOneWidget);
      expect(llm.requests, isEmpty);

      // The check can be wrong: Scan anyway spends one request.
      await tester.runAsync(() async {
        await tester.tap(find.text('Scan anyway'));
        for (var i = 0; i < 50 && llm.requests.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pumpAndSettle();
      expect(llm.requests, hasLength(1));
      expect(find.text('We couldn’t find a board'), findsOneWidget);
    });

    testWidgets('not a board: asks before spending a request', (tester) async {
      check = const PhotoCheck(brightness: 150, contrast: 60, sharpness: 400, boardScore: 0.1);
      final llm = FakeLlm(reply: noBoardReply());
      await pump(tester, ScanScreen(photo: photo), llm: llm);
      await scanBoard(
        tester,
        until: () => find.text('This doesn’t look like a chess board').evaluate().isNotEmpty,
      );
      expect(find.text('This doesn’t look like a chess board'), findsOneWidget);

      await tester.tap(find.text('Adjust crop'));
      await tester.pumpAndSettle();
      expect(find.text('Crop to the board'), findsOneWidget);
      expect(llm.requests, isEmpty);
    });

    testWidgets('the same crop scanned again reuses the answer', (tester) async {
      final llm = FakeLlm(reply: noBoardReply());
      await pump(tester, ScanScreen(photo: photo), llm: llm);
      await scanBoard(
        tester,
        until: () => find.text('We couldn’t find a board').evaluate().isNotEmpty,
      );
      expect(llm.requests, hasLength(1));

      // Back to the crop, same corners, Scan board again.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Crop to the board'), findsOneWidget);
      await scanBoard(
        tester,
        until: () => find.text('We couldn’t find a board').evaluate().isNotEmpty,
      );
      expect(find.text('We couldn’t find a board'), findsOneWidget);
      expect(llm.requests, hasLength(1), reason: 'no second request');
    });

    testWidgets('after 3 unreadable photos in a row, the camera opens with the tips', (
      tester,
    ) async {
      check = const PhotoCheck(brightness: 12, contrast: 8, sharpness: 400, boardScore: 0.8);
      await pump(
        tester,
        ScanScreen(photo: photo),
        llm: FakeLlm(reply: noBoardReply()),
      );
      for (var i = 0; i < 3; i++) {
        if (i > 0) {
          await tester.binding.handlePopRoute(); // Back to the crop.
          await tester.pumpAndSettle();
        }
        await scanBoard(
          tester,
          until: () => find.text('Too dark or too blurry').evaluate().isNotEmpty,
        );
      }
      await tester.tap(find.text('Try again'));
      // The camera (none in tests) keeps a spinner going: pump, don't settle.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Got it'), findsOneWidget, reason: 'the tips sheet');
    });

    testWidgets('the daily limit: then only setting up by hand', (tester) async {
      final now = DateTime.now();
      store
        ..set('scan.day', '${now.year}-${now.month}-${now.day}')
        ..set('scan.count', '${ScanUsage.dailyLimit}');
      final llm = FakeLlm(reply: noBoardReply());
      await pump(tester, ScanScreen(photo: photo), llm: llm);
      await scanBoard(
        tester,
        until: () => find.textContaining('scans today').evaluate().isNotEmpty,
      );
      expect(find.text('That’s ${ScanUsage.dailyLimit} scans today'), findsOneWidget);
      expect(find.text('Set up the position by hand'), findsOneWidget);
      expect(llm.requests, isEmpty);
    });

    testWidgets('near the limit, says how many scans are left', (tester) async {
      final now = DateTime.now();
      store
        ..set('scan.day', '${now.year}-${now.month}-${now.day}')
        ..set('scan.count', '${ScanUsage.dailyLimit - 3}');
      await pump(
        tester,
        ScanScreen(photo: photo),
        llm: FakeLlm(reply: noBoardReply()),
      );
      await scanBoard(
        tester,
        until: () => find.text('We couldn’t find a board').evaluate().isNotEmpty,
      );
      expect(find.text('2 scans left today.'), findsOneWidget);
      expect(store.get('scan.count'), '${ScanUsage.dailyLimit - 2}');
    });
  });
}
