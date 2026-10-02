// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/motion/reduce_motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// Shows the animated intro over the app at launch, then fades it away.
/// The app builds underneath meanwhile, so Home is ready when it lifts.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child});

  final Widget child;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool _finished = false;
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_gone)
          IgnorePointer(
            ignoring: _finished,
            child: AnimatedOpacity(
              opacity: _finished ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              onEnd: () => setState(() => _gone = true),
              child: RooksightIntro(onDone: () => setState(() => _finished = true)),
            ),
          ),
      ],
    );
  }
}

/// The animated intro (design: SplashIntro, design/splash/rooksight_intro.dart),
/// about 1.2 s plus a short hold: the tower appears, the three battlements
/// rise one by one, the AI spark pops in and the wordmark fades up.
///
/// It opens in the phone's light or dark mode, exactly like the native splash
/// before it (which can't know the app's setting), with the logo where the
/// splash drew it, so the hand-off is seamless. If the app's Appearance
/// setting differs, the colours then blend into it, so Home appears in the
/// right theme. With reduced motion it shows the final frame, with a fade.
class RooksightIntro extends ConsumerStatefulWidget {
  const RooksightIntro({super.key, required this.onDone});

  final VoidCallback onDone;

  /// The drawing, then a hold on the finished logo: 1.5 s in all.
  static const drawing = Duration(milliseconds: 1200);
  static const total = Duration(milliseconds: 1500);

  /// Reduced motion: the final frame, briefly.
  static const still = Duration(milliseconds: 400);

  /// The logo's size, as on the native splash (148 dp).
  static const logoSize = 148.0;

  @override
  ConsumerState<RooksightIntro> createState() => _RooksightIntroState();
}

