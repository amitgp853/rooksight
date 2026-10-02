// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'game_repository.dart';

/// What was last imported from one Chess.com archive month.
@immutable
class ImportedMonth {
  const ImportedMonth({required this.complete, required this.gameCount, this.etag});

  /// The month is over and fully imported: never fetch it again.
  final bool complete;
  final int gameCount;

  /// Chess.com's ETag, sent back to ask whether anything changed.
  final String? etag;
}

/// Remembers imported archive months per user. Behind an interface for tests.
abstract interface class ImportLog {
  Future<ImportedMonth?> get(String username, String month);

  Future<void> record(String username, String month, ImportedMonth imported);
}

class DriftImportLog implements ImportLog {
  DriftImportLog(this._db);

  final AppDatabase _db;

  @override
  Future<ImportedMonth?> get(String username, String month) async {
    final row =
        await (_db.select(_db.importMonths)
              ..where((m) => m.username.equals(username.toLowerCase()) & m.month.equals(month)))
            .getSingleOrNull();
    return row == null
        ? null
        : ImportedMonth(complete: row.complete, gameCount: row.gameCount, etag: row.etag);
  }

  @override
  Future<void> record(String username, String month, ImportedMonth imported) {
    return _db
        .into(_db.importMonths)
        .insertOnConflictUpdate(
          ImportMonthsCompanion.insert(
            username: username.toLowerCase(),
            month: month,
            complete: imported.complete,
            etag: Value(imported.etag),
            gameCount: imported.gameCount,
            fetchedAt: DateTime.now(),
          ),
        );
  }
}

final importLogProvider = Provider<ImportLog>(
  (ref) => DriftImportLog(ref.watch(appDatabaseProvider)),
);
