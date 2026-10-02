// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'game_repository.dart' show appDatabaseProvider;

/// Who wrote a message.
enum ChatRole { user, coach }

/// An AI Coach chat as stored, without its messages.
@immutable
class StoredChat {
  const StoredChat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    required this.scopeLabel,
    this.gameId,
    this.thumbFen,
    this.verified = const {},
    this.preview,
  });

  final int id;
  final String title;
  final DateTime createdAt;

  /// Last activity.
  final DateTime updatedAt;
  final int messageCount;

  /// What the chat is about: `vs Stockfish 1000 · 28 Sep`, `Your recent games`.
  final String scopeLabel;
  final int? gameId;
  final String? thumbFen;

  /// What the move check may accept in later answers (see the coach).
  final Map<String, Object?> verified;

  /// The start of the last answer, for the list; null in a single read.
  final String? preview;
}

/// A new chat: saved when its first question is sent.
@immutable
class NewChat {
  const NewChat({required this.title, required this.scopeLabel, this.gameId, this.thumbFen});

  final String title;
  final String scopeLabel;
  final int? gameId;
  final String? thumbFen;
}

/// One message as stored: plain [body] text (searched and previewed) plus a
/// JSON [payload] the coach reads back.
@immutable
class StoredMessage {
  const StoredMessage({
    required this.role,
    required this.at,
    required this.body,
    this.payload = const {},
    this.id,
  });

  /// Null until saved.
  final int? id;
  final ChatRole role;
  final DateTime at;
  final String body;
  final Map<String, Object?> payload;
}

/// Stores AI Coach chats on the phone. Behind an interface so tests can use a
/// fake.
abstract interface class ChatRepository {
  /// Saves a new chat and returns its id.
  Future<int> create(NewChat chat, DateTime now);

  /// Appends [message] to chat [chatId], moving the chat to the top.
  Future<int> addMessage(int chatId, StoredMessage message);

  /// Updates what the move check may accept, and the thumbnail.
  Future<void> updateContext(int chatId, {Map<String, Object?>? verified, String? thumbFen});

  Future<void> rename(int chatId, String title);

  /// Deletes chat [chatId] with its messages.
  Future<void> delete(int chatId);

  Future<StoredChat?> chat(int chatId);

  /// The chat as it changes (renamed, new messages); null once deleted.
  Stream<StoredChat?> watchChat(int chatId);

  /// Chat [chatId]'s messages, oldest first.
  Future<List<StoredMessage>> messages(int chatId);

  /// Every chat, most recent activity first, each with a [StoredChat.preview].
  /// A non-empty [search] keeps chats whose title or messages contain it.
  Stream<List<StoredChat>> watchChats({String search = ''});
}

class DriftChatRepository implements ChatRepository {
  DriftChatRepository(this._db);

  final AppDatabase _db;

  @override
  Future<int> create(NewChat chat, DateTime now) {
    return _db
        .into(_db.coachChats)
        .insert(
          CoachChatsCompanion.insert(
            title: chat.title,
            createdAt: now,
            updatedAt: now,
            scopeLabel: chat.scopeLabel,
            gameId: Value(chat.gameId),
            thumbFen: Value(chat.thumbFen),
          ),
        );
  }

  @override
  Future<int> addMessage(int chatId, StoredMessage message) {
    return _db.transaction(() async {
      final id = await _db
          .into(_db.coachMessages)
          .insert(
            CoachMessagesCompanion.insert(
              chatId: chatId,
              role: message.role.name,
              at: message.at,
              body: message.body,
              payload: Value(jsonEncode(message.payload)),
            ),
          );
      await _db.customUpdate(
        'UPDATE coach_chats SET message_count = message_count + 1, updated_at = ? WHERE id = ?',
        variables: [Variable.withDateTime(message.at), Variable.withInt(chatId)],
        updates: {_db.coachChats},
      );
      return id;
    });
  }

  @override
  Future<void> updateContext(int chatId, {Map<String, Object?>? verified, String? thumbFen}) {
    return (_db.update(_db.coachChats)..where((c) => c.id.equals(chatId))).write(
      CoachChatsCompanion(
        verified: verified == null ? const Value.absent() : Value(jsonEncode(verified)),
        thumbFen: thumbFen == null ? const Value.absent() : Value(thumbFen),
      ),
    );
  }

  @override
  Future<void> rename(int chatId, String title) {
    return (_db.update(
      _db.coachChats,
    )..where((c) => c.id.equals(chatId))).write(CoachChatsCompanion(title: Value(title)));
  }

  @override
  Future<void> delete(int chatId) async {
    // The messages go with it (ON DELETE CASCADE).
    await (_db.delete(_db.coachChats)..where((c) => c.id.equals(chatId))).go();
  }

  @override
  Future<StoredChat?> chat(int chatId) async {
    final row = await (_db.select(
      _db.coachChats,
    )..where((c) => c.id.equals(chatId))).getSingleOrNull();
    return row == null ? null : _toChat(row);
  }

  @override
  Stream<StoredChat?> watchChat(int chatId) {
    final query = _db.select(_db.coachChats)..where((c) => c.id.equals(chatId));
    return query.watchSingleOrNull().map((row) => row == null ? null : _toChat(row));
  }

  @override
  Future<List<StoredMessage>> messages(int chatId) async {
    final rows =
        await (_db.select(_db.coachMessages)
              ..where((m) => m.chatId.equals(chatId))
              ..orderBy([(m) => OrderingTerm.asc(m.id)]))
            .get();
    return [
      for (final row in rows)
        StoredMessage(
          id: row.id,
          role: ChatRole.values.byName(row.role),
          at: row.at,
          body: row.body,
          payload: _json(row.payload),
        ),
    ];
  }

  @override
  Stream<List<StoredChat>> watchChats({String search = ''}) {
    final term = search.trim();
    final like = '%${term.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
    return _db
        .customSelect(
          'SELECT c.*, '
          '(SELECT m.body FROM coach_messages m WHERE m.chat_id = c.id AND m.role = \'coach\' '
          'ORDER BY m.id DESC LIMIT 1) AS preview '
          'FROM coach_chats c '
          "WHERE ?1 = '' OR c.title LIKE ?2 ESCAPE '\\' OR EXISTS "
          '(SELECT 1 FROM coach_messages m2 WHERE m2.chat_id = c.id '
          "AND m2.body LIKE ?2 ESCAPE '\\') "
          'ORDER BY c.updated_at DESC, c.id DESC',
          variables: [Variable.withString(term), Variable.withString(like)],
          readsFrom: {_db.coachChats, _db.coachMessages},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              _toChat(_db.coachChats.map(row.data), preview: row.readNullable<String>('preview')),
          ],
        );
  }

  static StoredChat _toChat(CoachChatRow row, {String? preview}) => StoredChat(
    id: row.id,
    title: row.title,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    messageCount: row.messageCount,
    scopeLabel: row.scopeLabel,
    gameId: row.gameId,
    thumbFen: row.thumbFen,
    verified: _json(row.verified),
    preview: preview,
  );

  static Map<String, Object?> _json(String text) {
    try {
      return (jsonDecode(text) as Map<String, Object?>?) ?? const {};
    } on Object {
      return const {};
    }
  }
}

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => DriftChatRepository(ref.watch(appDatabaseProvider)),
);
