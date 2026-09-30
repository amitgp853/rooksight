import 'dart:convert';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/llm/llm_client.dart';
import 'board_setup.dart';
import 'position_check.dart';

/// One row of the "Reading your board" list: what the reader is doing, and
/// once done, what it found.
@immutable
class ScanStep {
  const ScanStep(this.label, {this.detail, this.done = false, this.retry = false});

  final String label;

  /// Shown under the label once the step is done.
  final String? detail;
  final bool done;

  /// A second look at doubtful squares (drawn in brass).
  final bool retry;

  ScanStep finish(String detail) => ScanStep(label, detail: detail, done: true, retry: retry);
}

/// What a scan found: the position as read, the squares it was least sure
/// of, and whether White was at the bottom of the photo.
@immutable
class ScanResult {
  const ScanResult({
    required this.setup,
    this.unsure = const {},
    this.whiteAtBottom = true,
    this.problem,
  });

  final BoardSetup setup;
  final Set<Square> unsure;
  final bool whiteAtBottom;

  /// Why the position can't be analysed yet, if it can't.
  final PositionProblem? problem;
}

/// Why a scan didn't produce a position.
enum ScanFailureKind { noBoard, blurry, illegal, offline, noKey, invalidKey, limit, failed }

class ScanFailure implements Exception {
  const ScanFailure(this.kind, {this.result});

  final ScanFailureKind kind;

  /// What was read, for an [ScanFailureKind.illegal] position (to edit).
  final ScanResult? result;

  @override
  String toString() => 'ScanFailure($kind)';
}

/// Reads a chess position from a photo with the player's Gemini key: one
/// request reads the whole board, the rules are checked on the phone, and
/// if something doesn't add up (two white kings, a pawn on the back rank) a
/// second request looks again at just those squares.
///
/// Photos go to the model only; nothing is stored.
class BoardReader {
  BoardReader(this._llm);

  final LlmClient _llm;

  /// Squares asked about in the second look, at most.
  static const maxRecheck = 6;

