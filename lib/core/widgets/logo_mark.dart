import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The MoveWise mark, "the analyst's rook" (design/logo): a rook whose
/// battlements rise like a bar chart, the tallest in brass (the best move),
/// with the AI coach's spark cut through the tower.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 34});

  final double size;

  // From mark_dark.svg and mark_light.svg: the light mark uses its own
  // brass (#C98A1B), brighter than the accent.brass token.
  static const _dark = (tower: '#86A8FF', best: '#E3B25C');
  static const _light = (tower: '#2F5BD3', best: '#C98A1B');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _dark : _light;
    return Semantics(
      label: 'MoveWise',
      image: true,
      child: SvgPicture.string(svg(colors.tower, colors.best), width: size, height: size),
    );
  }

  /// The mark on a 100 × 100 canvas. The tower and the spark share one
  /// even-odd path, so the spark is a real hole whatever the background.
  static String svg(String tower, String best) =>
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <rect x="22" y="80" width="56" height="8" rx="2" fill="$tower"/>
  <rect x="27" y="73" width="46" height="5" rx="1.5" fill="$tower"/>
  <path fill-rule="evenodd" fill="$tower" d="M33 71H67L63.5 41H36.5Z M50 46.5L52.28 53.72L59.5 56L52.28 58.28L50 65.5L47.72 58.28L40.5 56L47.72 53.72Z"/>
  <rect x="28" y="33" width="44" height="6" rx="1.5" fill="$tower"/>
  <rect x="28" y="24" width="11" height="7" rx="1.2" fill="$tower"/>
  <rect x="44.5" y="18" width="11" height="13" rx="1.2" fill="$tower"/>
  <rect x="61" y="11" width="11" height="20" rx="1.2" fill="$best"/>
</svg>''';
}
