// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';

/// Settings as string key–value pairs, loaded once at start-up so the first
/// frame already has the right theme. Writes go to the database in the
/// background.
class SettingsStore {
  SettingsStore._(this._values, this._persist);

  /// Not persisted: the default for tests and previews.
  SettingsStore.inMemory([Map<String, String>? values]) : this._({...?values}, null);

  /// Loads every setting from [db] and writes changes back to it.
  static Future<SettingsStore> load(AppDatabase db) async {
    final rows = await db.select(db.settings).get();
    return SettingsStore._(
      {for (final row in rows) row.key: row.value},
      (key, value) => db
          .into(db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value)),
    );
  }

  final Map<String, String> _values;
  final Future<void> Function(String key, String value)? _persist;

  String? get(String key) => _values[key];

  void set(String key, String value) {
    if (_values[key] == value) return;
    _values[key] = value;
    _persist?.call(key, value);
  }
}

/// Overridden in `main()` with the loaded, persisted store.
final settingsStoreProvider = Provider<SettingsStore>((ref) => SettingsStore.inMemory());
