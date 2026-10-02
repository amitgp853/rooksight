// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// How a request to start listening went.
enum SpeechStart {
  listening,

  /// The player said no to the microphone or speech recognition.
  denied,

  /// The phone has no speech recognition.
  unavailable,

  /// Speech recognition is there but couldn't start this time.
  failed,
}

/// Why listening ended early.
enum SpeechProblem {
  /// Nothing was recognised: silence, or words it couldn't make out.
  notHeard,

  /// The phone's recognition needed the network and couldn't reach it.
  offline,

  /// Anything else the phone reported.
  failed,
}

/// Speech to text for typed questions, behind an interface so tests can
/// fake it. Uses the phone's own recognition: no key, no AI requests.
abstract interface class SpeechInput {
  /// Starts listening. [onWords] gets everything heard so far, each time it
  /// changes; [onStopped] runs once when listening ends, however it ends
  /// (a pause, [stop], or an error, given as its problem).
  Future<SpeechStart> start({
    required ValueChanged<String> onWords,
    required void Function(SpeechProblem? problem) onStopped,
  });

  /// Stops listening; the words heard so far stay.
  Future<void> stop();
}

final speechInputProvider = Provider<SpeechInput>((ref) => DeviceSpeechInput());

/// [SpeechInput] on the phone's speech recognition, via `speech_to_text`.
class DeviceSpeechInput implements SpeechInput {
  final _speech = SpeechToText();
  void Function(SpeechProblem?)? _onStopped;

  /// Listening ends by itself after this long without speech.
  static const _pause = Duration(seconds: 3);

  @override
  Future<SpeechStart> start({
    required ValueChanged<String> onWords,
    required void Function(SpeechProblem? problem) onStopped,
  }) async {
    // Asks for permission the first time. Not cached when it fails, so
    // access granted later in Settings works without a restart.
    final bool ready;
    try {
      ready = await _speech.initialize(onStatus: _onStatus, onError: _onError);
    } on PlatformException catch (error) {
      _log('initialize failed: ${error.code} ${error.message}');
      return SpeechStart.failed;
    }
    if (!ready) {
      final allowed = await _speech.hasPermission;
      _log('not ready, permission: $allowed');
      return allowed ? SpeechStart.unavailable : SpeechStart.denied;
    }
    _onStopped = onStopped;
    try {
      await _speech.listen(
        onResult: (result) => onWords(result.recognizedWords),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          pauseFor: _pause,
        ),
      );
    } on Exception catch (error) {
      _log('listen failed: $error');
      _onStopped = null;
      return SpeechStart.failed;
    }
    return SpeechStart.listening;
  }

  @override
  Future<void> stop() => _speech.stop();

  void _onStatus(String status) {
    _log('status: $status');
    if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
      _stopped(null);
    }
  }

  void _onError(SpeechRecognitionError error) {
    _log('error: ${error.errorMsg} (permanent: ${error.permanent})');
    _stopped(switch (error.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => SpeechProblem.notHeard,
      'error_network' || 'error_network_timeout' || 'error_server' => SpeechProblem.offline,
      _ => SpeechProblem.failed,
    });
  }

  void _stopped(SpeechProblem? problem) {
    final onStopped = _onStopped;
    _onStopped = null;
    onStopped?.call(problem);
  }

  /// What the phone's recognition reports, for the debug console only.
  static void _log(String message) {
    if (kDebugMode) debugPrint('Speech $message');
  }
}
