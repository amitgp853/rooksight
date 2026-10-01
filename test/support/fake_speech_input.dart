import 'package:flutter/foundation.dart';
import 'package:rooksight/core/speech/speech_input.dart';

/// Speech recognition for tests: [start] answers with [result]; while
/// listening, [hear] sends words and [finish] ends it, as a pause would or
/// with a [SpeechProblem].
class FakeSpeechInput implements SpeechInput {
  SpeechStart result = SpeechStart.listening;
  ValueChanged<String>? _onWords;
  void Function(SpeechProblem?)? _onStopped;
  var stops = 0;

  bool get isListening => _onStopped != null;

  @override
  Future<SpeechStart> start({
    required ValueChanged<String> onWords,
    required void Function(SpeechProblem? problem) onStopped,
  }) async {
    if (result == SpeechStart.listening) {
      _onWords = onWords;
      _onStopped = onStopped;
    }
    return result;
  }

  void hear(String words) => _onWords?.call(words);

  void finish([SpeechProblem? problem]) {
    final onStopped = _onStopped;
    _onWords = null;
    _onStopped = null;
    onStopped?.call(problem);
  }

  @override
  Future<void> stop() async {
    stops++;
    finish();
  }
}
