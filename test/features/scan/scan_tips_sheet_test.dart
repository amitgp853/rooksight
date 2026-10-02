// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/core/widgets/rooksight_sheet.dart';
import 'package:rooksight/features/scan/widgets/scan_camera_view.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('a short sheet is as tall as its content, not the screen', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showRooksightSheet<void>(
                context,
                reduceMotion: true,
                builder: (_) => const ScanTipsSheet(),
              ),
              child: const Text('Tips'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Tips'));
    await tester.pumpAndSettle();

    // On a very tall screen the tips leave most of it free.
    final sheet = tester.getRect(find.byType(ScanTipsSheet));
    expect(sheet.top, greaterThan(800));
  });
}
