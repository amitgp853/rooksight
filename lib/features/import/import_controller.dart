import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/game_repository.dart';
import '../../core/storage/import_log.dart';
import '../../core/storage/settings_store.dart';
import '../play/domain/game_controller.dart' show nowProvider;
import 'data/chess_com_api.dart';
import 'data/lichess_api.dart';
import 'domain/importer.dart';

/// The username on each platform, remembered on this device (one each).
final importUsernameProvider = NotifierProvider.family<ImportUsername, String, ImportPlatform>(
  ImportUsername.new,
);

/// The Chess.com username.
final chessComUsernameProvider = importUsernameProvider(ImportPlatform.chessCom);

/// The Lichess username.
final lichessUsernameProvider = importUsernameProvider(ImportPlatform.lichess);

class ImportUsername extends Notifier<String> {
  ImportUsername(this.platform);

  final ImportPlatform platform;

  String get _key => switch (platform) {
    ImportPlatform.chessCom => 'chesscom.username',
    ImportPlatform.lichess => 'lichess.username',
  };

  @override
  String build() => ref.watch(settingsStoreProvider).get(_key) ?? '';

  void set(String username) {
    state = username.trim();
    ref.read(settingsStoreProvider).set(_key, state);
  }
}

/// The current (or last) import. Not auto-disposed: an import keeps running
/// when the screen closes, and the screen shows its progress on return.
final importControllerProvider = NotifierProvider<ImportController, ImportProgress>(
  ImportController.new,
);

class ImportController extends Notifier<ImportProgress> {
  StreamSubscription<ImportProgress>? _run;
  bool _cancelled = false;

  @override
  ImportProgress build() {
    ref.onDispose(() => _run?.cancel());
    return const ImportProgress();
  }

  /// Starts importing [username]'s games on [platform] from [range].
  /// Ignored while an import is running.
  void start(ImportPlatform platform, String username, ImportRange range) {
    if (state.isRunning || username.trim().isEmpty) return;
    ref.read(importUsernameProvider(platform).notifier).set(username);
    _cancelled = false;
    final games = ref.read(gameRepositoryProvider);
    final now = ref.read(nowProvider);
    final run = switch (platform) {
      ImportPlatform.chessCom => Importer(
        api: ref.read(chessComApiProvider),
        games: games,
        log: ref.read(importLogProvider),
        now: now,
      ).run(username, range, isCancelled: () => _cancelled),
      ImportPlatform.lichess => LichessImporter(
        api: ref.read(lichessApiProvider),
        games: games,
        settings: ref.read(settingsStoreProvider),
        now: now,
      ).run(username, range, isCancelled: () => _cancelled),
    };
    _run = run.listen((progress) => state = progress);
  }

  /// Stops after the month being fetched.
  void cancel() => _cancelled = true;

  /// Back to the form after a finished, cancelled or failed import.
  void reset() {
    if (!state.isRunning) state = const ImportProgress();
  }
}
