import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/board/board_style.dart';
import 'package:move_wise/core/llm/gemini_client.dart';
import 'package:move_wise/core/storage/analysis_repository.dart';
import 'package:move_wise/core/storage/game_repository.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/engine/engine_provider.dart';
import 'package:move_wise/features/report_card/data/image_sharer.dart';
import 'package:move_wise/features/report_card/report_card_screen.dart';

import '../../support/fake_analysis_repository.dart';
import '../../support/fake_engine.dart';
import '../../support/fake_game_repository.dart';
import '../../support/fake_llm.dart';
import '../coach/coach_fixtures.dart';

/// Records what would have been shared.
class FakeSharer implements ImageSharer {
  final shared = <(Uint8List, String)>[];

  @override
  Future<void> sharePng(Uint8List png, {required String fileName, Rect? origin}) async =>
      shared.add((png, fileName));
}

/// Width and height from a PNG's header.
(int, int) pngSize(Uint8List png) {
  final data = ByteData.sublistView(png);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late FakeGameRepository games;
  late FakeAnalysisRepository analyses;
  late FakeEngine engine;
  late FakeSharer sharer;
  late FakeLlm llm;
  late int id;

  setUp(() async {
    games = FakeGameRepository();
    analyses = FakeAnalysisRepository();
    engine = FakeEngine();
    sharer = FakeSharer();
    llm = FakeLlm(
      reply: jsonEncode({
        'summary': 's',
        'focus': <String>[],
        'verdict': 'A short, sharp lesson in king safety.',
        'moments': <Object>[],
      }),
    );
    id = await games.save(foolsMate);
  });

  Future<void> pumpReport(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(precachePieces);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          gameRepositoryProvider.overrideWithValue(games),
          analysisRepositoryProvider.overrideWithValue(analyses),
          chessEngineProvider.overrideWithValue(engine),
          imageSharerProvider.overrideWithValue(sharer),
          llmClientProvider.overrideWithValue(llm),
          llmConfiguredProvider.overrideWithValue(true),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: ReportCardScreen(gameId: '$id'),
        ),
      ),
    );
    settle ? await tester.pumpAndSettle() : await tester.pump();
  }

  testWidgets('a reviewed game: the card, with the worst blunder', (tester) async {
    analyses.analyses[id] = foolsMateAnalysis;
    await pumpReport(tester);

    expect(find.text('GAME REPORT'), findsOneWidget);
    expect(find.text('2. g4??'), findsOneWidget);
    expect(find.text('Game summary'), findsOneWidget);
    expect(find.textContaining('One blunder on move 2 turned the game'), findsOneWidget);
    expect(find.text('1080 × 1350 · 4:5 portrait image'), findsOneWidget);
    expect(engine.searches, isEmpty, reason: 'already reviewed');
  });

  testWidgets('Share hands a 1080 × 1350 PNG to the share sheet', (tester) async {
    analyses.analyses[id] = foolsMateAnalysis;
    await pumpReport(tester);

    await tester.runAsync(() async {
      await tester.tap(find.text('Share image'));
      // The capture runs outside the fake clock.
      for (var i = 0; i < 50 && sharer.shared.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    await tester.pumpAndSettle();

    final (png, name) = sharer.shared.single;
    expect(name, 'movewise-report-$id.png');
    expect(pngSize(png), (1080, 1350));
  });

  testWidgets('Copy PGN puts the game on the clipboard', (tester) async {
    analyses.analyses[id] = foolsMateAnalysis;
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (
      call,
    ) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpReport(tester);

    await tester.tap(find.text('Copy PGN'));
    await tester.pumpAndSettle();
    expect(copied, foolsMate.pgn);
    expect(find.text('PGN copied'), findsOneWidget);
  });

  testWidgets('an unreviewed game is analysed first, without AI', (tester) async {
    engine.delay = const Duration(milliseconds: 50);
    await pumpReport(tester, settle: false);
    await tester.pump(const Duration(milliseconds: 120));
    expect(find.textContaining('Analysing your game'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('GAME REPORT'), findsOneWidget);
    expect(analyses.analyses[id]!.complete, isTrue);
    expect(llm.requests, isEmpty);
  });

  testWidgets('Get AI verdict: one request, and the card uses it', (tester) async {
    analyses.analyses[id] = foolsMateAnalysis;
    await pumpReport(tester);

    await tester.tap(find.text('Get AI verdict'));
    await tester.pumpAndSettle();
    expect(llm.requests, hasLength(1));
    expect(find.text('“A short, sharp lesson in king safety.”'), findsOneWidget);
    expect(find.text('AI Coach verdict'), findsOneWidget);
    expect(find.text('Get AI verdict'), findsNothing);
  });

  testWidgets('a missing game says so', (tester) async {
    id = 99;
    await pumpReport(tester);
    expect(find.text('This game couldn’t be found.'), findsOneWidget);
  });
}
