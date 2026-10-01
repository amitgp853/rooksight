import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/analysis/widgets/analysis_panels.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget strip(({int white, int draw, int black}) wdl) => ProviderScope(
    child: MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 340, child: WdlStrip(wdl: wdl)),
        ),
      ),
    ),
  );

  testWidgets('the bar never overflows while the label beside it grows', (tester) async {
    await tester.pumpWidget(strip((white: 60, draw: 40, black: 0)));
    await tester.pumpAndSettle();

    // A full bar, then "Black 0%" becomes "Black 10%": the label widens, so
    // the bar narrows faster than its segments shrink.
    await tester.pumpWidget(strip((white: 55, draw: 35, black: 10)));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpAndSettle();
    expect(find.text('Draw 35% · Black 10%'), findsOneWidget);
  });
}
