import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'core/board/board_style.dart';
import 'core/llm/gemini_key.dart';
import 'core/storage/database.dart';
import 'core/storage/game_repository.dart';
import 'core/storage/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts/; never download them.
  GoogleFonts.config.allowRuntimeFetching = false;

  final database = AppDatabase();
  final keyStorage = SecureGeminiKeyStorage();
  // Settings load before the first frame, so the saved theme shows at once.
  final (settings, geminiKey, _) = await (
    SettingsStore.load(database),
    keyStorage.read(),
    precachePieces(),
  ).wait;

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        settingsStoreProvider.overrideWithValue(settings),
        geminiKeyStorageProvider.overrideWithValue(keyStorage),
        savedGeminiKeyAtStartProvider.overrideWithValue(geminiKey),
      ],
      child: const MoveWiseApp(),
    ),
  );
}
