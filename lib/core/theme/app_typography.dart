import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The MoveWise type scale (`design/design-spec.md`).
///
/// Fonts are bundled in `assets/google_fonts/`; runtime fetching is disabled
/// in `main.dart`, so these never hit the network.
///
/// Read them with `context.type` (see `app_theme.dart`).
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.display,
    required this.title,
    required this.heading,
    required this.body,
    required this.label,
    required this.overline,
    required this.mono,
  });

  /// Sora 600, 40/44, −2%. Big numbers: accuracy, Elo.
  final TextStyle display;

  /// Sora 600, 24/30. Screen titles.
  final TextStyle title;

  /// Sora 600, 17/24. Card and section headings.
  final TextStyle heading;

  /// Instrument Sans 400, 15/22.
  final TextStyle body;

  /// Instrument Sans 500, 13/18.
  final TextStyle label;

  /// Instrument Sans 600, 11/16, +8%. Pass ALL-CAPS text: Flutter has no
  /// text-transform.
  final TextStyle overline;

  /// JetBrains Mono 500, 15/22, tabular figures. Moves, clocks, evals.
  final TextStyle mono;

  /// Builds the scale in [color] (normally `text.primary`).
  factory AppTypography.withColor(Color color) {
    return AppTypography(
      display: GoogleFonts.sora(
        fontSize: 40,
        height: 44 / 40,
        fontWeight: FontWeight.w600,
        letterSpacing: 40 * -0.02,
        color: color,
      ),
      title: GoogleFonts.sora(
        fontSize: 24,
        height: 30 / 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 24 * -0.01,
        color: color,
      ),
      heading: GoogleFonts.sora(
        fontSize: 17,
        height: 24 / 17,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      body: GoogleFonts.instrumentSans(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w400,
        color: color,
      ),
      label: GoogleFonts.instrumentSans(
        fontSize: 13,
        height: 18 / 13,
        fontWeight: FontWeight.w500,
        color: color,
      ),
      overline: GoogleFonts.instrumentSans(
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 11 * 0.08,
        color: color,
      ),
      mono: GoogleFonts.jetBrainsMono(
        fontSize: 15,
        height: 22 / 15,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color,
      ),
    );
  }

  @override
  AppTypography copyWith({
    TextStyle? display,
    TextStyle? title,
    TextStyle? heading,
    TextStyle? body,
    TextStyle? label,
    TextStyle? overline,
    TextStyle? mono,
  }) {
    return AppTypography(
      display: display ?? this.display,
      title: title ?? this.title,
      heading: heading ?? this.heading,
      body: body ?? this.body,
      label: label ?? this.label,
      overline: overline ?? this.overline,
      mono: mono ?? this.mono,
    );
  }

  @override
  AppTypography lerp(AppTypography? other, double t) {
    if (other == null) return this;
    TextStyle mix(TextStyle a, TextStyle b) => TextStyle.lerp(a, b, t)!;
    return AppTypography(
      display: mix(display, other.display),
      title: mix(title, other.title),
      heading: mix(heading, other.heading),
      body: mix(body, other.body),
      label: mix(label, other.label),
      overline: mix(overline, other.overline),
      mono: mix(mono, other.mono),
    );
  }
}
