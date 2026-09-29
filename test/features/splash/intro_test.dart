import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/core/theme/app_colors.dart';
import 'package:move_wise/core/theme/app_theme.dart';
import 'package:move_wise/features/splash/intro.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpGate(
    WidgetTester tester, {
    bool reduceMotion = false,
    Brightness platform = Brightness.dark,
  }) async {
    tester.platformDispatcher.platformBrightnessTestValue = platform;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(
            SettingsStore.inMemory({if (reduceMotion) 'reduceMotion': 'true'}),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const IntroGate(child: Text('home')),
        ),
      ),
    );
  }

  testWidgets('plays for 1.5 s at most, then gives way to the app', (tester) async {
    await pumpGate(tester);
    expect(find.byType(MoveWiseIntro), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Your AI chess coach'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(MoveWiseIntro), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('with reduced motion, the finished logo only briefly', (tester) async {
    await pumpGate(tester, reduceMotion: true);
    await tester.pump();
    final painter =
        tester
                .widget<CustomPaint>(
                  find.descendant(
                    of: find.byType(MoveWiseIntro),
                    matching: find.byType(CustomPaint),
                  ),
                )
                .painter!
            as RookPainter;
    expect(painter.t, 1, reason: 'no drawing in: the final frame');

    await tester.pump(MoveWiseIntro.still);
    await tester.pumpAndSettle();
    expect(find.byType(MoveWiseIntro), findsNothing);
  });

  testWidgets('its background follows the phone, like the native splash', (tester) async {
    await pumpGate(tester, platform: Brightness.light);
    final box = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(MoveWiseIntro), matching: find.byType(ColoredBox)).first,
    );
    expect(box.color, AppColors.light.bgBase);
    await tester.pumpAndSettle();
  });
}
