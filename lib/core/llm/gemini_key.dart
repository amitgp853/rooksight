// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_keys.dart';

/// Where the player's own Gemini key is kept, behind an interface so tests
/// can use memory.
abstract interface class GeminiKeyStorage {
  Future<String?> read();
  Future<void> write(String key);
  Future<void> delete();
}

/// The iOS Keychain / Android encrypted storage: only on this phone.
class SecureGeminiKeyStorage implements GeminiKeyStorage {
  static const _storage = FlutterSecureStorage();
  static const _name = 'gemini_api_key';

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _name);
    } on PlatformException catch (error) {
      // E.g. Android storage that can't be decrypted after a backup restore:
      // the player just adds the key again.
      debugPrint('Gemini key unreadable: ${error.message}');
      return null;
    }
  }

  @override
  Future<void> write(String key) => _storage.write(key: _name, value: key);

  @override
  Future<void> delete() => _storage.delete(key: _name);
}

class MemoryGeminiKeyStorage implements GeminiKeyStorage {
  MemoryGeminiKeyStorage([this.key]);

  String? key;

  @override
  Future<String?> read() async => key;

  @override
  Future<void> write(String key) async => this.key = key;

  @override
  Future<void> delete() async => key = null;
}

/// The storage, and the key it held at start-up (read before the first
/// frame, so the AI features know at once). Overridden in `main()`.
final geminiKeyStorageProvider = Provider<GeminiKeyStorage>((ref) => MemoryGeminiKeyStorage());
final savedGeminiKeyAtStartProvider = Provider<String?>((ref) => null);

/// The key the player pasted in Settings, if any.
class SavedGeminiKey extends Notifier<String?> {
  @override
  String? build() => ref.read(savedGeminiKeyAtStartProvider);

  Future<void> save(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return remove();
    await ref.read(geminiKeyStorageProvider).write(trimmed);
    state = trimmed;
  }

  Future<void> remove() async {
    await ref.read(geminiKeyStorageProvider).delete();
    state = null;
  }
}

final savedGeminiKeyProvider = NotifierProvider<SavedGeminiKey, String?>(SavedGeminiKey.new);

/// The key the AI features use: the player's own, else (in development) one
/// passed in at build time with `--dart-define-from-file=.env`.
final geminiKeyProvider = Provider<String>(
  (ref) => ref.watch(savedGeminiKeyProvider) ?? ApiKeys.gemini,
);
