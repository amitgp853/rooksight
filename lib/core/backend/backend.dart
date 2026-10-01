import 'dart:async';
import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../config/api_keys.dart';
import '../llm/llm_client.dart';

/// Rooksight's server: a Firebase function that calls Gemini with the
/// developer's key (see `functions/`). Each install signs in silently as an
/// anonymous user, and App Check shows the requests come from the real app.
/// Nothing about the player is stored there but their free uses and credits.
class Backend {
  Backend._(this.projectId);

  final String projectId;

  /// Where the function is deployed.
  static const region = 'us-central1';

  /// Starts Firebase. Null when this build isn't set up for it (no
  /// `flutterfire configure` yet) or it fails to start: the AI features then
  /// need the player's own key.
  static Future<Backend?> start() async {
    try {
      final app = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      final debugToken = ApiKeys.appCheckDebugToken.isEmpty ? null : ApiKeys.appCheckDebugToken;
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? AndroidDebugProvider(debugToken: debugToken)
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? AppleDebugProvider(debugToken: debugToken)
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
      return Backend._(app.options.projectId);
    } on Object catch (error) {
      debugPrint('Rooksight server unavailable: $error');
      return null;
    }
  }

  /// The AI proxy, which mirrors Gemini's `models/{model}:generateContent`.
  Uri get aiEndpoint => Uri.parse('https://$region-$projectId.cloudfunctions.net/ai/');

  /// The player's ID token and an App Check token, signing in on first use.
  /// Throws [LlmFailure].
  Future<Map<String, String>> authHeaders() async {
    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser ?? (await auth.signInAnonymously()).user!;
      final idToken = await user.getIdToken();
      final appCheck = await FirebaseAppCheck.instance.getToken();
      return {'Authorization': 'Bearer $idToken', 'X-Firebase-AppCheck': ?appCheck};
    } on FirebaseException catch (error) {
      debugPrint('Rooksight server sign-in failed: ${error.plugin}/${error.code} ${error.message}');
      if (error.code == 'network-request-failed') throw const LlmOffline();
      throw LlmUnavailable('sign-in: ${error.code}');
    }
  }

  /// Free uses and credits left. Throws [LlmFailure].
  Future<AiAllowance> allowance() async {
    final http.Response response;
    try {
      response = await http
          .get(aiEndpoint.resolve('status'), headers: await authHeaders())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const LlmOffline();
    } on http.ClientException {
      throw const LlmOffline();
    }
    if (response.statusCode != 200) throw LlmUnavailable('HTTP ${response.statusCode}');
    return AiAllowance.fromJson(jsonDecode(response.body) as Map<String, Object?>);
  }
}

/// What a player may still ask the AI for: free uses this week (they come
/// back each Monday, UTC) and bought credits.
@immutable
class AiAllowance {
  const AiAllowance({
    required this.free,
    required this.freePerWeek,
    required this.price,
    this.credits = 0,
    this.paused = false,
  });

  factory AiAllowance.fromJson(Map<String, Object?> json) {
    Map<LlmActionKind, int> counts(Object? map) => {
      for (final kind in LlmActionKind.values)
        kind: ((map as Map<String, Object?>?)?[kind.name] as num?)?.toInt() ?? 0,
    };
    return AiAllowance(
      free: counts(json['free']),
      freePerWeek: counts(json['freePerWeek']),
      price: counts(json['price']),
      credits: (json['credits'] as num?)?.toInt() ?? 0,
      paused: json['paused'] == true,
    );
  }

  final Map<LlmActionKind, int> free;
  final Map<LlmActionKind, int> freePerWeek;

  /// Credits each kind costs once its free uses are gone.
  final Map<LlmActionKind, int> price;
  final int credits;

  /// Free uses are paused for the rest of the day (the server's spend limit).
  final bool paused;
}

/// The server, when this build has one. Overridden in `main()`.
final backendProvider = Provider<Backend?>((ref) => null);

/// The player's allowance, fetched each time a screen showing it opens.
final aiAllowanceProvider = FutureProvider.autoDispose<AiAllowance?>((ref) async {
  final backend = ref.watch(backendProvider);
  return backend?.allowance();
});
