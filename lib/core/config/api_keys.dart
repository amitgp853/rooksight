// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

/// Keys and settings passed in at build time, never stored in the repo:
///
///     flutter run --dart-define-from-file=.env
///
/// `.env` is git-ignored; `.env.example` shows its format.
abstract final class ApiKeys {
  /// A development key. Always empty in release builds: anything compiled
  /// into the app can be pulled out of it, so a shipped key would be anyone's.
  /// Players add their own key in Settings.
  static const gemini = kReleaseMode ? '' : String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGemini => gemini.isNotEmpty;

  /// Flash models are free on the Gemini API free tier. `config/remote.json`
  /// can switch every installed app to another; `GEMINI_MODEL` overrides both
  /// on a development build (e.g. `gemini-3.5-flash-lite` if the free limits
  /// are tight).
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  /// Whether `GEMINI_MODEL` was given, so it wins over the remote config.
  static const geminiModelOverridden = bool.hasEnvironment('GEMINI_MODEL');

  /// Used when [geminiModel] stays overloaded ("high demand") after retries.
  static const geminiFallbackModel = String.fromEnvironment(
    'GEMINI_FALLBACK_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );

  /// How much [geminiModel] thinks before answering (`minimal`, `low`,
  /// `medium` or `high`; empty for the model's default). Thinking is billed
  /// as output, and the facts it works from are already Stockfish's, so `low`
  /// is enough. Only the primary model gets it: Flash-Lite doesn't think by
  /// default, and asking it for `low` would add thinking, not cut it.
  static const geminiThinkingLevel = String.fromEnvironment(
    'GEMINI_THINKING_LEVEL',
    defaultValue: 'low',
  );

  /// TelemetryDeck, for anonymous usage counts (see `core/analytics`). Both
  /// come from the TelemetryDeck dashboard. Without them nothing is sent.
  static const telemetryDeckAppId = String.fromEnvironment('TELEMETRYDECK_APP_ID');
  static const telemetryDeckNamespace = String.fromEnvironment('TELEMETRYDECK_NAMESPACE');

  static bool get hasTelemetryDeck =>
      telemetryDeckAppId.isNotEmpty && telemetryDeckNamespace.isNotEmpty;
}
