// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io' as io;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/chat_repository.dart';
import 'package:rooksight/core/storage/database.dart';
import 'package:rooksight/core/storage/game_repository.dart';

import 'storage_test.dart' show record;

void main() {
  late AppDatabase db;
  late DriftChatRepository chats;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    chats = DriftChatRepository(db);
  });
  tearDown(() => db.close());

  final day = DateTime(2026, 9, 26, 10);

  StoredMessage question(String text, DateTime at) =>
      StoredMessage(role: ChatRole.user, at: at, body: text);
  StoredMessage answer(String text, DateTime at) =>
      StoredMessage(role: ChatRole.coach, at: at, body: text, payload: const {'headline': 'Point'});

  Future<int> chatWith(String title, DateTime at, {int? gameId}) =>
      chats.create(NewChat(title: title, scopeLabel: 'Your recent games', gameId: gameId), at);

  test('saves a chat and its messages in order, counting them', () async {
    final id = await chatWith('Why do I lose?', day);
    await chats.addMessage(id, question('Why do I lose?', day));
    await chats.addMessage(
      id,
      answer('You weaken your king.', day.add(const Duration(minutes: 1))),
    );

    final chat = (await chats.chat(id))!;
    expect(chat.title, 'Why do I lose?');
    expect(chat.messageCount, 2);
    expect(chat.updatedAt, day.add(const Duration(minutes: 1)));
    expect(chat.scopeLabel, 'Your recent games');

    final messages = await chats.messages(id);
    expect([for (final m in messages) m.role], [ChatRole.user, ChatRole.coach]);
    expect(messages.last.payload, {'headline': 'Point'});
  });

  test('the list: latest activity first, with the last answer as preview', () async {
    final older = await chatWith('Older', day);
    final newer = await chatWith('Newer', day.add(const Duration(hours: 1)));
    await chats.addMessage(older, answer('First answer', day.add(const Duration(hours: 2))));
    await chats.addMessage(older, answer('Latest answer', day.add(const Duration(hours: 3))));

    final list = await chats.watchChats().first;
    expect([for (final c in list) c.id], [older, newer], reason: 'older chat had newer activity');
    expect(list.first.preview, 'Latest answer');
    expect(list.last.preview, isNull);
  });

  test('search matches titles and message text, literally', () async {
    final a = await chatWith('Middlegame trouble', day);
    final b = await chatWith('Openings', day);
    await chats.addMessage(b, answer('Your 50% score with the Sicilian…', day));

    Future<List<int>> find(String term) async => [
      for (final c in await chats.watchChats(search: term).first) c.id,
    ];
    expect(await find('middle'), [a]);
    expect(await find('sicilian'), [b]);
    expect(await find('50%'), [b]);
    expect(await find('5_%'), isEmpty, reason: '_ and % are not wildcards');
    expect((await find('')).toSet(), {a, b});
  });

  test('rename, and updating the move-check context', () async {
    final id = await chatWith('Why do I lose?', day);
    await chats.rename(id, 'King safety');
    await chats.updateContext(
      id,
      verified: {
        'moves': ['Qg5'],
      },
      thumbFen: '8/8/8/8/8/8/8/K6k w - - 0 1',
    );

    final chat = (await chats.chat(id))!;
    expect(chat.title, 'King safety');
    expect(chat.verified, {
      'moves': ['Qg5'],
    });
    expect(chat.thumbFen, '8/8/8/8/8/8/8/K6k w - - 0 1');
  });

  test('deleting a chat deletes its messages; deleting a game keeps chats', () async {
    final games = DriftGameRepository(db);
    final gameId = await games.save(record());
    final kept = await chatWith('About the game', day, gameId: gameId);
    final gone = await chatWith('Delete me', day);
    await chats.addMessage(gone, question('Delete me', day));

    await chats.delete(gone);
    await games.delete(gameId);

    expect(await chats.chat(gone), isNull);
    expect(await chats.messages(gone), isEmpty);
    expect((await chats.chat(kept))!.gameId, gameId);
  });

  test('v3 → v4 keeps games and adds the chat tables', () async {
    final v3Schema = io.File('test/core/storage/schema_v3.sql').readAsStringSync();
    final upgraded = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw.execute(v3Schema);
          raw.execute(
            'INSERT INTO games (source, pgn, player_side, result, ply_count, '
            "started_at, ended_at) VALUES ('stockfish', '1. e4 *', 'white', '1-0', 1, 0, 0)",
          );
          raw.execute('PRAGMA user_version = 3');
        },
      ),
    );
    addTearDown(upgraded.close);

    expect(await DriftGameRepository(upgraded).watchAll().first, hasLength(1));
    final repo = DriftChatRepository(upgraded);
    final id = await repo.create(const NewChat(title: 'Hi', scopeLabel: 'Your recent games'), day);
    await repo.addMessage(id, question('Hi', day));
    expect((await repo.chat(id))!.messageCount, 1);
  });
}
