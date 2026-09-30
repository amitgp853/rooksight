import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/storage/settings_store.dart';
import 'package:move_wise/features/scan/domain/scan_usage.dart';

void main() {
  test('counts scans per day, starts again the next day, and stops at the limit', () {
    var now = DateTime(2026, 9, 30, 23, 50);
    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(SettingsStore.inMemory()),
        scanClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    final usage = container.read(scanUsageProvider.notifier);

    for (var i = 0; i < ScanUsage.dailyLimit; i++) {
      expect(usage.reachedLimit, isFalse);
      usage.record();
    }
    expect(container.read(scanUsageProvider), ScanUsage.dailyLimit);
    expect(usage.reachedLimit, isTrue);
    expect(usage.left, 0);

    now = DateTime(2026, 10, 1, 0, 5); // Midnight passed, app still open.
    expect(usage.reachedLimit, isFalse);
    expect(usage.left, ScanUsage.dailyLimit);
    usage.record();
    expect(container.read(scanUsageProvider), 1);
  });

  test('kept across restarts (the settings store)', () {
    final store = SettingsStore.inMemory();
    final now = DateTime(2026, 9, 30);
    ProviderContainer container() => ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(store),
        scanClockProvider.overrideWithValue(() => now),
      ],
    );
    final first = container()..read(scanUsageProvider.notifier).record();
    first.dispose();
    final second = container();
    addTearDown(second.dispose);
    expect(second.read(scanUsageProvider), 1);
  });
}
