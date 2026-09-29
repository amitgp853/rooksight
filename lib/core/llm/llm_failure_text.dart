import 'llm_client.dart';

/// What to tell the player when an AI request fails.
String llmFailureText(Object? failure) => switch (failure) {
  LlmMissingKey() => 'AI features aren’t set up on this device yet.',
  LlmInvalidKey() => 'The AI key was rejected, so AI features aren’t available right now.',
  LlmRateLimited() => 'The free AI limit is used up for now. Try again in a minute or two.',
  LlmOffline() => 'Couldn’t reach the AI. Check your connection.',
  _ => 'The AI didn’t give a usable answer.',
};
