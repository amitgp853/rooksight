import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/llm/gemini_client.dart';
import 'package:rooksight/core/llm/gemini_key.dart';

void main() {
  ProviderContainer containerWith(MemoryGeminiKeyStorage storage) {
    final container = ProviderContainer(
      overrides: [
        geminiKeyStorageProvider.overrideWithValue(storage),
        savedGeminiKeyAtStartProvider.overrideWithValue(storage.key),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the key saved on the phone is the one used', () {
    final container = containerWith(MemoryGeminiKeyStorage('AIzaSaved'));
    expect(container.read(geminiKeyProvider), 'AIzaSaved');
    expect(container.read(llmConfiguredProvider), isTrue);
  });

  test('no key: the AI features are off', () {
    // Tests run without --dart-define, so there's no build-time key either.
    final container = containerWith(MemoryGeminiKeyStorage());
    expect(container.read(geminiKeyProvider), isEmpty);
    expect(container.read(llmConfiguredProvider), isFalse);
  });

  test('saving trims the key, stores it, and builds a new client', () async {
    final storage = MemoryGeminiKeyStorage();
    final container = containerWith(storage);
    final before = container.read(llmClientProvider);

    await container.read(savedGeminiKeyProvider.notifier).save('  AIzaNew \n');
    expect(storage.key, 'AIzaNew');
    expect(container.read(geminiKeyProvider), 'AIzaNew');
    expect(container.read(llmClientProvider), isNot(same(before)));
  });

  test('removing forgets it; saving blank text removes too', () async {
    final storage = MemoryGeminiKeyStorage('AIzaSaved');
    final container = containerWith(storage);

    await container.read(savedGeminiKeyProvider.notifier).remove();
    expect((storage.key, container.read(llmConfiguredProvider)), (null, false));

    await container.read(savedGeminiKeyProvider.notifier).save('AIzaAgain');
    await container.read(savedGeminiKeyProvider.notifier).save('   ');
    expect(storage.key, isNull);
  });
}
