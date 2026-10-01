import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app.dart';
import 'core/backend/backend.dart';
import 'core/board/board_style.dart';
import 'core/llm/gemini_key.dart';
import 'core/storage/database.dart';
import 'core/storage/game_repository.dart';
import 'core/storage/settings_store.dart';
import 'core/update/app_update.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts/; never download them.
  GoogleFonts.config.allowRuntimeFetching = false;

  final database = AppDatabase();
  final keyStorage = SecureGeminiKeyStorage();
  // Settings load before the first frame, so the saved theme shows at once.
  final (settings, geminiKey, package, backend, _) = await (
    SettingsStore.load(database),
    keyStorage.read(),
    PackageInfo.fromPlatform(),
    Backend.start(),
    precachePieces(),
  ).wait;

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsStoreProvider.overrideWithValue(settings),
        geminiKeyStorageProvider.overrideWithValue(keyStorage),
        savedGeminiKeyAtStartProvider.overrideWithValue(geminiKey),
        appBuildProvider.overrideWithValue(int.tryParse(package.buildNumber) ?? 0),
        backendProvider.overrideWithValue(backend),
      ],
      child: const RooksightApp(),
    ),
  );
}
