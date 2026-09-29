// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GamesTable extends Games with TableInfo<$GamesTable, GameRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GamesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _externalIdMeta = const VerificationMeta(
    'externalId',
  );
  @override
  late final GeneratedColumn<String> externalId = GeneratedColumn<String>(
    'external_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _pgnMeta = const VerificationMeta('pgn');
  @override
  late final GeneratedColumn<String> pgn = GeneratedColumn<String>(
    'pgn',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _playerSideMeta = const VerificationMeta(
    'playerSide',
  );
  @override
  late final GeneratedColumn<String> playerSide = GeneratedColumn<String>(
    'player_side',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resultMeta = const VerificationMeta('result');
  @override
  late final GeneratedColumn<String> result = GeneratedColumn<String>(
    'result',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endReasonMeta = const VerificationMeta(
    'endReason',
  );
  @override
  late final GeneratedColumn<String> endReason = GeneratedColumn<String>(
    'end_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _engineEloMeta = const VerificationMeta(
    'engineElo',
  );
  @override
  late final GeneratedColumn<int> engineElo = GeneratedColumn<int>(
    'engine_elo',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _opponentNameMeta = const VerificationMeta(
    'opponentName',
  );
  @override
  late final GeneratedColumn<String> opponentName = GeneratedColumn<String>(
    'opponent_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _opponentRatingMeta = const VerificationMeta(
    'opponentRating',
  );
  @override
  late final GeneratedColumn<int> opponentRating = GeneratedColumn<int>(
    'opponent_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _playerRatingMeta = const VerificationMeta(
    'playerRating',
  );
  @override
  late final GeneratedColumn<int> playerRating = GeneratedColumn<int>(
    'player_rating',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeClassMeta = const VerificationMeta(
    'timeClass',
  );
  @override
  late final GeneratedColumn<String> timeClass = GeneratedColumn<String>(
    'time_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _timeControlMeta = const VerificationMeta(
    'timeControl',
  );
  @override
  late final GeneratedColumn<String> timeControl = GeneratedColumn<String>(
    'time_control',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _practiceMeta = const VerificationMeta(
    'practice',
  );
  @override
  late final GeneratedColumn<bool> practice = GeneratedColumn<bool>(
    'practice',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("practice" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _hintsUsedMeta = const VerificationMeta(
    'hintsUsed',
  );
  @override
  late final GeneratedColumn<int> hintsUsed = GeneratedColumn<int>(
    'hints_used',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _plyCountMeta = const VerificationMeta(
    'plyCount',
  );
  @override
  late final GeneratedColumn<int> plyCount = GeneratedColumn<int>(
    'ply_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    source,
    externalId,
    pgn,
    playerSide,
    result,
    endReason,
    engineElo,
    opponentName,
    opponentRating,
    playerRating,
    timeClass,
    timeControl,
    practice,
    hintsUsed,
    plyCount,
    startedAt,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'games';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('external_id')) {
      context.handle(
        _externalIdMeta,
        externalId.isAcceptableOrUnknown(data['external_id']!, _externalIdMeta),
      );
    }
    if (data.containsKey('pgn')) {
      context.handle(
        _pgnMeta,
        pgn.isAcceptableOrUnknown(data['pgn']!, _pgnMeta),
      );
    } else if (isInserting) {
      context.missing(_pgnMeta);
    }
    if (data.containsKey('player_side')) {
      context.handle(
        _playerSideMeta,
        playerSide.isAcceptableOrUnknown(data['player_side']!, _playerSideMeta),
      );
    } else if (isInserting) {
      context.missing(_playerSideMeta);
    }
    if (data.containsKey('result')) {
      context.handle(
        _resultMeta,
        result.isAcceptableOrUnknown(data['result']!, _resultMeta),
      );
    } else if (isInserting) {
      context.missing(_resultMeta);
    }
    if (data.containsKey('end_reason')) {
      context.handle(
        _endReasonMeta,
        endReason.isAcceptableOrUnknown(data['end_reason']!, _endReasonMeta),
      );
    }
    if (data.containsKey('engine_elo')) {
      context.handle(
        _engineEloMeta,
        engineElo.isAcceptableOrUnknown(data['engine_elo']!, _engineEloMeta),
      );
    }
    if (data.containsKey('opponent_name')) {
      context.handle(
        _opponentNameMeta,
        opponentName.isAcceptableOrUnknown(
          data['opponent_name']!,
          _opponentNameMeta,
        ),
      );
    }
    if (data.containsKey('opponent_rating')) {
      context.handle(
        _opponentRatingMeta,
        opponentRating.isAcceptableOrUnknown(
          data['opponent_rating']!,
          _opponentRatingMeta,
        ),
      );
    }
    if (data.containsKey('player_rating')) {
      context.handle(
        _playerRatingMeta,
        playerRating.isAcceptableOrUnknown(
          data['player_rating']!,
          _playerRatingMeta,
        ),
      );
    }
    if (data.containsKey('time_class')) {
      context.handle(
        _timeClassMeta,
        timeClass.isAcceptableOrUnknown(data['time_class']!, _timeClassMeta),
      );
    }
    if (data.containsKey('time_control')) {
      context.handle(
        _timeControlMeta,
        timeControl.isAcceptableOrUnknown(
          data['time_control']!,
          _timeControlMeta,
        ),
      );
    }
    if (data.containsKey('practice')) {
      context.handle(
        _practiceMeta,
        practice.isAcceptableOrUnknown(data['practice']!, _practiceMeta),
      );
    }
    if (data.containsKey('hints_used')) {
      context.handle(
        _hintsUsedMeta,
        hintsUsed.isAcceptableOrUnknown(data['hints_used']!, _hintsUsedMeta),
      );
    }
    if (data.containsKey('ply_count')) {
      context.handle(
        _plyCountMeta,
        plyCount.isAcceptableOrUnknown(data['ply_count']!, _plyCountMeta),
      );
    } else if (isInserting) {
      context.missing(_plyCountMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GameRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      externalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}external_id'],
      ),
      pgn: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pgn'],
      )!,
      playerSide: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}player_side'],
      )!,
      result: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result'],
      )!,
      endReason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_reason'],
      ),
      engineElo: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}engine_elo'],
      ),
      opponentName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}opponent_name'],
      ),
      opponentRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opponent_rating'],
      ),
      playerRating: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}player_rating'],
      ),
      timeClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_class'],
      ),
      timeControl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}time_control'],
      ),
      practice: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}practice'],
      )!,
      hintsUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}hints_used'],
      )!,
      plyCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ply_count'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      )!,
    );
  }

  @override
  $GamesTable createAlias(String alias) {
    return $GamesTable(attachedDatabase, alias);
  }
}

class GameRow extends DataClass implements Insertable<GameRow> {
  final int id;

  /// A `GameSource` name: `stockfish`, `passAndPlay`, `chesscom` or `lichess`.
  final String source;

  /// The source's own id (e.g. a Chess.com game URL), to avoid duplicates.
  final String? externalId;

  /// The whole game as PGN, headers included.
  final String pgn;

  /// `white` or `black`: the side the user played.
  final String playerSide;

  /// PGN result: `1-0`, `0-1` or `1/2-1/2`.
  final String result;

  /// How the game ended (`checkmate`, `timeout`, …), when known.
  final String? endReason;
  final int? engineElo;

  /// Who the user played, e.g. `Stockfish 1600` or a Chess.com username.
  final String? opponentName;
  final int? opponentRating;
  final int? playerRating;

  /// Chess.com time class: `bullet`, `blitz`, `rapid` or `daily`.
  final String? timeClass;

  /// PGN time control, e.g. `600+0`, or null for no clock.
  final String? timeControl;
  final bool practice;
  final int hintsUsed;
  final int plyCount;
  final DateTime startedAt;
  final DateTime endedAt;
  const GameRow({
    required this.id,
    required this.source,
    this.externalId,
    required this.pgn,
    required this.playerSide,
    required this.result,
    this.endReason,
    this.engineElo,
    this.opponentName,
    this.opponentRating,
    this.playerRating,
    this.timeClass,
    this.timeControl,
    required this.practice,
    required this.hintsUsed,
    required this.plyCount,
    required this.startedAt,
    required this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || externalId != null) {
      map['external_id'] = Variable<String>(externalId);
    }
    map['pgn'] = Variable<String>(pgn);
    map['player_side'] = Variable<String>(playerSide);
    map['result'] = Variable<String>(result);
    if (!nullToAbsent || endReason != null) {
      map['end_reason'] = Variable<String>(endReason);
    }
    if (!nullToAbsent || engineElo != null) {
      map['engine_elo'] = Variable<int>(engineElo);
    }
    if (!nullToAbsent || opponentName != null) {
      map['opponent_name'] = Variable<String>(opponentName);
    }
    if (!nullToAbsent || opponentRating != null) {
      map['opponent_rating'] = Variable<int>(opponentRating);
    }
    if (!nullToAbsent || playerRating != null) {
      map['player_rating'] = Variable<int>(playerRating);
    }
    if (!nullToAbsent || timeClass != null) {
      map['time_class'] = Variable<String>(timeClass);
    }
    if (!nullToAbsent || timeControl != null) {
      map['time_control'] = Variable<String>(timeControl);
    }
    map['practice'] = Variable<bool>(practice);
    map['hints_used'] = Variable<int>(hintsUsed);
    map['ply_count'] = Variable<int>(plyCount);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    return map;
  }

