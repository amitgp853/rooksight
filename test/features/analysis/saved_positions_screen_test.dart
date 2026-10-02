// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/storage/saved_position_repository.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/analysis/saved_positions_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late MemorySavedPositionRepository positions;
  setUp(() => positions = MemorySavedPositionRepository());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SavedPositionsScreen()),
        GoRoute(
          path: '/analysis',
          builder: (_, state) => Text('analysis ${(state.extra! as SavedPosition).title}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [savedPositionRepositoryProvider.overrideWithValue(positions)],
        child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<int> save(String title, {List<Object?> moves = const []}) => positions.create((
    title: title,
    fen: Chess.initial.fen,
    moves: moves,
    path: const [],
    source: 'scan',
    orientation: 'white',
  ), DateTime(2026, 9, 30));

  testWidgets('empty: explains how to save one', (tester) async {
    await pump(tester);
    expect(find.text('No saved positions yet'), findsOneWidget);
  });

  testWidgets('lists them and opens one on the analysis board', (tester) async {
    await save(
      'Book diagram',
      moves: const [
        {
          'm': 'e2e4',
          'c': [
            {'m': 'e7e5'},
          ],
        },
      ],
    );
    await pump(tester);

    expect(find.text('Book diagram'), findsOneWidget);
    expect(find.text('Scan · 2 moves explored · 30 Sep'), findsOneWidget);
    await tester.tap(find.text('Book diagram'));
    await tester.pumpAndSettle();
    expect(find.text('analysis Book diagram'), findsOneWidget);
  });

  testWidgets('rename and delete', (tester) async {
    await save('Old name');
    await pump(tester);

    await tester.tap(find.byTooltip('Options for Old name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'New name');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('New name'), findsOneWidget);

    await tester.tap(find.byTooltip('Options for New name'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete position'));
    await tester.pumpAndSettle();
    expect(positions.all, isEmpty);
    expect(find.text('No saved positions yet'), findsOneWidget);
  });
}
