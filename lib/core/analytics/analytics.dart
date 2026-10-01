import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telemetrydecksdk/telemetrydecksdk.dart';

import '../config/api_keys.dart';
import '../llm/llm_client.dart';
import '../settings/display_settings.dart';

/// Anonymous usage counts: how often each feature is used, so the developer
/// knows what people rely on. Never anything personal: no PGNs, chat text,
/// usernames, keys or positions; only the event name and a few small
/// categories (an Elo level, a result, an error kind).
///
/// [track] returns at once and never throws; sending happens in the
/// background, in batches, and waits for a connection when offline.
abstract interface class Analytics {
  void track(String event, [Map<String, Object> details = const {}]);
}

/// Sends nothing: tests, builds without a TelemetryDeck app ID, and players
/// who turned usage stats off.
class NoAnalytics implements Analytics {
  const NoAnalytics();

  @override
  void track(String event, [Map<String, Object> details = const {}]) {}
}

/// [Analytics] through TelemetryDeck, whose native SDKs also count sessions
/// and (as an anonymous hash) devices. Debug builds are marked as test
/// signals, which the dashboard shows apart.
class TelemetryDeckAnalytics implements Analytics {
  TelemetryDeckAnalytics.start({required String appId, required String namespace})
    : _ready = Telemetrydecksdk.start(
        TelemetryManagerConfiguration(
          appID: appId,
          namespace: namespace,
          defaultSignalPrefix: 'MoveWise.',
        ),
      ).catchError((Object error) => debugPrint('Analytics off: $error'));

  /// Starting is async; events wait for it so none go out before it.
  final Future<void> _ready;

  @override
  void track(String event, [Map<String, Object> details = const {}]) {
    unawaited(
      _ready
          .then((_) => Telemetrydecksdk.send(event, additionalPayload: details))
          .catchError((Object error) => debugPrint('Analytics: $error')),
    );
  }

  /// Stops sending, dropping events not yet sent.
  void stop() => unawaited(_ready.then((_) => Telemetrydecksdk.stop()).catchError((_) {}));
}

/// "Share anonymous usage stats" in Settings. On by default; turning it off
/// stops sending at once.
final usageStatsEnabledProvider = NotifierProvider<BoolSetting, bool>(
  () => BoolSetting('usageStats', fallback: true),
);

final analyticsProvider = Provider<Analytics>((ref) {
  if (!ApiKeys.hasTelemetryDeck || !ref.watch(usageStatsEnabledProvider)) {
    return const NoAnalytics();
  }
  final analytics = TelemetryDeckAnalytics.start(
    appId: ApiKeys.telemetryDeckAppId,
    namespace: ApiKeys.telemetryDeckNamespace,
  );
  ref.onDispose(analytics.stop);
  return analytics;
});

/// How an AI request ended, as a short category for [Analytics].
String outcomeOf(Object? error) => switch (error) {
  null => 'ok',
  LlmMissingKey() => 'missing_key',
  LlmInvalidKey() => 'invalid_key',
  LlmRateLimited() => 'rate_limited',
  LlmOffline() => 'offline',
  LlmUnavailable() => 'unavailable',
  _ => 'error',
};

/// The events tracked, in one place so the dashboard's names stay stable.
abstract final class Events {
  /// A game against Stockfish ended. `elo`, `result` (win/draw/loss).
  static const gameFinished = 'Game.finished';

  /// A Pass & Play game ended.
  static const passGameFinished = 'PassGame.finished';

  /// A board photo was read. `outcome` (ok or the failure kind).
  static const scanRead = 'Scan.read';

  /// The AI explanation of a review was asked for. `outcome`.
  static const reviewExplained = 'Review.explained';

  /// A coach question finished. `outcome`, `steps` (tool steps shown).
  static const coachAsked = 'Coach.asked';

  /// An import finished. `platform`, `outcome`, `added`.
  static const importFinished = 'Import.finished';
}