  GamesCompanion toCompanion(bool nullToAbsent) {
    return GamesCompanion(
      id: Value(id),
      source: Value(source),
      externalId: externalId == null && nullToAbsent
          ? const Value.absent()
          : Value(externalId),
      pgn: Value(pgn),
      playerSide: Value(playerSide),
      result: Value(result),
      endReason: endReason == null && nullToAbsent
          ? const Value.absent()
          : Value(endReason),
      engineElo: engineElo == null && nullToAbsent
          ? const Value.absent()
          : Value(engineElo),
      opponentName: opponentName == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentName),
      opponentRating: opponentRating == null && nullToAbsent
          ? const Value.absent()
          : Value(opponentRating),
      playerRating: playerRating == null && nullToAbsent
          ? const Value.absent()
          : Value(playerRating),
      timeClass: timeClass == null && nullToAbsent
          ? const Value.absent()
          : Value(timeClass),
      timeControl: timeControl == null && nullToAbsent
          ? const Value.absent()
          : Value(timeControl),
      practice: Value(practice),
      hintsUsed: Value(hintsUsed),
      plyCount: Value(plyCount),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
    );
  }

  factory GameRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameRow(
      id: serializer.fromJson<int>(json['id']),
      source: serializer.fromJson<String>(json['source']),
      externalId: serializer.fromJson<String?>(json['externalId']),
      pgn: serializer.fromJson<String>(json['pgn']),
      playerSide: serializer.fromJson<String>(json['playerSide']),
      result: serializer.fromJson<String>(json['result']),
      endReason: serializer.fromJson<String?>(json['endReason']),
      engineElo: serializer.fromJson<int?>(json['engineElo']),
      opponentName: serializer.fromJson<String?>(json['opponentName']),
      opponentRating: serializer.fromJson<int?>(json['opponentRating']),
      playerRating: serializer.fromJson<int?>(json['playerRating']),
      timeClass: serializer.fromJson<String?>(json['timeClass']),
      timeControl: serializer.fromJson<String?>(json['timeControl']),
      practice: serializer.fromJson<bool>(json['practice']),
      hintsUsed: serializer.fromJson<int>(json['hintsUsed']),
      plyCount: serializer.fromJson<int>(json['plyCount']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'source': serializer.toJson<String>(source),
      'externalId': serializer.toJson<String?>(externalId),
      'pgn': serializer.toJson<String>(pgn),
      'playerSide': serializer.toJson<String>(playerSide),
      'result': serializer.toJson<String>(result),
      'endReason': serializer.toJson<String?>(endReason),
      'engineElo': serializer.toJson<int?>(engineElo),
      'opponentName': serializer.toJson<String?>(opponentName),
      'opponentRating': serializer.toJson<int?>(opponentRating),
      'playerRating': serializer.toJson<int?>(playerRating),
      'timeClass': serializer.toJson<String?>(timeClass),
      'timeControl': serializer.toJson<String?>(timeControl),
      'practice': serializer.toJson<bool>(practice),
      'hintsUsed': serializer.toJson<int>(hintsUsed),
      'plyCount': serializer.toJson<int>(plyCount),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
    };
  }

  GameRow copyWith({
    int? id,
    String? source,
    Value<String?> externalId = const Value.absent(),
    String? pgn,
    String? playerSide,
    String? result,
    Value<String?> endReason = const Value.absent(),
    Value<int?> engineElo = const Value.absent(),
    Value<String?> opponentName = const Value.absent(),
    Value<int?> opponentRating = const Value.absent(),
    Value<int?> playerRating = const Value.absent(),
    Value<String?> timeClass = const Value.absent(),
    Value<String?> timeControl = const Value.absent(),
    bool? practice,
    int? hintsUsed,
    int? plyCount,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => GameRow(
    id: id ?? this.id,
    source: source ?? this.source,
    externalId: externalId.present ? externalId.value : this.externalId,
    pgn: pgn ?? this.pgn,
    playerSide: playerSide ?? this.playerSide,
    result: result ?? this.result,
    endReason: endReason.present ? endReason.value : this.endReason,
    engineElo: engineElo.present ? engineElo.value : this.engineElo,
    opponentName: opponentName.present ? opponentName.value : this.opponentName,
    opponentRating: opponentRating.present
        ? opponentRating.value
        : this.opponentRating,
    playerRating: playerRating.present ? playerRating.value : this.playerRating,
    timeClass: timeClass.present ? timeClass.value : this.timeClass,
    timeControl: timeControl.present ? timeControl.value : this.timeControl,
    practice: practice ?? this.practice,
    hintsUsed: hintsUsed ?? this.hintsUsed,
    plyCount: plyCount ?? this.plyCount,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );
  GameRow copyWithCompanion(GamesCompanion data) {
    return GameRow(
      id: data.id.present ? data.id.value : this.id,
      source: data.source.present ? data.source.value : this.source,
      externalId: data.externalId.present
          ? data.externalId.value
          : this.externalId,
      pgn: data.pgn.present ? data.pgn.value : this.pgn,
      playerSide: data.playerSide.present
          ? data.playerSide.value
          : this.playerSide,
      result: data.result.present ? data.result.value : this.result,
      endReason: data.endReason.present ? data.endReason.value : this.endReason,
      engineElo: data.engineElo.present ? data.engineElo.value : this.engineElo,
      opponentName: data.opponentName.present
          ? data.opponentName.value
          : this.opponentName,
      opponentRating: data.opponentRating.present
          ? data.opponentRating.value
          : this.opponentRating,
      playerRating: data.playerRating.present
          ? data.playerRating.value
          : this.playerRating,
      timeClass: data.timeClass.present ? data.timeClass.value : this.timeClass,
      timeControl: data.timeControl.present
          ? data.timeControl.value
          : this.timeControl,
      practice: data.practice.present ? data.practice.value : this.practice,
      hintsUsed: data.hintsUsed.present ? data.hintsUsed.value : this.hintsUsed,
      plyCount: data.plyCount.present ? data.plyCount.value : this.plyCount,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameRow(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('pgn: $pgn, ')
          ..write('playerSide: $playerSide, ')
          ..write('result: $result, ')
          ..write('endReason: $endReason, ')
          ..write('engineElo: $engineElo, ')
          ..write('opponentName: $opponentName, ')
          ..write('opponentRating: $opponentRating, ')
          ..write('playerRating: $playerRating, ')
          ..write('timeClass: $timeClass, ')
          ..write('timeControl: $timeControl, ')
          ..write('practice: $practice, ')
          ..write('hintsUsed: $hintsUsed, ')
          ..write('plyCount: $plyCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    source,
    externalId,
    pgn,
    playerSide,
    result,
    endReason,
    engineElo,
    opponentName,
    opponentRating,
    playerRating,
    timeClass,
    timeControl,
    practice,
    hintsUsed,
    plyCount,
    startedAt,
    endedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameRow &&
          other.id == this.id &&
          other.source == this.source &&
          other.externalId == this.externalId &&
          other.pgn == this.pgn &&
          other.playerSide == this.playerSide &&
          other.result == this.result &&
          other.endReason == this.endReason &&
          other.engineElo == this.engineElo &&
          other.opponentName == this.opponentName &&
          other.opponentRating == this.opponentRating &&
          other.playerRating == this.playerRating &&
          other.timeClass == this.timeClass &&
          other.timeControl == this.timeControl &&
          other.practice == this.practice &&
          other.hintsUsed == this.hintsUsed &&
          other.plyCount == this.plyCount &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt);
}

class GamesCompanion extends UpdateCompanion<GameRow> {
  final Value<int> id;
  final Value<String> source;
  final Value<String?> externalId;
  final Value<String> pgn;
  final Value<String> playerSide;
  final Value<String> result;
  final Value<String?> endReason;
  final Value<int?> engineElo;
  final Value<String?> opponentName;
  final Value<int?> opponentRating;
  final Value<int?> playerRating;
  final Value<String?> timeClass;
  final Value<String?> timeControl;
  final Value<bool> practice;
  final Value<int> hintsUsed;
  final Value<int> plyCount;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  const GamesCompanion({
    this.id = const Value.absent(),
    this.source = const Value.absent(),
    this.externalId = const Value.absent(),
    this.pgn = const Value.absent(),
    this.playerSide = const Value.absent(),
    this.result = const Value.absent(),
    this.endReason = const Value.absent(),
    this.engineElo = const Value.absent(),
    this.opponentName = const Value.absent(),
    this.opponentRating = const Value.absent(),
    this.playerRating = const Value.absent(),
    this.timeClass = const Value.absent(),
    this.timeControl = const Value.absent(),
    this.practice = const Value.absent(),
    this.hintsUsed = const Value.absent(),
    this.plyCount = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
  });
  GamesCompanion.insert({
    this.id = const Value.absent(),
    required String source,
    this.externalId = const Value.absent(),
    required String pgn,
    required String playerSide,
    required String result,
    this.endReason = const Value.absent(),
    this.engineElo = const Value.absent(),
    this.opponentName = const Value.absent(),
    this.opponentRating = const Value.absent(),
    this.playerRating = const Value.absent(),
    this.timeClass = const Value.absent(),
    this.timeControl = const Value.absent(),
    this.practice = const Value.absent(),
    this.hintsUsed = const Value.absent(),
    required int plyCount,
    required DateTime startedAt,
    required DateTime endedAt,
  }) : source = Value(source),
       pgn = Value(pgn),
       playerSide = Value(playerSide),
       result = Value(result),
       plyCount = Value(plyCount),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt);
  static Insertable<GameRow> custom({
    Expression<int>? id,
    Expression<String>? source,
    Expression<String>? externalId,
    Expression<String>? pgn,
    Expression<String>? playerSide,
    Expression<String>? result,
    Expression<String>? endReason,
    Expression<int>? engineElo,
    Expression<String>? opponentName,
    Expression<int>? opponentRating,
    Expression<int>? playerRating,
    Expression<String>? timeClass,
    Expression<String>? timeControl,
    Expression<bool>? practice,
    Expression<int>? hintsUsed,
    Expression<int>? plyCount,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (source != null) 'source': source,
      if (externalId != null) 'external_id': externalId,
      if (pgn != null) 'pgn': pgn,
      if (playerSide != null) 'player_side': playerSide,
      if (result != null) 'result': result,
      if (endReason != null) 'end_reason': endReason,
      if (engineElo != null) 'engine_elo': engineElo,
      if (opponentName != null) 'opponent_name': opponentName,
      if (opponentRating != null) 'opponent_rating': opponentRating,
      if (playerRating != null) 'player_rating': playerRating,
      if (timeClass != null) 'time_class': timeClass,
      if (timeControl != null) 'time_control': timeControl,
      if (practice != null) 'practice': practice,
      if (hintsUsed != null) 'hints_used': hintsUsed,
      if (plyCount != null) 'ply_count': plyCount,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
    });
  }

  GamesCompanion copyWith({
    Value<int>? id,
    Value<String>? source,
    Value<String?>? externalId,
    Value<String>? pgn,
    Value<String>? playerSide,
    Value<String>? result,
    Value<String?>? endReason,
    Value<int?>? engineElo,
    Value<String?>? opponentName,
    Value<int?>? opponentRating,
    Value<int?>? playerRating,
    Value<String?>? timeClass,
    Value<String?>? timeControl,
    Value<bool>? practice,
    Value<int>? hintsUsed,
    Value<int>? plyCount,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
  }) {
    return GamesCompanion(
      id: id ?? this.id,
      source: source ?? this.source,
      externalId: externalId ?? this.externalId,
      pgn: pgn ?? this.pgn,
      playerSide: playerSide ?? this.playerSide,
      result: result ?? this.result,
      endReason: endReason ?? this.endReason,
      engineElo: engineElo ?? this.engineElo,
      opponentName: opponentName ?? this.opponentName,
      opponentRating: opponentRating ?? this.opponentRating,
      playerRating: playerRating ?? this.playerRating,
      timeClass: timeClass ?? this.timeClass,
      timeControl: timeControl ?? this.timeControl,
      practice: practice ?? this.practice,
      hintsUsed: hintsUsed ?? this.hintsUsed,
      plyCount: plyCount ?? this.plyCount,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (externalId.present) {
      map['external_id'] = Variable<String>(externalId.value);
    }
    if (pgn.present) {
      map['pgn'] = Variable<String>(pgn.value);
    }
    if (playerSide.present) {
      map['player_side'] = Variable<String>(playerSide.value);
    }
    if (result.present) {
      map['result'] = Variable<String>(result.value);
    }
    if (endReason.present) {
      map['end_reason'] = Variable<String>(endReason.value);
    }
    if (engineElo.present) {
      map['engine_elo'] = Variable<int>(engineElo.value);
    }
    if (opponentName.present) {
      map['opponent_name'] = Variable<String>(opponentName.value);
    }
    if (opponentRating.present) {
      map['opponent_rating'] = Variable<int>(opponentRating.value);
    }
    if (playerRating.present) {
      map['player_rating'] = Variable<int>(playerRating.value);
    }
    if (timeClass.present) {
      map['time_class'] = Variable<String>(timeClass.value);
    }
    if (timeControl.present) {
      map['time_control'] = Variable<String>(timeControl.value);
    }
    if (practice.present) {
      map['practice'] = Variable<bool>(practice.value);
    }
    if (hintsUsed.present) {
      map['hints_used'] = Variable<int>(hintsUsed.value);
    }
    if (plyCount.present) {
      map['ply_count'] = Variable<int>(plyCount.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GamesCompanion(')
          ..write('id: $id, ')
          ..write('source: $source, ')
          ..write('externalId: $externalId, ')
          ..write('pgn: $pgn, ')
          ..write('playerSide: $playerSide, ')
          ..write('result: $result, ')
          ..write('endReason: $endReason, ')
          ..write('engineElo: $engineElo, ')
          ..write('opponentName: $opponentName, ')
          ..write('opponentRating: $opponentRating, ')
          ..write('playerRating: $playerRating, ')
          ..write('timeClass: $timeClass, ')
          ..write('timeControl: $timeControl, ')
          ..write('practice: $practice, ')
          ..write('hintsUsed: $hintsUsed, ')
          ..write('plyCount: $plyCount, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportMonthsTable extends ImportMonths
    with TableInfo<$ImportMonthsTable, ImportMonthRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportMonthsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _usernameMeta = const VerificationMeta(
    'username',
  );
  @override
  late final GeneratedColumn<String> username = GeneratedColumn<String>(
    'username',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completeMeta = const VerificationMeta(
    'complete',
  );
  @override
  late final GeneratedColumn<bool> complete = GeneratedColumn<bool>(
    'complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("complete" IN (0, 1))',
    ),
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gameCountMeta = const VerificationMeta(
    'gameCount',
  );
  @override
  late final GeneratedColumn<int> gameCount = GeneratedColumn<int>(
    'game_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    username,
    month,
    complete,
    etag,
    gameCount,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_months';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportMonthRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('username')) {
      context.handle(
        _usernameMeta,
        username.isAcceptableOrUnknown(data['username']!, _usernameMeta),
      );
    } else if (isInserting) {
      context.missing(_usernameMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('complete')) {
      context.handle(
        _completeMeta,
        complete.isAcceptableOrUnknown(data['complete']!, _completeMeta),
      );
    } else if (isInserting) {
      context.missing(_completeMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('game_count')) {
      context.handle(
        _gameCountMeta,
        gameCount.isAcceptableOrUnknown(data['game_count']!, _gameCountMeta),
      );
    } else if (isInserting) {
      context.missing(_gameCountMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {username, month};
  @override
  ImportMonthRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportMonthRow(
      username: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}username'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      complete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}complete'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      gameCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_count'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $ImportMonthsTable createAlias(String alias) {
    return $ImportMonthsTable(attachedDatabase, alias);
  }
}

class ImportMonthRow extends DataClass implements Insertable<ImportMonthRow> {
  /// Lower-case Chess.com username.
  final String username;

  /// `YYYY/MM`, as in the archive URL.
  final String month;

  /// True once a month that can no longer change has been fully imported.
  final bool complete;

  /// Chess.com's ETag for the month, to ask "has anything changed?".
  final String? etag;
  final int gameCount;
  final DateTime fetchedAt;
  const ImportMonthRow({
    required this.username,
    required this.month,
    required this.complete,
    this.etag,
    required this.gameCount,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['username'] = Variable<String>(username);
    map['month'] = Variable<String>(month);
    map['complete'] = Variable<bool>(complete);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['game_count'] = Variable<int>(gameCount);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  ImportMonthsCompanion toCompanion(bool nullToAbsent) {
    return ImportMonthsCompanion(
      username: Value(username),
      month: Value(month),
      complete: Value(complete),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      gameCount: Value(gameCount),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory ImportMonthRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportMonthRow(
      username: serializer.fromJson<String>(json['username']),
      month: serializer.fromJson<String>(json['month']),
      complete: serializer.fromJson<bool>(json['complete']),
      etag: serializer.fromJson<String?>(json['etag']),
      gameCount: serializer.fromJson<int>(json['gameCount']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'username': serializer.toJson<String>(username),
      'month': serializer.toJson<String>(month),
      'complete': serializer.toJson<bool>(complete),
      'etag': serializer.toJson<String?>(etag),
      'gameCount': serializer.toJson<int>(gameCount),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  ImportMonthRow copyWith({
    String? username,
    String? month,
    bool? complete,
    Value<String?> etag = const Value.absent(),
    int? gameCount,
    DateTime? fetchedAt,
  }) => ImportMonthRow(
    username: username ?? this.username,
    month: month ?? this.month,
    complete: complete ?? this.complete,
    etag: etag.present ? etag.value : this.etag,
    gameCount: gameCount ?? this.gameCount,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  ImportMonthRow copyWithCompanion(ImportMonthsCompanion data) {
    return ImportMonthRow(
      username: data.username.present ? data.username.value : this.username,
      month: data.month.present ? data.month.value : this.month,
      complete: data.complete.present ? data.complete.value : this.complete,
      etag: data.etag.present ? data.etag.value : this.etag,
      gameCount: data.gameCount.present ? data.gameCount.value : this.gameCount,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportMonthRow(')
          ..write('username: $username, ')
          ..write('month: $month, ')
          ..write('complete: $complete, ')
          ..write('etag: $etag, ')
          ..write('gameCount: $gameCount, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(username, month, complete, etag, gameCount, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportMonthRow &&
          other.username == this.username &&
          other.month == this.month &&
          other.complete == this.complete &&
          other.etag == this.etag &&
          other.gameCount == this.gameCount &&
          other.fetchedAt == this.fetchedAt);
}

class ImportMonthsCompanion extends UpdateCompanion<ImportMonthRow> {
  final Value<String> username;
  final Value<String> month;
  final Value<bool> complete;
  final Value<String?> etag;
  final Value<int> gameCount;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const ImportMonthsCompanion({
    this.username = const Value.absent(),
    this.month = const Value.absent(),
    this.complete = const Value.absent(),
    this.etag = const Value.absent(),
    this.gameCount = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportMonthsCompanion.insert({
    required String username,
    required String month,
    required bool complete,
    this.etag = const Value.absent(),
    required int gameCount,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : username = Value(username),
       month = Value(month),
       complete = Value(complete),
       gameCount = Value(gameCount),
       fetchedAt = Value(fetchedAt);
  static Insertable<ImportMonthRow> custom({
    Expression<String>? username,
    Expression<String>? month,
    Expression<bool>? complete,
    Expression<String>? etag,
    Expression<int>? gameCount,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (username != null) 'username': username,
      if (month != null) 'month': month,
      if (complete != null) 'complete': complete,
      if (etag != null) 'etag': etag,
      if (gameCount != null) 'game_count': gameCount,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportMonthsCompanion copyWith({
    Value<String>? username,
    Value<String>? month,
    Value<bool>? complete,
    Value<String?>? etag,
    Value<int>? gameCount,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return ImportMonthsCompanion(
      username: username ?? this.username,
      month: month ?? this.month,
      complete: complete ?? this.complete,
      etag: etag ?? this.etag,
      gameCount: gameCount ?? this.gameCount,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (username.present) {
      map['username'] = Variable<String>(username.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (complete.present) {
      map['complete'] = Variable<bool>(complete.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (gameCount.present) {
      map['game_count'] = Variable<int>(gameCount.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportMonthsCompanion(')
          ..write('username: $username, ')
          ..write('month: $month, ')
          ..write('complete: $complete, ')
          ..write('etag: $etag, ')
          ..write('gameCount: $gameCount, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GameAnalysesTable extends GameAnalyses
    with TableInfo<$GameAnalysesTable, GameAnalysisRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameAnalysesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _depthMeta = const VerificationMeta('depth');
  @override
  late final GeneratedColumn<int> depth = GeneratedColumn<int>(
    'depth',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evalsMeta = const VerificationMeta('evals');
  @override
  late final GeneratedColumn<String> evals = GeneratedColumn<String>(
    'evals',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completeMeta = const VerificationMeta(
    'complete',
  );
  @override
  late final GeneratedColumn<bool> complete = GeneratedColumn<bool>(
    'complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("complete" IN (0, 1))',
    ),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    gameId,
    depth,
    evals,
    complete,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_analyses';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameAnalysisRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('depth')) {
      context.handle(
        _depthMeta,
        depth.isAcceptableOrUnknown(data['depth']!, _depthMeta),
      );
    } else if (isInserting) {
      context.missing(_depthMeta);
    }
    if (data.containsKey('evals')) {
      context.handle(
        _evalsMeta,
        evals.isAcceptableOrUnknown(data['evals']!, _evalsMeta),
      );
    } else if (isInserting) {
      context.missing(_evalsMeta);
    }
    if (data.containsKey('complete')) {
      context.handle(
        _completeMeta,
        complete.isAcceptableOrUnknown(data['complete']!, _completeMeta),
      );
    } else if (isInserting) {
      context.missing(_completeMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId};
  @override
  GameAnalysisRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameAnalysisRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      depth: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}depth'],
      )!,
      evals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evals'],
      )!,
      complete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}complete'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GameAnalysesTable createAlias(String alias) {
    return $GameAnalysesTable(attachedDatabase, alias);
  }
}

class GameAnalysisRow extends DataClass implements Insertable<GameAnalysisRow> {
  final int gameId;
  final int depth;

  /// JSON list, one entry per position analysed so far, start position first.
  final String evals;

  /// Every position has been analysed.
  final bool complete;
  final DateTime updatedAt;
  const GameAnalysisRow({
    required this.gameId,
    required this.depth,
    required this.evals,
    required this.complete,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<int>(gameId);
    map['depth'] = Variable<int>(depth);
    map['evals'] = Variable<String>(evals);
    map['complete'] = Variable<bool>(complete);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GameAnalysesCompanion toCompanion(bool nullToAbsent) {
    return GameAnalysesCompanion(
      gameId: Value(gameId),
      depth: Value(depth),
      evals: Value(evals),
      complete: Value(complete),
      updatedAt: Value(updatedAt),
    );
  }

  factory GameAnalysisRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameAnalysisRow(
      gameId: serializer.fromJson<int>(json['gameId']),
      depth: serializer.fromJson<int>(json['depth']),
      evals: serializer.fromJson<String>(json['evals']),
      complete: serializer.fromJson<bool>(json['complete']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<int>(gameId),
      'depth': serializer.toJson<int>(depth),
      'evals': serializer.toJson<String>(evals),
      'complete': serializer.toJson<bool>(complete),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GameAnalysisRow copyWith({
    int? gameId,
    int? depth,
    String? evals,
    bool? complete,
    DateTime? updatedAt,
  }) => GameAnalysisRow(
    gameId: gameId ?? this.gameId,
    depth: depth ?? this.depth,
    evals: evals ?? this.evals,
    complete: complete ?? this.complete,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GameAnalysisRow copyWithCompanion(GameAnalysesCompanion data) {
    return GameAnalysisRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      depth: data.depth.present ? data.depth.value : this.depth,
      evals: data.evals.present ? data.evals.value : this.evals,
      complete: data.complete.present ? data.complete.value : this.complete,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameAnalysisRow(')
          ..write('gameId: $gameId, ')
          ..write('depth: $depth, ')
          ..write('evals: $evals, ')
          ..write('complete: $complete, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gameId, depth, evals, complete, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameAnalysisRow &&
          other.gameId == this.gameId &&
          other.depth == this.depth &&
          other.evals == this.evals &&
          other.complete == this.complete &&
          other.updatedAt == this.updatedAt);
}

class GameAnalysesCompanion extends UpdateCompanion<GameAnalysisRow> {
  final Value<int> gameId;
  final Value<int> depth;
  final Value<String> evals;
  final Value<bool> complete;
  final Value<DateTime> updatedAt;
  const GameAnalysesCompanion({
    this.gameId = const Value.absent(),
    this.depth = const Value.absent(),
    this.evals = const Value.absent(),
    this.complete = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  GameAnalysesCompanion.insert({
    this.gameId = const Value.absent(),
    required int depth,
    required String evals,
    required bool complete,
    required DateTime updatedAt,
  }) : depth = Value(depth),
       evals = Value(evals),
       complete = Value(complete),
       updatedAt = Value(updatedAt);
  static Insertable<GameAnalysisRow> custom({
    Expression<int>? gameId,
    Expression<int>? depth,
    Expression<String>? evals,
    Expression<bool>? complete,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (depth != null) 'depth': depth,
      if (evals != null) 'evals': evals,
      if (complete != null) 'complete': complete,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  GameAnalysesCompanion copyWith({
    Value<int>? gameId,
    Value<int>? depth,
    Value<String>? evals,
    Value<bool>? complete,
    Value<DateTime>? updatedAt,
  }) {
    return GameAnalysesCompanion(
      gameId: gameId ?? this.gameId,
      depth: depth ?? this.depth,
      evals: evals ?? this.evals,
      complete: complete ?? this.complete,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (depth.present) {
      map['depth'] = Variable<int>(depth.value);
    }
    if (evals.present) {
      map['evals'] = Variable<String>(evals.value);
    }
    if (complete.present) {
      map['complete'] = Variable<bool>(complete.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameAnalysesCompanion(')
          ..write('gameId: $gameId, ')
          ..write('depth: $depth, ')
          ..write('evals: $evals, ')
          ..write('complete: $complete, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $GameReviewsTable extends GameReviews
    with TableInfo<$GameReviewsTable, GameReviewRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GameReviewsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES games (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [gameId, model, json, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'game_reviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<GameReviewRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {gameId};
  @override
  GameReviewRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GameReviewRow(
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GameReviewsTable createAlias(String alias) {
    return $GameReviewsTable(attachedDatabase, alias);
  }
}

class GameReviewRow extends DataClass implements Insertable<GameReviewRow> {
  final int gameId;

  /// The model that wrote it, e.g. `gemini-3.8-flash`.
  final String model;

  /// The model's JSON reply, after the move check.
  final String json;
  final DateTime createdAt;
  const GameReviewRow({
    required this.gameId,
    required this.model,
    required this.json,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['game_id'] = Variable<int>(gameId);
    map['model'] = Variable<String>(model);
    map['json'] = Variable<String>(json);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GameReviewsCompanion toCompanion(bool nullToAbsent) {
    return GameReviewsCompanion(
      gameId: Value(gameId),
      model: Value(model),
      json: Value(json),
      createdAt: Value(createdAt),
    );
  }

  factory GameReviewRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GameReviewRow(
      gameId: serializer.fromJson<int>(json['gameId']),
      model: serializer.fromJson<String>(json['model']),
      json: serializer.fromJson<String>(json['json']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'gameId': serializer.toJson<int>(gameId),
      'model': serializer.toJson<String>(model),
      'json': serializer.toJson<String>(json),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GameReviewRow copyWith({
    int? gameId,
    String? model,
    String? json,
    DateTime? createdAt,
  }) => GameReviewRow(
    gameId: gameId ?? this.gameId,
    model: model ?? this.model,
    json: json ?? this.json,
    createdAt: createdAt ?? this.createdAt,
  );
  GameReviewRow copyWithCompanion(GameReviewsCompanion data) {
    return GameReviewRow(
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      model: data.model.present ? data.model.value : this.model,
      json: data.json.present ? data.json.value : this.json,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GameReviewRow(')
          ..write('gameId: $gameId, ')
          ..write('model: $model, ')
          ..write('json: $json, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(gameId, model, json, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GameReviewRow &&
          other.gameId == this.gameId &&
          other.model == this.model &&
          other.json == this.json &&
          other.createdAt == this.createdAt);
}

class GameReviewsCompanion extends UpdateCompanion<GameReviewRow> {
  final Value<int> gameId;
  final Value<String> model;
  final Value<String> json;
  final Value<DateTime> createdAt;
  const GameReviewsCompanion({
    this.gameId = const Value.absent(),
    this.model = const Value.absent(),
    this.json = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  GameReviewsCompanion.insert({
    this.gameId = const Value.absent(),
    required String model,
    required String json,
    required DateTime createdAt,
  }) : model = Value(model),
       json = Value(json),
       createdAt = Value(createdAt);
  static Insertable<GameReviewRow> custom({
    Expression<int>? gameId,
    Expression<String>? model,
    Expression<String>? json,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (gameId != null) 'game_id': gameId,
      if (model != null) 'model': model,
      if (json != null) 'json': json,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  GameReviewsCompanion copyWith({
    Value<int>? gameId,
    Value<String>? model,
    Value<String>? json,
    Value<DateTime>? createdAt,
  }) {
    return GameReviewsCompanion(
      gameId: gameId ?? this.gameId,
      model: model ?? this.model,
      json: json ?? this.json,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GameReviewsCompanion(')
          ..write('gameId: $gameId, ')
          ..write('model: $model, ')
          ..write('json: $json, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $CoachChatsTable extends CoachChats
    with TableInfo<$CoachChatsTable, CoachChatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoachChatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  @override
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _gameIdMeta = const VerificationMeta('gameId');
  @override
  late final GeneratedColumn<int> gameId = GeneratedColumn<int>(
    'game_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _scopeLabelMeta = const VerificationMeta(
    'scopeLabel',
  );
  @override
  late final GeneratedColumn<String> scopeLabel = GeneratedColumn<String>(
    'scope_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _thumbFenMeta = const VerificationMeta(
    'thumbFen',
  );
  @override
  late final GeneratedColumn<String> thumbFen = GeneratedColumn<String>(
    'thumb_fen',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<String> verified = GeneratedColumn<String>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    createdAt,
    updatedAt,
    messageCount,
    gameId,
    scopeLabel,
    thumbFen,
    verified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coach_chats';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoachChatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    if (data.containsKey('game_id')) {
      context.handle(
        _gameIdMeta,
        gameId.isAcceptableOrUnknown(data['game_id']!, _gameIdMeta),
      );
    }
    if (data.containsKey('scope_label')) {
      context.handle(
        _scopeLabelMeta,
        scopeLabel.isAcceptableOrUnknown(data['scope_label']!, _scopeLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeLabelMeta);
    }
    if (data.containsKey('thumb_fen')) {
      context.handle(
        _thumbFenMeta,
        thumbFen.isAcceptableOrUnknown(data['thumb_fen']!, _thumbFenMeta),
      );
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoachChatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoachChatRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
      gameId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}game_id'],
      ),
      scopeLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope_label'],
      )!,
      thumbFen: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thumb_fen'],
      ),
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verified'],
      )!,
    );
  }

  @override
  $CoachChatsTable createAlias(String alias) {
    return $CoachChatsTable(attachedDatabase, alias);
  }
}

class CoachChatRow extends DataClass implements Insertable<CoachChatRow> {
  final int id;

  /// The first question, until renamed.
  final String title;
  final DateTime createdAt;

  /// Last activity: the list is sorted and grouped by it.
  final DateTime updatedAt;
  final int messageCount;

  /// The game the chat is about, or null for questions across many games.
  final int? gameId;

  /// What it's about, as shown: `vs Stockfish 1000 · 28 Sep`.
  final String scopeLabel;

  /// The position for the list thumbnail, when there's a game.
  final String? thumbFen;

  /// JSON: what the move check may accept in later answers (moves the tools
  /// reported, and the move cards they described).
  final String verified;
  const CoachChatRow({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messageCount,
    this.gameId,
    required this.scopeLabel,
    this.thumbFen,
    required this.verified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['message_count'] = Variable<int>(messageCount);
    if (!nullToAbsent || gameId != null) {
      map['game_id'] = Variable<int>(gameId);
    }
    map['scope_label'] = Variable<String>(scopeLabel);
    if (!nullToAbsent || thumbFen != null) {
      map['thumb_fen'] = Variable<String>(thumbFen);
    }
    map['verified'] = Variable<String>(verified);
    return map;
  }

  CoachChatsCompanion toCompanion(bool nullToAbsent) {
    return CoachChatsCompanion(
      id: Value(id),
      title: Value(title),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      messageCount: Value(messageCount),
      gameId: gameId == null && nullToAbsent
          ? const Value.absent()
          : Value(gameId),
      scopeLabel: Value(scopeLabel),
      thumbFen: thumbFen == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbFen),
      verified: Value(verified),
    );
  }

  factory CoachChatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoachChatRow(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
      gameId: serializer.fromJson<int?>(json['gameId']),
      scopeLabel: serializer.fromJson<String>(json['scopeLabel']),
      thumbFen: serializer.fromJson<String?>(json['thumbFen']),
      verified: serializer.fromJson<String>(json['verified']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'messageCount': serializer.toJson<int>(messageCount),
      'gameId': serializer.toJson<int?>(gameId),
      'scopeLabel': serializer.toJson<String>(scopeLabel),
      'thumbFen': serializer.toJson<String?>(thumbFen),
      'verified': serializer.toJson<String>(verified),
    };
  }

  CoachChatRow copyWith({
    int? id,
    String? title,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? messageCount,
    Value<int?> gameId = const Value.absent(),
    String? scopeLabel,
    Value<String?> thumbFen = const Value.absent(),
    String? verified,
  }) => CoachChatRow(
    id: id ?? this.id,
    title: title ?? this.title,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messageCount: messageCount ?? this.messageCount,
    gameId: gameId.present ? gameId.value : this.gameId,
    scopeLabel: scopeLabel ?? this.scopeLabel,
    thumbFen: thumbFen.present ? thumbFen.value : this.thumbFen,
    verified: verified ?? this.verified,
  );
  CoachChatRow copyWithCompanion(CoachChatsCompanion data) {
    return CoachChatRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
      gameId: data.gameId.present ? data.gameId.value : this.gameId,
      scopeLabel: data.scopeLabel.present
          ? data.scopeLabel.value
          : this.scopeLabel,
      thumbFen: data.thumbFen.present ? data.thumbFen.value : this.thumbFen,
      verified: data.verified.present ? data.verified.value : this.verified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoachChatRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageCount: $messageCount, ')
          ..write('gameId: $gameId, ')
          ..write('scopeLabel: $scopeLabel, ')
          ..write('thumbFen: $thumbFen, ')
          ..write('verified: $verified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    createdAt,
    updatedAt,
    messageCount,
    gameId,
    scopeLabel,
    thumbFen,
    verified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachChatRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.messageCount == this.messageCount &&
          other.gameId == this.gameId &&
          other.scopeLabel == this.scopeLabel &&
          other.thumbFen == this.thumbFen &&
          other.verified == this.verified);
}

class CoachChatsCompanion extends UpdateCompanion<CoachChatRow> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> messageCount;
  final Value<int?> gameId;
  final Value<String> scopeLabel;
  final Value<String?> thumbFen;
  final Value<String> verified;
  const CoachChatsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.gameId = const Value.absent(),
    this.scopeLabel = const Value.absent(),
    this.thumbFen = const Value.absent(),
    this.verified = const Value.absent(),
  });
  CoachChatsCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.messageCount = const Value.absent(),
    this.gameId = const Value.absent(),
    required String scopeLabel,
    this.thumbFen = const Value.absent(),
    this.verified = const Value.absent(),
  }) : title = Value(title),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt),
       scopeLabel = Value(scopeLabel);
  static Insertable<CoachChatRow> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? messageCount,
    Expression<int>? gameId,
    Expression<String>? scopeLabel,
    Expression<String>? thumbFen,
    Expression<String>? verified,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (messageCount != null) 'message_count': messageCount,
      if (gameId != null) 'game_id': gameId,
      if (scopeLabel != null) 'scope_label': scopeLabel,
      if (thumbFen != null) 'thumb_fen': thumbFen,
      if (verified != null) 'verified': verified,
    });
  }

  CoachChatsCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? messageCount,
    Value<int?>? gameId,
    Value<String>? scopeLabel,
    Value<String?>? thumbFen,
    Value<String>? verified,
  }) {
    return CoachChatsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messageCount: messageCount ?? this.messageCount,
      gameId: gameId ?? this.gameId,
      scopeLabel: scopeLabel ?? this.scopeLabel,
      thumbFen: thumbFen ?? this.thumbFen,
      verified: verified ?? this.verified,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (gameId.present) {
      map['game_id'] = Variable<int>(gameId.value);
    }
    if (scopeLabel.present) {
      map['scope_label'] = Variable<String>(scopeLabel.value);
    }
    if (thumbFen.present) {
      map['thumb_fen'] = Variable<String>(thumbFen.value);
    }
    if (verified.present) {
      map['verified'] = Variable<String>(verified.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoachChatsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('messageCount: $messageCount, ')
          ..write('gameId: $gameId, ')
          ..write('scopeLabel: $scopeLabel, ')
          ..write('thumbFen: $thumbFen, ')
          ..write('verified: $verified')
          ..write(')'))
        .toString();
  }
}

class $CoachMessagesTable extends CoachMessages
    with TableInfo<$CoachMessagesTable, CoachMessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoachMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _chatIdMeta = const VerificationMeta('chatId');
  @override
  late final GeneratedColumn<int> chatId = GeneratedColumn<int>(
    'chat_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES coach_chats (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _atMeta = const VerificationMeta('at');
  @override
  late final GeneratedColumn<DateTime> at = GeneratedColumn<DateTime>(
    'at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, chatId, role, at, body, payload];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'coach_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoachMessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('chat_id')) {
      context.handle(
        _chatIdMeta,
        chatId.isAcceptableOrUnknown(data['chat_id']!, _chatIdMeta),
      );
    } else if (isInserting) {
      context.missing(_chatIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('at')) {
      context.handle(_atMeta, at.isAcceptableOrUnknown(data['at']!, _atMeta));
    } else if (isInserting) {
      context.missing(_atMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoachMessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoachMessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      chatId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}chat_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      at: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}at'],
      )!,
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
    );
  }

  @override
  $CoachMessagesTable createAlias(String alias) {
    return $CoachMessagesTable(attachedDatabase, alias);
  }
}

class CoachMessageRow extends DataClass implements Insertable<CoachMessageRow> {
  final int id;
  final int chatId;

  /// `user` or `coach`.
  final String role;
  final DateTime at;

  /// The question, or the answer as plain text: searched and previewed.
  final String body;

  /// JSON with the rest: the attached game or move for a question; the
  /// headline, steps and move card for an answer.
  final String payload;
  const CoachMessageRow({
    required this.id,
    required this.chatId,
    required this.role,
    required this.at,
    required this.body,
    required this.payload,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['chat_id'] = Variable<int>(chatId);
    map['role'] = Variable<String>(role);
    map['at'] = Variable<DateTime>(at);
    map['body'] = Variable<String>(body);
    map['payload'] = Variable<String>(payload);
    return map;
  }

  CoachMessagesCompanion toCompanion(bool nullToAbsent) {
    return CoachMessagesCompanion(
      id: Value(id),
      chatId: Value(chatId),
      role: Value(role),
      at: Value(at),
      body: Value(body),
      payload: Value(payload),
    );
  }

  factory CoachMessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoachMessageRow(
      id: serializer.fromJson<int>(json['id']),
      chatId: serializer.fromJson<int>(json['chatId']),
      role: serializer.fromJson<String>(json['role']),
      at: serializer.fromJson<DateTime>(json['at']),
      body: serializer.fromJson<String>(json['body']),
      payload: serializer.fromJson<String>(json['payload']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'chatId': serializer.toJson<int>(chatId),
      'role': serializer.toJson<String>(role),
      'at': serializer.toJson<DateTime>(at),
      'body': serializer.toJson<String>(body),
      'payload': serializer.toJson<String>(payload),
    };
  }

  CoachMessageRow copyWith({
    int? id,
    int? chatId,
    String? role,
    DateTime? at,
    String? body,
    String? payload,
  }) => CoachMessageRow(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    role: role ?? this.role,
    at: at ?? this.at,
    body: body ?? this.body,
    payload: payload ?? this.payload,
  );
  CoachMessageRow copyWithCompanion(CoachMessagesCompanion data) {
    return CoachMessageRow(
      id: data.id.present ? data.id.value : this.id,
      chatId: data.chatId.present ? data.chatId.value : this.chatId,
      role: data.role.present ? data.role.value : this.role,
      at: data.at.present ? data.at.value : this.at,
      body: data.body.present ? data.body.value : this.body,
      payload: data.payload.present ? data.payload.value : this.payload,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoachMessageRow(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('role: $role, ')
          ..write('at: $at, ')
          ..write('body: $body, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, chatId, role, at, body, payload);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoachMessageRow &&
          other.id == this.id &&
          other.chatId == this.chatId &&
          other.role == this.role &&
          other.at == this.at &&
          other.body == this.body &&
          other.payload == this.payload);
}

class CoachMessagesCompanion extends UpdateCompanion<CoachMessageRow> {
  final Value<int> id;
  final Value<int> chatId;
  final Value<String> role;
  final Value<DateTime> at;
  final Value<String> body;
  final Value<String> payload;
  const CoachMessagesCompanion({
    this.id = const Value.absent(),
    this.chatId = const Value.absent(),
    this.role = const Value.absent(),
    this.at = const Value.absent(),
    this.body = const Value.absent(),
    this.payload = const Value.absent(),
  });
  CoachMessagesCompanion.insert({
    this.id = const Value.absent(),
    required int chatId,
    required String role,
    required DateTime at,
    required String body,
    this.payload = const Value.absent(),
  }) : chatId = Value(chatId),
       role = Value(role),
       at = Value(at),
       body = Value(body);
  static Insertable<CoachMessageRow> custom({
    Expression<int>? id,
    Expression<int>? chatId,
    Expression<String>? role,
    Expression<DateTime>? at,
    Expression<String>? body,
    Expression<String>? payload,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (chatId != null) 'chat_id': chatId,
      if (role != null) 'role': role,
      if (at != null) 'at': at,
      if (body != null) 'body': body,
      if (payload != null) 'payload': payload,
    });
  }

  CoachMessagesCompanion copyWith({
    Value<int>? id,
    Value<int>? chatId,
    Value<String>? role,
    Value<DateTime>? at,
    Value<String>? body,
    Value<String>? payload,
  }) {
    return CoachMessagesCompanion(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      at: at ?? this.at,
      body: body ?? this.body,
      payload: payload ?? this.payload,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (chatId.present) {
      map['chat_id'] = Variable<int>(chatId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (at.present) {
      map['at'] = Variable<DateTime>(at.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoachMessagesCompanion(')
          ..write('id: $id, ')
          ..write('chatId: $chatId, ')
          ..write('role: $role, ')
          ..write('at: $at, ')
          ..write('body: $body, ')
          ..write('payload: $payload')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GamesTable games = $GamesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $ImportMonthsTable importMonths = $ImportMonthsTable(this);
  late final $GameAnalysesTable gameAnalyses = $GameAnalysesTable(this);
  late final $GameReviewsTable gameReviews = $GameReviewsTable(this);
  late final $CoachChatsTable coachChats = $CoachChatsTable(this);
  late final $CoachMessagesTable coachMessages = $CoachMessagesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    games,
    settings,
    importMonths,
    gameAnalyses,
    gameReviews,
    coachChats,
    coachMessages,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'games',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('game_analyses', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'games',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('game_reviews', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'coach_chats',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('coach_messages', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$GamesTableCreateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      required String source,
      Value<String?> externalId,
      required String pgn,
      required String playerSide,
      required String result,
      Value<String?> endReason,
      Value<int?> engineElo,
      Value<String?> opponentName,
      Value<int?> opponentRating,
      Value<int?> playerRating,
      Value<String?> timeClass,
      Value<String?> timeControl,
      Value<bool> practice,
      Value<int> hintsUsed,
      required int plyCount,
      required DateTime startedAt,
      required DateTime endedAt,
    });
typedef $$GamesTableUpdateCompanionBuilder =
    GamesCompanion Function({
      Value<int> id,
      Value<String> source,
      Value<String?> externalId,
      Value<String> pgn,
      Value<String> playerSide,
      Value<String> result,
      Value<String?> endReason,
      Value<int?> engineElo,
      Value<String?> opponentName,
      Value<int?> opponentRating,
      Value<int?> playerRating,
      Value<String?> timeClass,
      Value<String?> timeControl,
      Value<bool> practice,
      Value<int> hintsUsed,
      Value<int> plyCount,
      Value<DateTime> startedAt,
      Value<DateTime> endedAt,
    });

final class $$GamesTableReferences
    extends BaseReferences<_$AppDatabase, $GamesTable, GameRow> {
  $$GamesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GameAnalysesTable, List<GameAnalysisRow>>
  _gameAnalysesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gameAnalyses,
    aliasName: 'games__id__game_analyses__game_id',
  );

  $$GameAnalysesTableProcessedTableManager get gameAnalysesRefs {
    final manager = $$GameAnalysesTableTableManager(
      $_db,
      $_db.gameAnalyses,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gameAnalysesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GameReviewsTable, List<GameReviewRow>>
  _gameReviewsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.gameReviews,
    aliasName: 'games__id__game_reviews__game_id',
  );

  $$GameReviewsTableProcessedTableManager get gameReviewsRefs {
    final manager = $$GameReviewsTableTableManager(
      $_db,
      $_db.gameReviews,
    ).filter((f) => f.gameId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_gameReviewsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GamesTableFilterComposer extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endReason => $composableBuilder(
    column: $table.endReason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get engineElo => $composableBuilder(
    column: $table.engineElo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get opponentRating => $composableBuilder(
    column: $table.opponentRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get playerRating => $composableBuilder(
    column: $table.playerRating,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeClass => $composableBuilder(
    column: $table.timeClass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get timeControl => $composableBuilder(
    column: $table.timeControl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get practice => $composableBuilder(
    column: $table.practice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get hintsUsed => $composableBuilder(
    column: $table.hintsUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plyCount => $composableBuilder(
    column: $table.plyCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> gameAnalysesRefs(
    Expression<bool> Function($$GameAnalysesTableFilterComposer f) f,
  ) {
    final $$GameAnalysesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameAnalyses,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameAnalysesTableFilterComposer(
            $db: $db,
            $table: $db.gameAnalyses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> gameReviewsRefs(
    Expression<bool> Function($$GameReviewsTableFilterComposer f) f,
  ) {
    final $$GameReviewsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameReviews,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameReviewsTableFilterComposer(
            $db: $db,
            $table: $db.gameReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableOrderingComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pgn => $composableBuilder(
    column: $table.pgn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get result => $composableBuilder(
    column: $table.result,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endReason => $composableBuilder(
    column: $table.endReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get engineElo => $composableBuilder(
    column: $table.engineElo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get opponentRating => $composableBuilder(
    column: $table.opponentRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get playerRating => $composableBuilder(
    column: $table.playerRating,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeClass => $composableBuilder(
    column: $table.timeClass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get timeControl => $composableBuilder(
    column: $table.timeControl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get practice => $composableBuilder(
    column: $table.practice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get hintsUsed => $composableBuilder(
    column: $table.hintsUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plyCount => $composableBuilder(
    column: $table.plyCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GamesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GamesTable> {
  $$GamesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<String> get externalId => $composableBuilder(
    column: $table.externalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pgn =>
      $composableBuilder(column: $table.pgn, builder: (column) => column);

  GeneratedColumn<String> get playerSide => $composableBuilder(
    column: $table.playerSide,
    builder: (column) => column,
  );

  GeneratedColumn<String> get result =>
      $composableBuilder(column: $table.result, builder: (column) => column);

  GeneratedColumn<String> get endReason =>
      $composableBuilder(column: $table.endReason, builder: (column) => column);

  GeneratedColumn<int> get engineElo =>
      $composableBuilder(column: $table.engineElo, builder: (column) => column);

  GeneratedColumn<String> get opponentName => $composableBuilder(
    column: $table.opponentName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get opponentRating => $composableBuilder(
    column: $table.opponentRating,
    builder: (column) => column,
  );

  GeneratedColumn<int> get playerRating => $composableBuilder(
    column: $table.playerRating,
    builder: (column) => column,
  );

  GeneratedColumn<String> get timeClass =>
      $composableBuilder(column: $table.timeClass, builder: (column) => column);

  GeneratedColumn<String> get timeControl => $composableBuilder(
    column: $table.timeControl,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get practice =>
      $composableBuilder(column: $table.practice, builder: (column) => column);

  GeneratedColumn<int> get hintsUsed =>
      $composableBuilder(column: $table.hintsUsed, builder: (column) => column);

  GeneratedColumn<int> get plyCount =>
      $composableBuilder(column: $table.plyCount, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  Expression<T> gameAnalysesRefs<T extends Object>(
    Expression<T> Function($$GameAnalysesTableAnnotationComposer a) f,
  ) {
    final $$GameAnalysesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameAnalyses,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameAnalysesTableAnnotationComposer(
            $db: $db,
            $table: $db.gameAnalyses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> gameReviewsRefs<T extends Object>(
    Expression<T> Function($$GameReviewsTableAnnotationComposer a) f,
  ) {
    final $$GameReviewsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.gameReviews,
      getReferencedColumn: (t) => t.gameId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GameReviewsTableAnnotationComposer(
            $db: $db,
            $table: $db.gameReviews,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GamesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GamesTable,
          GameRow,
          $$GamesTableFilterComposer,
          $$GamesTableOrderingComposer,
          $$GamesTableAnnotationComposer,
          $$GamesTableCreateCompanionBuilder,
          $$GamesTableUpdateCompanionBuilder,
          (GameRow, $$GamesTableReferences),
          GameRow,
          PrefetchHooks Function({bool gameAnalysesRefs, bool gameReviewsRefs})
        > {
  $$GamesTableTableManager(_$AppDatabase db, $GamesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GamesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GamesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GamesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<String?> externalId = const Value.absent(),
                Value<String> pgn = const Value.absent(),
                Value<String> playerSide = const Value.absent(),
                Value<String> result = const Value.absent(),
                Value<String?> endReason = const Value.absent(),
                Value<int?> engineElo = const Value.absent(),
                Value<String?> opponentName = const Value.absent(),
                Value<int?> opponentRating = const Value.absent(),
                Value<int?> playerRating = const Value.absent(),
                Value<String?> timeClass = const Value.absent(),
                Value<String?> timeControl = const Value.absent(),
                Value<bool> practice = const Value.absent(),
                Value<int> hintsUsed = const Value.absent(),
                Value<int> plyCount = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
              }) => GamesCompanion(
                id: id,
                source: source,
                externalId: externalId,
                pgn: pgn,
                playerSide: playerSide,
                result: result,
                endReason: endReason,
                engineElo: engineElo,
                opponentName: opponentName,
                opponentRating: opponentRating,
                playerRating: playerRating,
                timeClass: timeClass,
                timeControl: timeControl,
                practice: practice,
                hintsUsed: hintsUsed,
                plyCount: plyCount,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String source,
                Value<String?> externalId = const Value.absent(),
                required String pgn,
                required String playerSide,
                required String result,
                Value<String?> endReason = const Value.absent(),
                Value<int?> engineElo = const Value.absent(),
                Value<String?> opponentName = const Value.absent(),
                Value<int?> opponentRating = const Value.absent(),
                Value<int?> playerRating = const Value.absent(),
                Value<String?> timeClass = const Value.absent(),
                Value<String?> timeControl = const Value.absent(),
                Value<bool> practice = const Value.absent(),
                Value<int> hintsUsed = const Value.absent(),
                required int plyCount,
                required DateTime startedAt,
                required DateTime endedAt,
              }) => GamesCompanion.insert(
                id: id,
                source: source,
                externalId: externalId,
                pgn: pgn,
                playerSide: playerSide,
                result: result,
                endReason: endReason,
                engineElo: engineElo,
                opponentName: opponentName,
                opponentRating: opponentRating,
                playerRating: playerRating,
                timeClass: timeClass,
                timeControl: timeControl,
                practice: practice,
                hintsUsed: hintsUsed,
                plyCount: plyCount,
                startedAt: startedAt,
                endedAt: endedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GamesTable, GameRow>(table),
                  $$GamesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({gameAnalysesRefs = false, gameReviewsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (gameAnalysesRefs) db.gameAnalyses,
                    if (gameReviewsRefs) db.gameReviews,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (gameAnalysesRefs)
                        await $_getPrefetchedData<
                          GameRow,
                          $GamesTable,
                          GameAnalysisRow
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._gameAnalysesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).gameAnalysesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (gameReviewsRefs)
                        await $_getPrefetchedData<
                          GameRow,
                          $GamesTable,
                          GameReviewRow
                        >(
                          currentTable: table,
                          referencedTable: $$GamesTableReferences
                              ._gameReviewsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GamesTableReferences(
                                db,
                                table,
                                p0,
                              ).gameReviewsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.gameId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GamesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GamesTable,
      GameRow,
      $$GamesTableFilterComposer,
      $$GamesTableOrderingComposer,
      $$GamesTableAnnotationComposer,
      $$GamesTableCreateCompanionBuilder,
      $$GamesTableUpdateCompanionBuilder,
      (GameRow, $$GamesTableReferences),
      GameRow,
      PrefetchHooks Function({bool gameAnalysesRefs, bool gameReviewsRefs})
    >;
typedef $$SettingsTableCreateCompanionBuilder =
    SettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingsTableUpdateCompanionBuilder =
    SettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$ImportMonthsTableCreateCompanionBuilder =
    ImportMonthsCompanion Function({
      required String username,
      required String month,
      required bool complete,
      Value<String?> etag,
      required int gameCount,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$ImportMonthsTableUpdateCompanionBuilder =
    ImportMonthsCompanion Function({
      Value<String> username,
      Value<String> month,
      Value<bool> complete,
      Value<String?> etag,
      Value<int> gameCount,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$ImportMonthsTableFilterComposer
    extends Composer<_$AppDatabase, $ImportMonthsTable> {
  $$ImportMonthsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameCount => $composableBuilder(
    column: $table.gameCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ImportMonthsTableOrderingComposer
    extends Composer<_$AppDatabase, $ImportMonthsTable> {
  $$ImportMonthsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get username => $composableBuilder(
    column: $table.username,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameCount => $composableBuilder(
    column: $table.gameCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImportMonthsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImportMonthsTable> {
  $$ImportMonthsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get username =>
      $composableBuilder(column: $table.username, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<bool> get complete =>
      $composableBuilder(column: $table.complete, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<int> get gameCount =>
      $composableBuilder(column: $table.gameCount, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$ImportMonthsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImportMonthsTable,
          ImportMonthRow,
          $$ImportMonthsTableFilterComposer,
          $$ImportMonthsTableOrderingComposer,
          $$ImportMonthsTableAnnotationComposer,
          $$ImportMonthsTableCreateCompanionBuilder,
          $$ImportMonthsTableUpdateCompanionBuilder,
          (
            ImportMonthRow,
            BaseReferences<_$AppDatabase, $ImportMonthsTable, ImportMonthRow>,
          ),
          ImportMonthRow,
          PrefetchHooks Function()
        > {
  $$ImportMonthsTableTableManager(_$AppDatabase db, $ImportMonthsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportMonthsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportMonthsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportMonthsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> username = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<int> gameCount = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportMonthsCompanion(
                username: username,
                month: month,
                complete: complete,
                etag: etag,
                gameCount: gameCount,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String username,
                required String month,
                required bool complete,
                Value<String?> etag = const Value.absent(),
                required int gameCount,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => ImportMonthsCompanion.insert(
                username: username,
                month: month,
                complete: complete,
                etag: etag,
                gameCount: gameCount,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ImportMonthsTable, ImportMonthRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ImportMonthsTable,
                    ImportMonthRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ImportMonthsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImportMonthsTable,
      ImportMonthRow,
      $$ImportMonthsTableFilterComposer,
      $$ImportMonthsTableOrderingComposer,
      $$ImportMonthsTableAnnotationComposer,
      $$ImportMonthsTableCreateCompanionBuilder,
      $$ImportMonthsTableUpdateCompanionBuilder,
      (
        ImportMonthRow,
        BaseReferences<_$AppDatabase, $ImportMonthsTable, ImportMonthRow>,
      ),
      ImportMonthRow,
      PrefetchHooks Function()
    >;
typedef $$GameAnalysesTableCreateCompanionBuilder =
    GameAnalysesCompanion Function({
      Value<int> gameId,
      required int depth,
      required String evals,
      required bool complete,
      required DateTime updatedAt,
    });
typedef $$GameAnalysesTableUpdateCompanionBuilder =
    GameAnalysesCompanion Function({
      Value<int> gameId,
      Value<int> depth,
      Value<String> evals,
      Value<bool> complete,
      Value<DateTime> updatedAt,
    });

final class $$GameAnalysesTableReferences
    extends BaseReferences<_$AppDatabase, $GameAnalysesTable, GameAnalysisRow> {
  $$GameAnalysesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('game_analyses__game_id__games__id');

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<int>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GameAnalysesTableFilterComposer
    extends Composer<_$AppDatabase, $GameAnalysesTable> {
  $$GameAnalysesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evals => $composableBuilder(
    column: $table.evals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameAnalysesTableOrderingComposer
    extends Composer<_$AppDatabase, $GameAnalysesTable> {
  $$GameAnalysesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get depth => $composableBuilder(
    column: $table.depth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evals => $composableBuilder(
    column: $table.evals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get complete => $composableBuilder(
    column: $table.complete,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameAnalysesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameAnalysesTable> {
  $$GameAnalysesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get depth =>
      $composableBuilder(column: $table.depth, builder: (column) => column);

  GeneratedColumn<String> get evals =>
      $composableBuilder(column: $table.evals, builder: (column) => column);

  GeneratedColumn<bool> get complete =>
      $composableBuilder(column: $table.complete, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameAnalysesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameAnalysesTable,
          GameAnalysisRow,
          $$GameAnalysesTableFilterComposer,
          $$GameAnalysesTableOrderingComposer,
          $$GameAnalysesTableAnnotationComposer,
          $$GameAnalysesTableCreateCompanionBuilder,
          $$GameAnalysesTableUpdateCompanionBuilder,
          (GameAnalysisRow, $$GameAnalysesTableReferences),
          GameAnalysisRow,
          PrefetchHooks Function({bool gameId})
        > {
  $$GameAnalysesTableTableManager(_$AppDatabase db, $GameAnalysesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameAnalysesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameAnalysesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameAnalysesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> gameId = const Value.absent(),
                Value<int> depth = const Value.absent(),
                Value<String> evals = const Value.absent(),
                Value<bool> complete = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => GameAnalysesCompanion(
                gameId: gameId,
                depth: depth,
                evals: evals,
                complete: complete,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> gameId = const Value.absent(),
                required int depth,
                required String evals,
                required bool complete,
                required DateTime updatedAt,
              }) => GameAnalysesCompanion.insert(
                gameId: gameId,
                depth: depth,
                evals: evals,
                complete: complete,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameAnalysesTable, GameAnalysisRow>(table),
                  $$GameAnalysesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable: $$GameAnalysesTableReferences
                                    ._gameIdTable(db),
                                referencedColumn: $$GameAnalysesTableReferences
                                    ._gameIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GameAnalysesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameAnalysesTable,
      GameAnalysisRow,
      $$GameAnalysesTableFilterComposer,
      $$GameAnalysesTableOrderingComposer,
      $$GameAnalysesTableAnnotationComposer,
      $$GameAnalysesTableCreateCompanionBuilder,
      $$GameAnalysesTableUpdateCompanionBuilder,
      (GameAnalysisRow, $$GameAnalysesTableReferences),
      GameAnalysisRow,
      PrefetchHooks Function({bool gameId})
    >;
typedef $$GameReviewsTableCreateCompanionBuilder =
    GameReviewsCompanion Function({
      Value<int> gameId,
      required String model,
      required String json,
      required DateTime createdAt,
    });
typedef $$GameReviewsTableUpdateCompanionBuilder =
    GameReviewsCompanion Function({
      Value<int> gameId,
      Value<String> model,
      Value<String> json,
      Value<DateTime> createdAt,
    });

final class $$GameReviewsTableReferences
    extends BaseReferences<_$AppDatabase, $GameReviewsTable, GameReviewRow> {
  $$GameReviewsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GamesTable _gameIdTable(_$AppDatabase db) =>
      db.games.createAlias('game_reviews__game_id__games__id');

  $$GamesTableProcessedTableManager get gameId {
    final $_column = $_itemColumn<int>('game_id')!;

    final manager = $$GamesTableTableManager(
      $_db,
      $_db.games,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_gameIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GameReviewsTableFilterComposer
    extends Composer<_$AppDatabase, $GameReviewsTable> {
  $$GameReviewsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$GamesTableFilterComposer get gameId {
    final $$GamesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableFilterComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameReviewsTableOrderingComposer
    extends Composer<_$AppDatabase, $GameReviewsTable> {
  $$GameReviewsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$GamesTableOrderingComposer get gameId {
    final $$GamesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableOrderingComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameReviewsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GameReviewsTable> {
  $$GameReviewsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$GamesTableAnnotationComposer get gameId {
    final $$GamesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.gameId,
      referencedTable: $db.games,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GamesTableAnnotationComposer(
            $db: $db,
            $table: $db.games,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GameReviewsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GameReviewsTable,
          GameReviewRow,
          $$GameReviewsTableFilterComposer,
          $$GameReviewsTableOrderingComposer,
          $$GameReviewsTableAnnotationComposer,
          $$GameReviewsTableCreateCompanionBuilder,
          $$GameReviewsTableUpdateCompanionBuilder,
          (GameReviewRow, $$GameReviewsTableReferences),
          GameReviewRow,
          PrefetchHooks Function({bool gameId})
        > {
  $$GameReviewsTableTableManager(_$AppDatabase db, $GameReviewsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GameReviewsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GameReviewsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GameReviewsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> gameId = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => GameReviewsCompanion(
                gameId: gameId,
                model: model,
                json: json,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> gameId = const Value.absent(),
                required String model,
                required String json,
                required DateTime createdAt,
              }) => GameReviewsCompanion.insert(
                gameId: gameId,
                model: model,
                json: json,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GameReviewsTable, GameReviewRow>(table),
                  $$GameReviewsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({gameId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (gameId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.gameId,
                                referencedTable: $$GameReviewsTableReferences
                                    ._gameIdTable(db),
                                referencedColumn: $$GameReviewsTableReferences
                                    ._gameIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GameReviewsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GameReviewsTable,
      GameReviewRow,
      $$GameReviewsTableFilterComposer,
      $$GameReviewsTableOrderingComposer,
      $$GameReviewsTableAnnotationComposer,
      $$GameReviewsTableCreateCompanionBuilder,
      $$GameReviewsTableUpdateCompanionBuilder,
      (GameReviewRow, $$GameReviewsTableReferences),
      GameReviewRow,
      PrefetchHooks Function({bool gameId})
    >;
typedef $$CoachChatsTableCreateCompanionBuilder =
    CoachChatsCompanion Function({
      Value<int> id,
      required String title,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> messageCount,
      Value<int?> gameId,
      required String scopeLabel,
      Value<String?> thumbFen,
      Value<String> verified,
    });
typedef $$CoachChatsTableUpdateCompanionBuilder =
    CoachChatsCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> messageCount,
      Value<int?> gameId,
      Value<String> scopeLabel,
      Value<String?> thumbFen,
      Value<String> verified,
    });

final class $$CoachChatsTableReferences
    extends BaseReferences<_$AppDatabase, $CoachChatsTable, CoachChatRow> {
  $$CoachChatsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CoachMessagesTable, List<CoachMessageRow>>
  _coachMessagesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.coachMessages,
    aliasName: 'coach_chats__id__coach_messages__chat_id',
  );

  $$CoachMessagesTableProcessedTableManager get coachMessagesRefs {
    final manager = $$CoachMessagesTableTableManager(
      $_db,
      $_db.coachMessages,
    ).filter((f) => f.chatId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_coachMessagesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoachChatsTableFilterComposer
    extends Composer<_$AppDatabase, $CoachChatsTable> {
  $$CoachChatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get thumbFen => $composableBuilder(
    column: $table.thumbFen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> coachMessagesRefs(
    Expression<bool> Function($$CoachMessagesTableFilterComposer f) f,
  ) {
    final $$CoachMessagesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coachMessages,
      getReferencedColumn: (t) => t.chatId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoachMessagesTableFilterComposer(
            $db: $db,
            $table: $db.coachMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoachChatsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoachChatsTable> {
  $$CoachChatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gameId => $composableBuilder(
    column: $table.gameId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get thumbFen => $composableBuilder(
    column: $table.thumbFen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoachChatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoachChatsTable> {
  $$CoachChatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gameId =>
      $composableBuilder(column: $table.gameId, builder: (column) => column);

  GeneratedColumn<String> get scopeLabel => $composableBuilder(
    column: $table.scopeLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get thumbFen =>
      $composableBuilder(column: $table.thumbFen, builder: (column) => column);

  GeneratedColumn<String> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  Expression<T> coachMessagesRefs<T extends Object>(
    Expression<T> Function($$CoachMessagesTableAnnotationComposer a) f,
  ) {
    final $$CoachMessagesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.coachMessages,
      getReferencedColumn: (t) => t.chatId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoachMessagesTableAnnotationComposer(
            $db: $db,
            $table: $db.coachMessages,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoachChatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoachChatsTable,
          CoachChatRow,
          $$CoachChatsTableFilterComposer,
          $$CoachChatsTableOrderingComposer,
          $$CoachChatsTableAnnotationComposer,
          $$CoachChatsTableCreateCompanionBuilder,
          $$CoachChatsTableUpdateCompanionBuilder,
          (CoachChatRow, $$CoachChatsTableReferences),
          CoachChatRow,
          PrefetchHooks Function({bool coachMessagesRefs})
        > {
  $$CoachChatsTableTableManager(_$AppDatabase db, $CoachChatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoachChatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoachChatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoachChatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                Value<String> scopeLabel = const Value.absent(),
                Value<String?> thumbFen = const Value.absent(),
                Value<String> verified = const Value.absent(),
              }) => CoachChatsCompanion(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageCount: messageCount,
                gameId: gameId,
                scopeLabel: scopeLabel,
                thumbFen: thumbFen,
                verified: verified,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> messageCount = const Value.absent(),
                Value<int?> gameId = const Value.absent(),
                required String scopeLabel,
                Value<String?> thumbFen = const Value.absent(),
                Value<String> verified = const Value.absent(),
              }) => CoachChatsCompanion.insert(
                id: id,
                title: title,
                createdAt: createdAt,
                updatedAt: updatedAt,
                messageCount: messageCount,
                gameId: gameId,
                scopeLabel: scopeLabel,
                thumbFen: thumbFen,
                verified: verified,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoachChatsTable, CoachChatRow>(table),
                  $$CoachChatsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({coachMessagesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (coachMessagesRefs) db.coachMessages,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (coachMessagesRefs)
                    await $_getPrefetchedData<
                      CoachChatRow,
                      $CoachChatsTable,
                      CoachMessageRow
                    >(
                      currentTable: table,
                      referencedTable: $$CoachChatsTableReferences
                          ._coachMessagesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CoachChatsTableReferences(
                            db,
                            table,
                            p0,
                          ).coachMessagesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.chatId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CoachChatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoachChatsTable,
      CoachChatRow,
      $$CoachChatsTableFilterComposer,
      $$CoachChatsTableOrderingComposer,
      $$CoachChatsTableAnnotationComposer,
      $$CoachChatsTableCreateCompanionBuilder,
      $$CoachChatsTableUpdateCompanionBuilder,
      (CoachChatRow, $$CoachChatsTableReferences),
      CoachChatRow,
      PrefetchHooks Function({bool coachMessagesRefs})
    >;
typedef $$CoachMessagesTableCreateCompanionBuilder =
    CoachMessagesCompanion Function({
      Value<int> id,
      required int chatId,
      required String role,
      required DateTime at,
      required String body,
      Value<String> payload,
    });
typedef $$CoachMessagesTableUpdateCompanionBuilder =
    CoachMessagesCompanion Function({
      Value<int> id,
      Value<int> chatId,
      Value<String> role,
      Value<DateTime> at,
      Value<String> body,
      Value<String> payload,
    });

final class $$CoachMessagesTableReferences
    extends
        BaseReferences<_$AppDatabase, $CoachMessagesTable, CoachMessageRow> {
  $$CoachMessagesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CoachChatsTable _chatIdTable(_$AppDatabase db) =>
      db.coachChats.createAlias('coach_messages__chat_id__coach_chats__id');

  $$CoachChatsTableProcessedTableManager get chatId {
    final $_column = $_itemColumn<int>('chat_id')!;

    final manager = $$CoachChatsTableTableManager(
      $_db,
      $_db.coachChats,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_chatIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CoachMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $CoachMessagesTable> {
  $$CoachMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  $$CoachChatsTableFilterComposer get chatId {
    final $$CoachChatsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chatId,
      referencedTable: $db.coachChats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoachChatsTableFilterComposer(
            $db: $db,
            $table: $db.coachChats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoachMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $CoachMessagesTable> {
  $$CoachMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get at => $composableBuilder(
    column: $table.at,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoachChatsTableOrderingComposer get chatId {
    final $$CoachChatsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chatId,
      referencedTable: $db.coachChats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoachChatsTableOrderingComposer(
            $db: $db,
            $table: $db.coachChats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoachMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoachMessagesTable> {
  $$CoachMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get at =>
      $composableBuilder(column: $table.at, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  $$CoachChatsTableAnnotationComposer get chatId {
    final $$CoachChatsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.chatId,
      referencedTable: $db.coachChats,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoachChatsTableAnnotationComposer(
            $db: $db,
            $table: $db.coachChats,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CoachMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoachMessagesTable,
          CoachMessageRow,
          $$CoachMessagesTableFilterComposer,
          $$CoachMessagesTableOrderingComposer,
          $$CoachMessagesTableAnnotationComposer,
          $$CoachMessagesTableCreateCompanionBuilder,
          $$CoachMessagesTableUpdateCompanionBuilder,
          (CoachMessageRow, $$CoachMessagesTableReferences),
          CoachMessageRow,
          PrefetchHooks Function({bool chatId})
        > {
  $$CoachMessagesTableTableManager(_$AppDatabase db, $CoachMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoachMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoachMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoachMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> chatId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> at = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<String> payload = const Value.absent(),
              }) => CoachMessagesCompanion(
                id: id,
                chatId: chatId,
                role: role,
                at: at,
                body: body,
                payload: payload,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int chatId,
                required String role,
                required DateTime at,
                required String body,
                Value<String> payload = const Value.absent(),
              }) => CoachMessagesCompanion.insert(
                id: id,
                chatId: chatId,
                role: role,
                at: at,
                body: body,
                payload: payload,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CoachMessagesTable, CoachMessageRow>(table),
                  $$CoachMessagesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({chatId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (chatId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.chatId,
                                referencedTable: $$CoachMessagesTableReferences
                                    ._chatIdTable(db),
                                referencedColumn: $$CoachMessagesTableReferences
                                    ._chatIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CoachMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoachMessagesTable,
      CoachMessageRow,
      $$CoachMessagesTableFilterComposer,
      $$CoachMessagesTableOrderingComposer,
      $$CoachMessagesTableAnnotationComposer,
      $$CoachMessagesTableCreateCompanionBuilder,
      $$CoachMessagesTableUpdateCompanionBuilder,
      (CoachMessageRow, $$CoachMessagesTableReferences),
      CoachMessageRow,
      PrefetchHooks Function({bool chatId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GamesTableTableManager get games =>
      $$GamesTableTableManager(_db, _db.games);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$ImportMonthsTableTableManager get importMonths =>
      $$ImportMonthsTableTableManager(_db, _db.importMonths);
  $$GameAnalysesTableTableManager get gameAnalyses =>
      $$GameAnalysesTableTableManager(_db, _db.gameAnalyses);
  $$GameReviewsTableTableManager get gameReviews =>
      $$GameReviewsTableTableManager(_db, _db.gameReviews);
  $$CoachChatsTableTableManager get coachChats =>
      $$CoachChatsTableTableManager(_db, _db.coachChats);
  $$CoachMessagesTableTableManager get coachMessages =>
      $$CoachMessagesTableTableManager(_db, _db.coachMessages);
}
