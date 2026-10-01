import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/analytics/analytics.dart';
import 'package:move_wise/core/llm/llm_client.dart';

void main() {
  test('without a TelemetryDeck app ID nothing is sent', () {
    // Tests run without --dart-define, like a build without the ID.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(analyticsProvider), isA<NoAnalytics>());
  });

  test('AI outcomes are short categories, never the error text', () {
    expect(outcomeOf(null), 'ok');
    expect(outcomeOf(const LlmMissingKey()), 'missing_key');
    expect(outcomeOf(const LlmInvalidKey()), 'invalid_key');
    expect(outcomeOf(const LlmRateLimited()), 'rate_limited');
    expect(outcomeOf(const LlmOffline()), 'offline');
    expect(outcomeOf(const LlmUnavailable('HTTP 500: details')), 'unavailable');
    expect(outcomeOf(StateError('a user’s question')), 'error');
  });
}
