import 'llm_client.dart';

/// What to tell the player when an AI request fails.
String llmFailureText(Object? failure) => switch (failure) {
  LlmMissingKey() =>
    'The AI coach isn’t turned on yet. Turn it on for free in Settings › AI Coach.',
  LlmInvalidKey() => 'The AI key was rejected, so AI features aren’t available right now.',
  LlmRateLimited() => 'The AI limit is used up for now. Try again in a minute or two.',
  LlmOffline() => 'Couldn’t reach the AI. Check your connection.',
  _ => 'The AI didn’t give a usable answer.',
};
