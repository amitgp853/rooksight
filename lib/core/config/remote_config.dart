import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../storage/settings_store.dart';
import 'app_info.dart';

/// Settings the developer can change without a release, read from
/// `config/remote.json` in the GitHub repo (see [AppInfo.remoteConfigUrl]).
///
/// Every field is optional: a missing or malformed one means "use what the
/// app ships with", so a typo in the file can never break the app.
@immutable
class RemoteConfig {
  const RemoteConfig({this.update, this.models});

  /// Nothing fetched yet (first launch, or offline): the built-in defaults.
  static const none = RemoteConfig();

  /// The schema this app understands. A file with a newer one is ignored.
  static const schema = 1;

  /// Store builds for this platform.
  final UpdateInfo? update;

  /// The Gemini models to use.
  final RemoteModels? models;

  /// Parses `remote.json`, taking the update block for [platform]
  /// (`android` or `ios`). Throws [FormatException] if it isn't a JSON
  /// object of a known schema.
  factory RemoteConfig.parse(String body, {required TargetPlatform platform}) {
    final json = jsonDecode(body);
    if (json is! Map<String, Object?>) throw const FormatException('not an object');
    final version = json['schema'];
    if (version is! int || version > schema) throw FormatException('schema $version');

    final update = json['update'];
    final key = switch (platform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      _ => null,
    };
    return RemoteConfig(
      update: update is Map<String, Object?> && key != null
          ? UpdateInfo.fromJson(update[key], message: update['message'])
          : null,
      models: RemoteModels.fromJson(json['llm']),
    );
  }
}

/// The newest store build and the oldest one still allowed to run.
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.latestBuild,
    required this.minBuild,
    this.storeUrl,
    this.message,
  });

  /// Builds below this see an optional "Update available".
  final int latestBuild;

  /// Builds below this must update before they can be used.
  final int minBuild;

  /// The app's store page; null means the default for the platform.
  final String? storeUrl;

  /// What's new, shown with the prompt.
  final String? message;

  static UpdateInfo? fromJson(Object? json, {Object? message}) {
    if (json is! Map<String, Object?>) return null;
    final latest = json['latestBuild'];
    final min = json['minBuild'];
    if (latest is! int) return null;
    final url = json['storeUrl'];
    return UpdateInfo(
      latestBuild: latest,
      // A minimum above the latest build would lock out even the newest app.
      minBuild: min is int && min <= latest ? min : 0,
      storeUrl: url is String && url.startsWith('https://') ? url : null,
      message: message is String && message.trim().isNotEmpty ? message.trim() : null,
    );
  }
}

/// The Gemini models chosen remotely. Unknown names are dropped.
@immutable
class RemoteModels {
  const RemoteModels({this.model, this.fallbackModel, this.thinkingLevel});

  final String? model;
  final String? fallbackModel;

  /// `minimal`, `low`, `medium` or `high`; empty for the model's default.
  final String? thinkingLevel;

  static final _modelName = RegExp(r'^gemini-[a-z0-9][a-z0-9.\-]*$');
  static const _thinkingLevels = {'', 'minimal', 'low', 'medium', 'high'};

  static RemoteModels? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    String? name(Object? value) => value is String && _modelName.hasMatch(value) ? value : null;
    final thinking = json['thinkingLevel'];
    return RemoteModels(
      model: name(json['model']),
      fallbackModel: name(json['fallbackModel']),
      thinkingLevel: thinking is String && _thinkingLevels.contains(thinking) ? thinking : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RemoteModels &&
      other.model == model &&
      other.fallbackModel == fallbackModel &&
      other.thinkingLevel == thinkingLevel;

  @override
  int get hashCode => Object.hash(model, fallbackModel, thinkingLevel);
}

/// Downloads `remote.json`. Overridden in tests.
final remoteConfigFetchProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(AppInfo.remoteConfigUrl), headers: {'User-Agent': AppInfo.userAgent})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw http.ClientException('HTTP ${response.statusCode}');
      return utf8.decode(response.bodyBytes);
    } finally {
      client.close();
    }
  };
});

/// Today's time, for spacing out refreshes. Overridden in tests.
final remoteConfigClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The remote config in force. Starts from the copy saved by the last
/// successful fetch, so it costs nothing at launch and works offline;
/// [RemoteConfigController.refresh] then fetches a fresh copy in the
/// background.
final remoteConfigProvider = NotifierProvider<RemoteConfigController, RemoteConfig>(
  RemoteConfigController.new,
);

class RemoteConfigController extends Notifier<RemoteConfig> {
  static const _bodyKey = 'remoteConfig.body';
  static const _fetchedKey = 'remoteConfig.fetchedAt';

  /// A phone left in the background for days still hears about a forced
  /// update when it comes back, without fetching on every unlock.
  static const refreshEvery = Duration(hours: 1);

  Future<void>? _running;

  @override
  RemoteConfig build() {
    final saved = ref.watch(settingsStoreProvider).get(_bodyKey);
    if (saved == null) return RemoteConfig.none;
    try {
      return RemoteConfig.parse(saved, platform: defaultTargetPlatform);
    } on FormatException {
      return RemoteConfig.none;
    }
  }

  /// Fetches the config unless it was fetched within [refreshEvery] (or
  /// [force]). Failures keep the current config: offline is normal.
  Future<void> refresh({bool force = false}) {
    if (!force && !_due) return Future.value();
    return _running ??= _fetch().whenComplete(() => _running = null);
  }

  bool get _due {
    final fetched = DateTime.tryParse(ref.read(settingsStoreProvider).get(_fetchedKey) ?? '');
    return fetched == null ||
        ref.read(remoteConfigClockProvider)().difference(fetched) >= refreshEvery;
  }

  Future<void> _fetch() async {
    try {
      final body = await ref.read(remoteConfigFetchProvider)();
      final config = RemoteConfig.parse(body, platform: defaultTargetPlatform);
      if (!ref.mounted) return;
      ref.read(settingsStoreProvider)
        ..set(_bodyKey, body)
        ..set(_fetchedKey, ref.read(remoteConfigClockProvider)().toIso8601String());
      state = config;
    } on Object catch (error) {
      debugPrint('Remote config not updated: $error');
    }
  }
}
