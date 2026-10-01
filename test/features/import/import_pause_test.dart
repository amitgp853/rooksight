import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/features/import/data/import_pause.dart';
import 'package:rooksight/features/play/domain/game_controller.dart' show nowProvider;

void main() {
  ProviderContainer containerFor(FakeAsync async) {
    final container = ProviderContainer(
      overrides: [nowProvider.overrideWithValue(() => DateTime(2026).add(async.elapsed))],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('a wait says when it ends, and clears when done', () {
    fakeAsync((async) {
      final container = containerFor(async);
      var done = false;
      container.read(importPauseProvider.notifier).wait(const Duration(seconds: 42)).then((_) {
        done = true;
      });
      expect(container.read(importPauseProvider), DateTime(2026).add(const Duration(seconds: 42)));

      async.elapse(const Duration(seconds: 41));
      expect(done, isFalse);
      async.elapse(const Duration(seconds: 1));
      expect(done, isTrue);
      expect(container.read(importPauseProvider), isNull);
    });
  });

  test('"Try now" ends the wait early', () {
    fakeAsync((async) {
      final container = containerFor(async);
      var done = false;
      container.read(importPauseProvider.notifier).wait(const Duration(minutes: 1)).then((_) {
        done = true;
      });
      async.elapse(const Duration(seconds: 5));
      container.read(importPauseProvider.notifier).skip();
      async.flushMicrotasks();
      expect(done, isTrue);
      expect(container.read(importPauseProvider), isNull);
    });
  });
}
