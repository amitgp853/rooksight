import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/settings_store.dart';

/// Today's date, for counting scans per day. Override in tests.
final scanClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Board scans sent to Gemini today, kept on the phone. A soft daily limit
/// keeps endless snapping from using up the player's free requests; setting
/// a position up by hand is never limited.
class ScanUsage extends Notifier<int> {
  /// Scans a day. Near it, the player is told how many are left.
  static const dailyLimit = 20;
  static const warnFrom = 15;

  static const _dayKey = 'scan.day';
  static const _countKey = 'scan.count';

  @override
  int build() {
    final store = ref.watch(settingsStoreProvider);
    if (store.get(_dayKey) != _today()) return 0;
    return int.tryParse(store.get(_countKey) ?? '') ?? 0;
  }

  String _today() {
    final now = ref.read(scanClockProvider)();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// No scans left today.
  bool get reachedLimit => _current >= dailyLimit;

  int get left => (dailyLimit - _current).clamp(0, dailyLimit);

  /// Today's count, starting again on a new day (even with the app open).
  int get _current {
    final store = ref.read(settingsStoreProvider);
    return store.get(_dayKey) == _today() ? state : 0;
  }

  /// Counts one scan sent to Gemini.
  void record() {
    final next = _current + 1;
    ref.read(settingsStoreProvider)
      ..set(_dayKey, _today())
      ..set(_countKey, '$next');
    state = next;
  }
}

final scanUsageProvider = NotifierProvider<ScanUsage, int>(ScanUsage.new);
