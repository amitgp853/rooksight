import 'dart:async';

import 'package:move_wise/core/storage/chat_repository.dart';

/// In-memory [ChatRepository] for widget and controller tests.
class FakeChatRepository implements ChatRepository {
  final _chats = <int, StoredChat>{};
  final _messages = <int, List<StoredMessage>>{};
  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;
  var _nextMessage = 1;

  /// Every message added, in order.
  final added = <StoredMessage>[];

  @override
  Future<int> create(NewChat chat, DateTime now) async {
    final id = _nextId++;
    _chats[id] = StoredChat(
      id: id,
      title: chat.title,
      createdAt: now,
      updatedAt: now,
      messageCount: 0,
      scopeLabel: chat.scopeLabel,
      gameId: chat.gameId,
      thumbFen: chat.thumbFen,
    );
    _messages[id] = [];
    _changes.add(null);
    return id;
  }

  @override
  Future<int> addMessage(int chatId, StoredMessage message) async {
    final id = _nextMessage++;
    final stored = StoredMessage(
      id: id,
      role: message.role,
      at: message.at,
      body: message.body,
      payload: message.payload,
    );
    _messages[chatId]!.add(stored);
    added.add(stored);
    _chats[chatId] = _copy(
      _chats[chatId]!,
      messageCount: _messages[chatId]!.length,
      updatedAt: message.at,
    );
    _changes.add(null);
    return id;
  }

  @override
  Future<void> updateContext(int chatId, {Map<String, Object?>? verified, String? thumbFen}) async {
    _chats[chatId] = _copy(_chats[chatId]!, verified: verified, thumbFen: thumbFen);
    _changes.add(null);
  }

  @override
  Future<void> rename(int chatId, String title) async {
    _chats[chatId] = _copy(_chats[chatId]!, title: title);
    _changes.add(null);
  }

  @override
  Future<void> delete(int chatId) async {
    _chats.remove(chatId);
    _messages.remove(chatId);
    _changes.add(null);
  }

  @override
  Future<StoredChat?> chat(int chatId) async => _chats[chatId];

  @override
  Stream<StoredChat?> watchChat(int chatId) async* {
    yield _chats[chatId];
    await for (final _ in _changes.stream) {
      yield _chats[chatId];
    }
  }

  @override
  Future<List<StoredMessage>> messages(int chatId) async => [...?_messages[chatId]];

  @override
  Stream<List<StoredChat>> watchChats({String search = ''}) async* {
    yield _list(search);
    await for (final _ in _changes.stream) {
      yield _list(search);
    }
  }

  List<StoredChat> _list(String search) {
    final term = search.trim().toLowerCase();
    bool matches(StoredChat c) =>
        term.isEmpty ||
        c.title.toLowerCase().contains(term) ||
        _messages[c.id]!.any((m) => m.body.toLowerCase().contains(term));
    return [
      for (final c in _chats.values.where(matches))
        _copy(c, preview: _messages[c.id]!.lastWhere(
          (m) => m.role == ChatRole.coach,
          orElse: () => StoredMessage(role: ChatRole.coach, at: c.createdAt, body: ''),
        ).body),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static StoredChat _copy(
    StoredChat c, {
    String? title,
    DateTime? updatedAt,
    int? messageCount,
    Map<String, Object?>? verified,
    String? thumbFen,
    String? preview,
  }) => StoredChat(
    id: c.id,
    title: title ?? c.title,
    createdAt: c.createdAt,
    updatedAt: updatedAt ?? c.updatedAt,
    messageCount: messageCount ?? c.messageCount,
    scopeLabel: c.scopeLabel,
    gameId: c.gameId,
    thumbFen: thumbFen ?? c.thumbFen,
    verified: verified ?? c.verified,
    preview: preview ?? c.preview,
  );
}
