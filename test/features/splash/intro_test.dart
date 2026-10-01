import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rooksight/core/storage/settings_store.dart';
import 'package:rooksight/core/theme/app_colors.dart';
import 'package:rooksight/core/theme/app_theme.dart';
import 'package:rooksight/features/splash/intro.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> pumpGate(
    WidgetTester tester, {
    bool reduceMotion = false,
    Brightness platform = Brightness.dark,
    ThemeMode app = ThemeMode.dark,
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
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: app,
          home: const IntroGate(child: Text('home')),
        ),
      ),
    );
  }

  testWidgets('plays for 1.5 s at most, then gives way to the app', (tester) async {
    await pumpGate(tester);
    expect(find.byType(RooksightIntro), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Your AI Chess Coach'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.byType(RooksightIntro), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('with reduced motion, the finished logo only briefly', (tester) async {
    await pumpGate(tester, reduceMotion: true);
    await tester.pump();
    final painter = tester
        .widgetList<CustomPaint>(
          find.descendant(of: find.byType(RooksightIntro), matching: find.byType(CustomPaint)),
        )
        .map((paint) => paint.painter)
        .whereType<RookPainter>()
        .single;
    expect(painter.t, 1, reason: 'no drawing in: the final frame');

    await tester.pump(RooksightIntro.still);
    await tester.pumpAndSettle();
    expect(find.byType(RooksightIntro), findsNothing);
  });

  Color background(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find.descendant(of: find.byType(RooksightIntro), matching: find.byType(ColoredBox)).first,
      )
      .color;

  testWidgets('phone light, app dark: opens light, then blends into dark', (tester) async {
    await pumpGate(tester, platform: Brightness.light, app: ThemeMode.dark);
    expect(background(tester), AppColors.light.bgBase, reason: 'matches the native splash');

    await tester.pump(const Duration(milliseconds: 400));
    expect(background(tester), isNot(AppColors.light.bgBase), reason: 'on its way');
    expect(background(tester), isNot(AppColors.dark.bgBase));

    await tester.pump(const Duration(milliseconds: 500));
    expect(background(tester), AppColors.dark.bgBase, reason: 'Home is dark too');
    await tester.pumpAndSettle();
  });

  testWidgets('its text has no "missing Material" underline', (tester) async {
    await pumpGate(tester);
    await tester.pump(const Duration(milliseconds: 1300));
    for (final text in ['Rooksight', 'Your AI Chess Coach']) {
      final style = tester.renderObject<RenderParagraph>(find.text(text)).text.style;
      expect(style?.decoration ?? TextDecoration.none, TextDecoration.none, reason: text);
    }
    await tester.pumpAndSettle();
  });

  testWidgets('status-bar icons flip with the background, staying readable', (tester) async {
    Brightness? icons() => tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: find.byType(RooksightIntro),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        )
        .value
        .statusBarIconBrightness;

    await pumpGate(tester, platform: Brightness.light, app: ThemeMode.dark);
    expect(icons(), Brightness.dark, reason: 'dark icons on the light first frame');

    await tester.pump(const Duration(milliseconds: 900));
    expect(icons(), Brightness.light, reason: 'light icons once it has blended to dark');
    await tester.pumpAndSettle();
  });

  testWidgets('phone dark, app light: opens dark, ends light', (tester) async {
    await pumpGate(tester, platform: Brightness.dark, app: ThemeMode.light);
    expect(background(tester), AppColors.dark.bgBase);
    await tester.pump(const Duration(milliseconds: 900));
    expect(background(tester), AppColors.light.bgBase);
    await tester.pumpAndSettle();
  });

  testWidgets('app following the phone: no change at all', (tester) async {
    await pumpGate(tester, platform: Brightness.light, app: ThemeMode.system);
    for (var i = 0; i < 6; i++) {
      expect(background(tester), AppColors.light.bgBase);
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle();
  });

  testWidgets('reduced motion: a fade from the phone\'s mode to the app\'s', (tester) async {
    await pumpGate(tester, reduceMotion: true, platform: Brightness.light, app: ThemeMode.dark);
    await tester.pump();
    expect(background(tester), AppColors.light.bgBase);
    await tester.pump(RooksightIntro.still - const Duration(milliseconds: 1));
    expect(background(tester), isNot(AppColors.light.bgBase));
    await tester.pumpAndSettle();
  });

  testWidgets('its background follows the phone, like the native splash', (tester) async {
    await pumpGate(tester, platform: Brightness.light);
    final box = tester.widget<ColoredBox>(
      find.descendant(of: find.byType(RooksightIntro), matching: find.byType(ColoredBox)).first,
    );
    expect(box.color, AppColors.light.bgBase);
    await tester.pumpAndSettle();
  });
}
