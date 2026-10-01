// Rooksight animated intro — shown right after the native splash (same background colour,
// same logo position, so the hand-off is seamless). ~1.2 s, then calls [onDone].
// Honors reduced motion: if MediaQuery.disableAnimations is true it shows the final frame.
import 'package:flutter/material.dart';

class RooksightIntro extends StatefulWidget {
  const RooksightIntro({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<RooksightIntro> createState() => _RooksightIntroState();
}

class _RooksightIntroState extends State<RooksightIntro> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.status == AnimationStatus.dismissed) {
      if (MediaQuery.of(context).disableAnimations) {
        _c.value = 1;
        Future.delayed(const Duration(milliseconds: 400), widget.onDone);
      } else {
        _c.forward().whenComplete(() => Future.delayed(const Duration(milliseconds: 300), widget.onDone));
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF0E1217) : const Color(0xFFF1F3F6);
    final word = CurvedAnimation(parent: _c, curve: const Interval(0.75, 1.0, curve: Curves.easeOutCubic));
    return ColoredBox(
      color: bg,
      // Logo stays exactly centred (same spot as the native splash); the wordmark sits below it.
      child: Stack(children: [
        Center(
          child: SizedBox.square(
            dimension: 148,
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => CustomPaint(painter: _RookPainter(_c.value, dark: dark, bg: bg)),
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 148 + 110),
            child: FadeTransition(
              opacity: word,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(word),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('Rooksight',
                      style: TextStyle(
                          fontFamily: 'Sora', fontWeight: FontWeight.w600, fontSize: 30, letterSpacing: -0.75,
                          color: dark ? const Color(0xFFE9EDF2) : const Color(0xFF121820))),
                  const SizedBox(height: 4),
                  Text('Your AI chess coach',
                      style: TextStyle(fontSize: 14, color: dark ? const Color(0xFFA3AFBD) : const Color(0xFF4A5563))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RookPainter extends CustomPainter {
  _RookPainter(this.t, {required this.dark, required this.bg});
  final double t;
  final bool dark;
  final Color bg;

  double _iv(double a, double b, [Curve c = Curves.easeOutCubic]) => c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final pri = dark ? const Color(0xFF86A8FF) : const Color(0xFF2F5BD3);
    final acc = dark ? const Color(0xFFE3B25C) : const Color(0xFFC98A1B);
    canvas.scale(size.width / 100);

    // Tower (fade + rise 0–25%)
    final body = _iv(0, 0.25);
    canvas.save();
    canvas.translate(0, 6 * (1 - body));
    final p = Paint()..color = pri.withValues(alpha: body);
    RRect r(double x, double y, double w, double h, double rad) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rad));
    canvas.drawRRect(r(22, 80, 56, 8, 2), p);
    canvas.drawRRect(r(27, 73, 46, 5, 1.5), p);
    canvas.drawPath(Path()..moveTo(33, 71)..lineTo(67, 71)..lineTo(63.5, 41)..lineTo(36.5, 41)..close(), p);
    canvas.drawRRect(r(28, 33, 44, 6, 1.5), p);
    canvas.restore();

    // Battlements rise one by one (bottom-anchored scaleY)
    void bar(double x, double h, Color c, double a, double b) {
      final k = _iv(a, b, Curves.easeOutBack);
      if (k <= 0) return;
      final hh = h * k;
      canvas.drawRRect(r(x, 31 - hh, 11, hh, 1.2), Paint()..color = c);
    }
    bar(28, 7, pri, 0.25, 0.375);
    bar(44.5, 13, pri, 0.35, 0.475);
    bar(61, 20, acc, 0.45, 0.625);

    // AI spark cut-out: scale 0.2 → 1.25 → 1 with a quarter turn
    final s = _iv(0.625, 0.875, Curves.easeOutBack);
    if (s > 0) {
      canvas.save();
      canvas.translate(50, 56);
      canvas.rotate((1 - s) * -0.785);
      canvas.scale(0.2 + 0.8 * s);
      final star = Path()
        ..moveTo(0, -9.5)..lineTo(2.28, -2.28)..lineTo(9.5, 0)..lineTo(2.28, 2.28)
        ..lineTo(0, 9.5)..lineTo(-2.28, 2.28)..lineTo(-9.5, 0)..lineTo(-2.28, -2.28)..close();
      canvas.drawPath(star, Paint()..color = bg);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RookPainter old) => old.t != t || old.dark != dark;
}
