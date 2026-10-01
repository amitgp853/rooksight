import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_info.dart';
import '../config/remote_config.dart';
import '../storage/settings_store.dart';

/// This app's build number (the `+N` in `pubspec.yaml`). Read from the
/// platform in `main()`; 0 elsewhere, which never asks for an update.
final appBuildProvider = Provider<int>((ref) => 0);

/// Whether this build must, could or needn't be updated.
sealed class AppUpdate {
  const AppUpdate();
}

class UpToDate extends AppUpdate {
  const UpToDate();
}

/// A newer build is out; the player may update or carry on.
class UpdateAvailable extends AppUpdate {
  const UpdateAvailable(this.info);

  final UpdateInfo info;
}

/// This build is no longer supported; the app can't be used until updated.
class UpdateRequired extends AppUpdate {
  const UpdateRequired(this.info);

  final UpdateInfo info;
}

/// What [info] means for [build]. A build of 0 (unknown) is never told to
/// update.
AppUpdate appUpdateFor(int build, UpdateInfo? info) {
  if (info == null || build <= 0) return const UpToDate();
  if (build < info.minBuild) return UpdateRequired(info);
  if (build < info.latestBuild) return UpdateAvailable(info);
  return const UpToDate();
}

/// The update state of this build, from the remote config.
final appUpdateProvider = Provider<AppUpdate>(
  (ref) => appUpdateFor(
    ref.watch(appBuildProvider),
    ref.watch(remoteConfigProvider.select((c) => c.update)),
  ),
);

/// The optional update to offer on Home: null when up to date, or once the
/// player has said "Later" to that build.
final updateOfferProvider = NotifierProvider<UpdateOffer, UpdateInfo?>(UpdateOffer.new);

class UpdateOffer extends Notifier<UpdateInfo?> {
  static const _dismissedKey = 'update.dismissedBuild';

  @override
  UpdateInfo? build() {
    if (ref.watch(appUpdateProvider) case UpdateAvailable(:final info)) {
      final dismissed = int.tryParse(ref.read(settingsStoreProvider).get(_dismissedKey) ?? '');
      if (dismissed == null || dismissed < info.latestBuild) return info;
    }
    return null;
  }

  /// "Later": not offered again until a newer build is out.
  void dismiss() {
    final info = state;
    if (info == null) return;
    ref.read(settingsStoreProvider).set(_dismissedKey, '${info.latestBuild}');
    state = null;
  }
}

/// Where to get the update: the configured store page, or Google Play on
/// Android. Null if there's nowhere to send the player.
String? storeUrlFor(UpdateInfo info, TargetPlatform platform) =>
    info.storeUrl ?? (platform == TargetPlatform.android ? AppInfo.playStoreUrl : null);
