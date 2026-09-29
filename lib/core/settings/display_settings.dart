import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/settings_store.dart';
import '../theme/board_themes.dart';

/// A setting kept in [SettingsStore]: starts from the stored value (or
/// [fallback]) and saves every change.
abstract class StoredSetting<T> extends Notifier<T> {
  String get key;
  T get fallback;
  T? decode(String value);
  String encode(T value);

  @override
  T build() {
    final stored = ref.watch(settingsStoreProvider).get(key);
    return (stored == null ? null : decode(stored)) ?? fallback;
  }

  void set(T value) {
    state = value;
    ref.read(settingsStoreProvider).set(key, encode(value));
  }
}

/// Looks up an enum value by name, or null if it is no longer defined.
E? _byName<E extends Enum>(List<E> values, String name) =>
    values.where((v) => v.name == name).firstOrNull;

/// App theme mode. Dark is the design default.
final themeModeProvider = NotifierProvider<ThemeModeSetting, ThemeMode>(ThemeModeSetting.new);

class ThemeModeSetting extends StoredSetting<ThemeMode> {
  @override
  String get key => 'themeMode';
  @override
  ThemeMode get fallback => ThemeMode.dark;
  @override
  ThemeMode? decode(String value) => _byName(ThemeMode.values, value);
  @override
  String encode(ThemeMode value) => value.name;
}

/// The in-app "Reduce motion" toggle. Combine it with the system setting via
/// `shouldReduceMotion` rather than reading it directly.
final reduceMotionSettingProvider = NotifierProvider<BoolSetting, bool>(
  () => BoolSetting('reduceMotion', fallback: false),
);

/// Board colour theme. Slate is the design default.
final boardThemeProvider = NotifierProvider<BoardThemeSetting, BoardTheme>(BoardThemeSetting.new);

class BoardThemeSetting extends StoredSetting<BoardTheme> {
  @override
  String get key => 'boardTheme';
  @override
  BoardTheme get fallback => BoardTheme.slate;
  @override
  BoardTheme? decode(String value) => _byName(BoardTheme.values, value);
  @override
  String encode(BoardTheme value) => value.name;
}

/// Board sounds on or off.
final soundEnabledProvider = NotifierProvider<BoolSetting, bool>(
  () => BoolSetting('sound', fallback: true),
);

/// Haptic feedback on or off.
final hapticsEnabledProvider = NotifierProvider<BoolSetting, bool>(
  () => BoolSetting('haptics', fallback: true),
);

/// Shows the AI Coach section (the Gemini key) in Settings.
final developerModeProvider = NotifierProvider<BoolSetting, bool>(
  () => BoolSetting('developerMode', fallback: false),
);

class BoolSetting extends StoredSetting<bool> {
  BoolSetting(this.key, {required this.fallback});

  @override
  final String key;
  @override
  final bool fallback;
  @override
  bool? decode(String value) => bool.tryParse(value);
  @override
  String encode(bool value) => '$value';
}

/// How deeply Stockfish analyses each position in a game review.
enum AnalysisDepth {
  fast(12, 'Fast'),
  normal(16, 'Normal'),
  deep(20, 'Deep');

  const AnalysisDepth(this.plies, this.label);

  final int plies;
  final String label;
}

final analysisDepthProvider = NotifierProvider<AnalysisDepthSetting, AnalysisDepth>(
  AnalysisDepthSetting.new,
);

class AnalysisDepthSetting extends StoredSetting<AnalysisDepth> {
  @override
  String get key => 'analysisDepth';
  @override
  AnalysisDepth get fallback => AnalysisDepth.normal;
  @override
  AnalysisDepth? decode(String value) => _byName(AnalysisDepth.values, value);
  @override
  String encode(AnalysisDepth value) => value.name;
}
