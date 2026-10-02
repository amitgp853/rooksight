// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Finished games: played against Stockfish or in pass & play, or imported.
///
/// Values are plain text and numbers; [GameRepository] maps them to app types,
/// so the schema doesn't depend on any feature's code.
@DataClassName('GameRow')
class Games extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// A `GameSource` name: `stockfish`, `passAndPlay`, `chesscom` or `lichess`.
  TextColumn get source => text()();

  /// The source's own id (e.g. a Chess.com game URL), to avoid duplicates.
  TextColumn get externalId => text().nullable().unique()();

  /// The whole game as PGN, headers included.
  TextColumn get pgn => text()();

  /// `white` or `black`: the side the user played.
  TextColumn get playerSide => text()();

  /// PGN result: `1-0`, `0-1` or `1/2-1/2`.
  TextColumn get result => text()();

  /// How the game ended (`checkmate`, `timeout`, …), when known.
  TextColumn get endReason => text().nullable()();

  IntColumn get engineElo => integer().nullable()();

  /// Who the user played, e.g. `Stockfish 1600` or a Chess.com username.
  TextColumn get opponentName => text().nullable()();
  IntColumn get opponentRating => integer().nullable()();
  IntColumn get playerRating => integer().nullable()();

  /// Chess.com time class: `bullet`, `blitz`, `rapid` or `daily`.
  TextColumn get timeClass => text().nullable()();

  /// PGN time control, e.g. `600+0`, or null for no clock.
  TextColumn get timeControl => text().nullable()();

  BoolColumn get practice => boolean().withDefault(const Constant(false))();
  IntColumn get hintsUsed => integer().withDefault(const Constant(0))();
  IntColumn get plyCount => integer()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime()();
}

/// App settings as simple key–value pairs.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Which Chess.com archive months have been imported, so finished months are
/// never downloaded twice.
@DataClassName('ImportMonthRow')
class ImportMonths extends Table {
  /// Lower-case Chess.com username.
  TextColumn get username => text()();

  /// `YYYY/MM`, as in the archive URL.
  TextColumn get month => text()();

  /// True once a month that can no longer change has been fully imported.
  BoolColumn get complete => boolean()();

  /// Chess.com's ETag for the month, to ask "has anything changed?".
  TextColumn get etag => text().nullable()();
  IntColumn get gameCount => integer()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {username, month};
}

/// Stockfish's evaluations of a game's positions, saved as they come in so an
/// interrupted analysis resumes where it stopped.
@DataClassName('GameAnalysisRow')
class GameAnalyses extends Table {
  IntColumn get gameId => integer().references(Games, #id, onDelete: KeyAction.cascade)();
  IntColumn get depth => integer()();

  /// JSON list, one entry per position analysed so far, start position first.
  TextColumn get evals => text()();

  /// Every position has been analysed.
  BoolColumn get complete => boolean()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}

/// The AI explanations of a game's key moments (one LLM call, kept).
@DataClassName('GameReviewRow')
class GameReviews extends Table {
  IntColumn get gameId => integer().references(Games, #id, onDelete: KeyAction.cascade)();

  /// The model that wrote it, e.g. `gemini-3.8-flash`.
  TextColumn get model => text()();

  /// The model's JSON reply, after the move check.
  TextColumn get json => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {gameId};
}

/// AI Coach conversations, kept on the phone so they can be reopened and
/// continued. Not tied to [Games]: deleting a game keeps its chats.
@DataClassName('CoachChatRow')
class CoachChats extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// The first question, until renamed.
  TextColumn get title => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// Last activity: the list is sorted and grouped by it.
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get messageCount => integer().withDefault(const Constant(0))();

  /// The game the chat is about, or null for questions across many games.
  IntColumn get gameId => integer().nullable()();

  /// What it's about, as shown: `vs Stockfish 1000 · 28 Sep`.
  TextColumn get scopeLabel => text()();

  /// The position for the list thumbnail, when there's a game.
  TextColumn get thumbFen => text().nullable()();

  /// JSON: what the move check may accept in later answers (moves the tools
  /// reported, and the move cards they described).
  TextColumn get verified => text().withDefault(const Constant('{}'))();
}

/// One message of an AI Coach chat.
@DataClassName('CoachMessageRow')
class CoachMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get chatId => integer().references(CoachChats, #id, onDelete: KeyAction.cascade)();

  /// `user` or `coach`.
  TextColumn get role => text()();
  DateTimeColumn get at => dateTime()();

  /// The question, or the answer as plain text: searched and previewed.
  TextColumn get body => text()();

  /// JSON with the rest: the attached game or move for a question; the
  /// headline, steps and move card for an answer.
  TextColumn get payload => text().withDefault(const Constant('{}'))();
}

/// Positions saved from the analysis board (a scan, one set up by hand, or a
/// game's position), with the moves explored from them.
@DataClassName('SavedPositionRow')
class SavedPositions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();

  /// The start position, as FEN.
  TextColumn get fen => text()();

  /// JSON: the moves explored from [fen], main line first, as a tree of UCI
  /// moves (`[{"m": "e2e4", "c": [...]}]`).
  TextColumn get moves => text().withDefault(const Constant('[]'))();

  /// JSON list of child indices from the start to the position last shown.
  TextColumn get path => text().withDefault(const Constant('[]'))();

  /// An `AnalysisSource` name: `scan`, `setup` or `game`.
  TextColumn get source => text()();

  /// `white` or `black`: the side at the bottom of the board.
  TextColumn get orientation => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@DriftDatabase(
  tables: [
    Games,
    Settings,
    ImportMonths,
    GameAnalyses,
    GameReviews,
    CoachChats,
    CoachMessages,
    SavedPositions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens the app's database file, or [executor] (e.g. in-memory for tests).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'rooksight'));

  /// Bump when the schema changes, and add a step to [migration].
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      // v2 (Phase 3): opponent details on games, Chess.com import log.
      if (from < 2) {
        await migrator.addColumn(games, games.opponentName);
        await migrator.addColumn(games, games.opponentRating);
        await migrator.addColumn(games, games.playerRating);
        await migrator.addColumn(games, games.timeClass);
        await migrator.createTable(importMonths);
        await customStatement(
          "UPDATE games SET opponent_name = 'Stockfish ' || engine_elo "
          'WHERE engine_elo IS NOT NULL',
        );
      }
      // v3 (Phase 4): game analysis and AI review.
      if (from < 3) {
        await migrator.createTable(gameAnalyses);
        await migrator.createTable(gameReviews);
      }
      // v4: AI Coach chat history.
      if (from < 4) {
        await migrator.createTable(coachChats);
        await migrator.createTable(coachMessages);
      }
      // v5: positions saved from the analysis board.
      if (from < 5) {
        await migrator.createTable(savedPositions);
      }
    },
    // Needed for the cascading deletes above.
    beforeOpen: (details) => customStatement('PRAGMA foreign_keys = ON'),
  );
}
