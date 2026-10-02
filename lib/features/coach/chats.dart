// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/chat_repository.dart';

/// Saved chats matching a search ('' for all), most recent first.
final chatsProvider = StreamProvider.autoDispose.family<List<StoredChat>, String>(
  (ref, search) => ref.watch(chatRepositoryProvider).watchChats(search: search),
);

/// One saved chat as it changes (renamed, new messages); null once deleted.
final chatProvider = StreamProvider.autoDispose.family<StoredChat?, int>(
  (ref, id) => ref.watch(chatRepositoryProvider).watchChat(id),
);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

int _daysBetween(DateTime date, DateTime now) => DateTime(
  now.year,
  now.month,
  now.day,
).difference(DateTime(date.year, date.month, date.day)).inDays;

/// A chat's last activity in the list: `Today`, `Yesterday`, a weekday
/// within the week (`Sat`), else `19 Sep`.
String chatWhen(DateTime date, DateTime now) {
  final days = _daysBetween(date, now);
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return _weekdays[date.weekday - 1];
  return shortDay(date, now);
}

/// `26 Sep`, with the year when it isn't this one.
String shortDay(DateTime date, DateTime now) {
  final label = '${date.day} ${_months[date.month - 1]}';
  return date.year == now.year ? label : '$label ${date.year}';
}

/// A day divider in a saved chat: `Today`, `Yesterday`, else `Sat 26 Sep`.
String dayDivider(DateTime date, DateTime now) {
  final days = _daysBetween(date, now);
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  return '${_weekdays[date.weekday - 1]} ${shortDay(date, now)}';
}

/// `1 message`, `4 messages`.
String messagesLabel(int count) => count == 1 ? '1 message' : '$count messages';

/// The list's groups: active in the last 7 days, then older.
({List<StoredChat> thisWeek, List<StoredChat> earlier}) groupChats(
  List<StoredChat> chats,
  DateTime now,
) {
  bool recent(StoredChat c) => _daysBetween(c.updatedAt, now) < 7;
  return (thisWeek: chats.where(recent).toList(), earlier: chats.where((c) => !recent(c)).toList());
}