class _RooksightIntroState extends ConsumerState<RooksightIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _started = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduced = shouldReduceMotion(context, ref);
    // With reduced motion the clock only times the hold; the logo is whole.
    _controller.duration = _reduced ? RooksightIntro.still : RooksightIntro.total;
    _controller.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  /// How far the colours have gone from the phone's mode to the app's (0–1):
  /// while the tower draws, or across the still frame with reduced motion.
  double get _toAppTheme =>
      Curves.easeInOut.transform(_reduced ? _controller.value : ((_t - 0.1) / 0.5).clamp(0.0, 1.0));

  /// Progress through the drawing (0–1), the hold excluded.
  double get _t => _reduced
      ? 1
      : (_controller.value *
                RooksightIntro.total.inMilliseconds /
                RooksightIntro.drawing.inMilliseconds)
            .clamp(0.0, 1.0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The native splash follows the phone; the app may be set otherwise.
    final phoneDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final appDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final darkness = lerpDouble(phoneDark ? 1 : 0, appDark ? 1 : 0, _toAppTheme)!;
        Color blend(Color Function(AppColors) token) =>
            Color.lerp(token(AppColors.light), token(AppColors.dark), darkness)!;
        final background = blend((c) => c.bgBase);
        // The wordmark appears after the blend, so it takes the app's colours
        // (with reduced motion it's visible sooner: it switches halfway, as a
        // fresh text, since changing a text's colour frame by frame can trip
        // over fonts still loading).
        final textDark = _reduced ? darkness >= 0.5 : appDark;
        final text = textDark ? AppColors.dark : AppColors.light;
        final word = Curves.easeOutCubic.transform(((_t - 0.75) / 0.25).clamp(0.0, 1.0));
        // One theme throughout for the type; only the colours blend.
        return Theme(
          data: phoneDark ? AppTheme.dark() : AppTheme.light(),
          child: Builder(
            builder: (context) {
              final type = context.type;
              // Status-bar icons flip at the blend's midpoint, so they stay
              // readable on the background throughout.
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: darkness >= 0.5 ? _StatusBar.overDark : _StatusBar.overLight,
                child: ColoredBox(
                  color: background,
                  // The intro sits above the app's screens, outside any
                  // Scaffold: this gives its text proper defaults (no yellow
                  // "missing Material" underline).
                  child: Material(
                    type: MaterialType.transparency,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox.square(
                            dimension: RooksightIntro.logoSize,
                            child: CustomPaint(
                              painter: RookPainter(_t, darkness: darkness, background: background),
                            ),
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: RooksightIntro.logoSize + 110),
                            child: Opacity(
                              opacity: word,
                              child: Transform.translate(
                                offset: Offset(0, 12 * (1 - word)),
                                child: Column(
                                  key: ValueKey(textDark),
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 4,
                                  children: [
                                    Text(
                                      'Rooksight',
                                      style: type.title.copyWith(
                                        fontSize: 30,
                                        letterSpacing: -0.75,
                                        color: text.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      'Your AI Chess Coach',
                                      style: type.body.copyWith(
                                        fontSize: 14,
                                        color: text.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Status-bar styles over the intro's background, with a transparent bar.
abstract final class _StatusBar {
  /// Light icons, for a dark background.
  static final overDark = SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent);

  /// Dark icons, for a light background.
  static final overLight = SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent);
}

/// The rook, drawn [t] of the way through the intro (1 = the finished
/// logo), on a 100 × 100 canvas scaled to the size given.
class RookPainter extends CustomPainter {
  RookPainter(this.t, {required this.darkness, required this.background});

  final double t;

  /// 0 for the light logo, 1 for the dark one; in between while blending.
  final double darkness;

  /// The spark is cut out by painting it in the background colour.
  final Color background;

  /// Progress through the stretch [from]–[to] of the intro.
  double _step(double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final tower = Color.lerp(AppColors.light.focus, AppColors.dark.focus, darkness)!;
    // The logo's own brass in light mode (design/logo/mark_light.svg).
    final best = Color.lerp(const Color(0xFFC98A1B), AppColors.dark.brass, darkness)!;
    canvas.scale(size.width / 100);
    RRect rect(double x, double y, double w, double h, double r) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

    // The tower fades in, rising 6 units (0–25%).
    final body = _step(0, 0.25);
    canvas.save();
    canvas.translate(0, 6 * (1 - body));
    final paint = Paint()..color = tower.withValues(alpha: body);
    canvas
      ..drawRRect(rect(22, 80, 56, 8, 2), paint)
      ..drawRRect(rect(27, 73, 46, 5, 1.5), paint)
      ..drawPath(
        Path()
          ..moveTo(33, 71)
          ..lineTo(67, 71)
          ..lineTo(63.5, 41)
          ..lineTo(36.5, 41)
          ..close(),
        paint,
      )
      ..drawRRect(rect(28, 33, 44, 6, 1.5), paint);
    canvas.restore();

    // The battlements rise one by one from the top of the tower.
    void battlement(double x, double height, Color color, double from, double to) {
      final k = _step(from, to, Curves.easeOutBack);
      if (k <= 0) return;
      canvas.drawRRect(rect(x, 31 - height * k, 11, height * k, 1.2), Paint()..color = color);
    }

    battlement(28, 7, tower, 0.25, 0.375);
    battlement(44.5, 13, tower, 0.35, 0.475);
    battlement(61, 20, best, 0.45, 0.625);

    // The AI spark pops in (0.2 → overshoot → 1) with a quarter turn.
    final spark = _step(0.625, 0.875, Curves.easeOutBack);
    if (spark > 0) {
      canvas
        ..save()
        ..translate(50, 56)
        ..rotate((1 - spark) * -0.785)
        ..scale(0.2 + 0.8 * spark)
        ..drawPath(
          Path()
            ..moveTo(0, -9.5)
            ..lineTo(2.28, -2.28)
            ..lineTo(9.5, 0)
            ..lineTo(2.28, 2.28)
            ..lineTo(0, 9.5)
            ..lineTo(-2.28, 2.28)
            ..lineTo(-9.5, 0)
            ..lineTo(-2.28, -2.28)
            ..close(),
          Paint()..color = background,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(RookPainter old) =>
      old.t != t || old.darkness != darkness || old.background != background;
}