  /// Reads [jpeg], reporting progress through [onSteps] (the whole list each
  /// time). Throws [ScanFailure]. Stops quietly (returns null) once
  /// [isCancelled] turns true.
  Future<ScanResult?> read(
    Uint8List jpeg, {
    required void Function(List<ScanStep> steps) onSteps,
    bool Function()? isCancelled,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    final steps = <ScanStep>[const ScanStep('Finding the board…')];
    void report() => onSteps(List.unmodifiable(steps));
    report();

    final reading = await _ask(
      LlmRequest(
        system: _readSystem,
        messages: [
          LlmMessage.user(_readPrompt, images: [LlmImage(jpeg)]),
        ],
        jsonSchema: _readSchema,
        temperature: 0.1,
      ),
    );
    if (cancelled()) return null;

    final found = reading['board_found'] == true;
    final quality = reading['image_quality'];
    final whiteAtBottom = reading['white_at_bottom'] != false;
    final ranks = [...?(reading['ranks'] as List<Object?>?)?.whereType<String>()];
    final grid = BoardSetup.fromRanks(ranks);
    if (!found || grid == null) {
      throw ScanFailure(
        found && quality != 'clear' ? ScanFailureKind.blurry : ScanFailureKind.noBoard,
      );
    }
    var unsure = _cells(reading['unsure_cells']);
    if (quality != 'clear' && unsure.length > 8) throw const ScanFailure(ScanFailureKind.blurry);

    // The grid as photographed; turned round when Black was at the bottom.
    Square toSquare(({int row, int col}) cell) {
      final square = Square.fromCoords(File(cell.col), Rank(7 - cell.row));
      return whiteAtBottom ? square : Square(63 - square);
    }

    var setup = whiteAtBottom ? grid : grid.rotated();
    steps[0] = steps[0].finish('Board found · 8 × 8 squares');
    steps.add(
      const ScanStep('Identifying pieces…').finish(
        '${setup.pieces.length} ${setup.pieces.length == 1 ? 'piece' : 'pieces'} · '
        '${unsure.isEmpty ? 'all clear' : '${unsure.length} unsure'}',
      ),
    );
    steps.add(const ScanStep('Checking the position is legal…'));
    report();

    var problem = _check(setup);
    if (problem == null) {
      steps.last = steps.last.finish('Legal position');
      report();
      return ScanResult(
        setup: _withTurn(setup),
        unsure: {for (final c in unsure) toSquare(c)},
        whiteAtBottom: whiteAtBottom,
      );
    }
    steps.last = steps.last.finish(_problemSummary(problem, setup));

    // A second look at the squares behind the problem, then the doubtful ones.
    final recheck = {
      ...problem.squares,
      for (final c in unsure) toSquare(c),
    }.take(maxRecheck).toList();
    if (recheck.isEmpty) {
      report();
      throw ScanFailure(
        ScanFailureKind.illegal,
        result: ScanResult(setup: setup, whiteAtBottom: whiteAtBottom, problem: problem),
      );
    }
    final names = _names(recheck);
    steps.add(ScanStep('Double-checking $names…', retry: true));
    report();

    // Cells in the photo's own grid, as the model saw them.
    ({int row, int col}) toCell(Square square) {
      final s = whiteAtBottom ? square : Square(63 - square);
      return (row: 7 - s.rank, col: s.file);
    }

    final second = await _ask(
      LlmRequest(
        system: _readSystem,
        messages: [
          LlmMessage.user(
            _recheckPrompt(ranks, [for (final s in recheck) toCell(s)]),
            images: [LlmImage(jpeg)],
          ),
        ],
        jsonSchema: _recheckSchema,
        temperature: 0.1,
      ),
    );
    if (cancelled()) return null;

    final seen = <String>[];
    for (final cell
        in (second['cells'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>()) {
      final row = (cell['row'] as num?)?.toInt();
      final col = (cell['col'] as num?)?.toInt();
      final char = cell['piece'];
      if (row == null || col == null || row < 0 || row > 7 || col < 0 || col > 7) continue;
      if (char is! String) continue;
      final square = toSquare((row: row, col: col));
      if (!recheck.contains(square)) continue;
      final piece = char == '.' ? null : Piece.fromChar(char);
      if (char != '.' && piece == null) continue;
      setup = setup.withPiece(square, piece);
      seen.add('${square.name} ${piece == null ? 'empty' : _roleName(piece.role)}');
    }
    unsure = {...unsure, for (final s in recheck) toCell(s)}.toList();
    steps.last = steps.last.finish(seen.isEmpty ? 'No change' : seen.join(' · '));
    report();

    problem = _check(setup);
    final result = ScanResult(
      setup: problem == null ? _withTurn(setup) : setup,
      unsure: {for (final c in unsure) toSquare(c)},
      whiteAtBottom: whiteAtBottom,
      problem: problem,
    );
    if (problem != null) throw ScanFailure(ScanFailureKind.illegal, result: result);
    return result;
  }

  /// [checkPosition], ignoring whose move it is: a photo can't show that,
  /// and [_withTurn] picks the side that must be to move.
  static PositionProblem? _check(BoardSetup setup) {
    final problem = checkPosition(setup);
    if (problem?.cause != PositionProblemCause.wrongCheck) return problem;
    return checkPosition(setup.copyWith(turn: setup.turn.opposite));
  }

  /// White to move, unless Black is in check (then it must be Black's move).
  static BoardSetup _withTurn(BoardSetup setup) {
    final white = setup.copyWith(turn: Side.white);
    return checkPosition(white)?.cause == PositionProblemCause.wrongCheck
        ? setup.copyWith(turn: Side.black)
        : white;
  }

  Future<Map<String, Object?>> _ask(LlmRequest request) async {
    final String text;
    try {
      text = await _llm.generate(request);
    } on LlmMissingKey {
      throw const ScanFailure(ScanFailureKind.noKey);
    } on LlmInvalidKey {
      throw const ScanFailure(ScanFailureKind.invalidKey);
    } on LlmRateLimited {
      throw const ScanFailure(ScanFailureKind.limit);
    } on LlmOffline {
      throw const ScanFailure(ScanFailureKind.offline);
    } on LlmFailure {
      throw const ScanFailure(ScanFailureKind.failed);
    }
    try {
      final json = jsonDecode(text);
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Falls through.
    }
    throw const ScanFailure(ScanFailureKind.failed);
  }

  static List<({int row, int col})> _cells(Object? list) => [
    for (final cell in (list as List<Object?>? ?? const []).whereType<Map<String, Object?>>())
      if ((cell['row'] as num?)?.toInt() case final row? when row >= 0 && row < 8)
        if ((cell['col'] as num?)?.toInt() case final col? when col >= 0 && col < 8)
          (row: row, col: col),
  ];

  /// "White looks like it has 2 kings", for the legality step.
  static String _problemSummary(PositionProblem problem, BoardSetup setup) {
    switch (problem.cause) {
      case PositionProblemCause.kings:
        final side = setup.board.piecesOf(Side.white, Role.king).size != 1
            ? Side.white
            : Side.black;
        final kings = setup.board.piecesOf(side, Role.king).size;
        final name = side == Side.white ? 'White' : 'Black';
        return kings == 0
            ? '$name looks like it has no king'
            : '$name looks like it has $kings kings';
      case PositionProblemCause.backRankPawns:
        return 'A pawn looks like it’s on the back rank';
      case PositionProblemCause.tooManyPieces || PositionProblemCause.tooManyPawns:
        return 'Too many pieces for one side';
      case _:
        return 'Something doesn’t add up';
    }
  }

  static String _names(List<Square> squares) {
    final names = [for (final s in squares) s.name];
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  }

  static String _roleName(Role role) => switch (role) {
    Role.king => 'king',
    Role.queen => 'queen',
    Role.rook => 'rook',
    Role.bishop => 'bishop',
    Role.knight => 'knight',
    Role.pawn => 'pawn',
  };

  static const _readSystem =
      'You read chess positions from photos of real boards and printed diagrams. '
      'Report only what you can see. Never invent pieces to make a position look normal.';

  static const _readPrompt = '''
Read the chess position in this photo.

- board_found: false if the photo doesn't show a whole 8×8 chess board.
- image_quality: "clear", or "too_dark" / "too_blurry" if you can't tell the pieces apart reliably.
- ranks: the board as it appears in the photo, exactly 8 strings, the row at the TOP of the photo first. Each string has exactly 8 characters, left to right: K Q R B N P for white pieces, k q r b n p for black pieces, "." for an empty square.
- white_at_bottom: true if White's pieces started on the side nearest the bottom of the photo (look at the coordinates if printed, else at where most white pieces are, else true).
- unsure_cells: the cells (row 0–7 from the top, col 0–7 from the left) you are least sure about, if any.''';

  static const _readSchema = {
    'type': 'object',
    'properties': {
      'board_found': {'type': 'boolean'},
      'image_quality': {
        'type': 'string',
        'enum': ['clear', 'too_dark', 'too_blurry'],
      },
      'ranks': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'white_at_bottom': {'type': 'boolean'},
      'unsure_cells': {'type': 'array', 'items': _cellSchema},
    },
    'required': ['board_found', 'image_quality', 'ranks', 'white_at_bottom', 'unsure_cells'],
  };

  static const _cellSchema = {
    'type': 'object',
    'properties': {
      'row': {'type': 'integer'},
      'col': {'type': 'integer'},
    },
    'required': ['row', 'col'],
  };

  static String _recheckPrompt(List<String> ranks, List<({int row, int col})> cells) =>
      '''
You read this board as (top row of the photo first, "." empty):
${ranks.join('\n')}

That position is impossible, so some of it is misread. Look again, carefully, at only these cells (row 0–7 from the top, col 0–7 from the left):
${[for (final c in cells) '- row ${c.row}, col ${c.col}'].join('\n')}

Shadows, reflections and pieces hiding behind taller ones are common mistakes. For each cell, give what is really on it: K Q R B N P (white), k q r b n p (black) or "." (empty).''';

  static const _recheckSchema = {
    'type': 'object',
    'properties': {
      'cells': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'row': {'type': 'integer'},
            'col': {'type': 'integer'},
            'piece': {'type': 'string'},
          },
          'required': ['row', 'col', 'piece'],
        },
      },
    },
    'required': ['cells'],
  };
}
