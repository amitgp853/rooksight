/// Keys and settings passed in at build time, never stored in the repo:
///
///     flutter run --dart-define-from-file=.env
///
/// `.env` is git-ignored; `.env.example` shows its format.
abstract final class ApiKeys {
  static const gemini = String.fromEnvironment('GEMINI_API_KEY');

  static bool get hasGemini => gemini.isNotEmpty;

  /// Flash models are free on the Gemini API free tier. Override with
  /// `GEMINI_MODEL` to try another (e.g. `gemini-3.5-flash-lite` if the free
  /// limits are tight).
  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.8-flash',
  );

  /// Used when [geminiModel] stays overloaded ("high demand") after retries.
  static const geminiFallbackModel = String.fromEnvironment(
    'GEMINI_FALLBACK_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );
}
