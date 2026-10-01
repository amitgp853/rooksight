import 'dart:convert';
import 'dart:math' as math;
import 'package:dartchess/dartchess.dart';
import 'package:flutter/foundation.dart';

import '../../../core/llm/llm_client.dart';
import 'board_setup.dart';
import 'position_check.dart';
import 'scan_photo.dart';

/// Cuts [box] out of a board photo, as a JPEG.
typedef CellCropper = Future<Uint8List> Function(Uint8List board, CellBox box);

/// Draws the lines between [rows] × [cols] cells on a board photo.
typedef GridDrawer = Future<Uint8List> Function(Uint8List board, {int rows, int cols});

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
enum ScanFailureKind {
  noBoard,
  blurry,
  illegal,
  offline,
  noKey,
  invalidKey,
  limit,
  failed,

  /// The app's own daily scan limit (see `ScanUsage`).
  dailyCap,

  /// This week's free scans are used and there are no credits left.
  outOfUses,

  /// Rooksight's server has paused AI use for today.
  paused,
}

class ScanFailure implements Exception {
  const ScanFailure(this.kind, {this.result, this.local = false});

  final ScanFailureKind kind;

  /// Found on the phone, before any Gemini request (no request spent). The
  /// check can be wrong, so the player may scan anyway.
  final bool local;

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
/// The first look goes to the lighter model with a grid drawn on the photo,
/// and must answer exactly 8 × 8 squares: tested on book diagrams, that read
/// every square right where the bare photo, as free text, often shifted a
/// row by one. The second look, a harder question, uses the usual model.
///
/// Nothing is stored. Tokens: the first request is the photo (1120 tokens on
/// Gemini 3) plus about 400 of text; the second look, when needed, sends a
/// close-up of the doubtful squares at a lower resolution, which still gives
/// each square at least as much detail as the first look did.
class BoardReader {
  BoardReader(this._llm, {CellCropper? crop, GridDrawer? grid})
    : _crop = crop ?? ScanPhoto.cropCells,
      _grid = grid ?? ScanPhoto.withGrid;

  final LlmClient _llm;
  final CellCropper _crop;
  final GridDrawer _grid;

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
    // The first look and the second are one scan.
    final action = LlmAction.start(LlmActionKind.scan);

    final reading = await _ask(
      LlmRequest(
        system: _readSystem,
        messages: [
          LlmMessage.user(_readPrompt, images: [LlmImage(await _gridded(jpeg, 8, 8))]),
        ],
        jsonSchema: _readSchema,
        temperature: 0.1,
        light: true,
        action: action,
      ),
    );
    if (cancelled()) return null;

    final found = reading['board_found'] == true;
    final quality = reading['image_quality'];
    final whiteAtBottom = reading['white_at_bottom'] != false;
    final ranks = _ranks(reading['rows']);
    if (!found) throw const ScanFailure(ScanFailureKind.noBoard);
    final grid = BoardSetup.fromRanks(ranks);
    if (grid == null) {
      // Not answered as 8 × 8 squares: a dark photo, or else a bad answer
      // (not a missing board).
      throw ScanFailure(quality == 'clear' ? ScanFailureKind.failed : ScanFailureKind.blurry);
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

    final cells = [for (final s in recheck) toCell(s)];
    final box = closeUpOf(cells);
    Uint8List? closeUp;
    if (box != fullBoard) {
      try {
        closeUp = await _crop(jpeg, box);
      } on Object {
        closeUp = null; // The whole photo, then.
      }
    }
    if (cancelled()) return null;
    final second = await _ask(
      LlmRequest(
        system: _readSystem,
        messages: [
          LlmMessage.user(
            _recheckPrompt(ranks, cells, closeUp == null ? null : box),
            images: [
              LlmImage(
                closeUp == null
                    ? await _gridded(jpeg, 8, 8)
                    : await _gridded(closeUp, box.bottom - box.top + 1, box.right - box.left + 1),
              ),
            ],
          ),
        ],
        jsonSchema: _recheckSchema,
        temperature: 0.1,
        mediaResolution: closeUp == null ? null : resolutionFor(box),
        action: action,
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

  static const fullBoard = (top: 0, left: 0, bottom: 7, right: 7);

  /// The cells around [cells], one cell of margin each way (tall pieces lean
  /// into the next square in a photo).
  static CellBox closeUpOf(List<({int row, int col})> cells) {
    int at(Iterable<int> values, int Function(int, int) pick) => values.reduce(pick);
    final rows = cells.map((c) => c.row);
    final cols = cells.map((c) => c.col);
    return (
      top: math.max(0, at(rows, math.min) - 1),
      left: math.max(0, at(cols, math.min) - 1),
      bottom: math.min(7, at(rows, math.max) + 1),
      right: math.min(7, at(cols, math.max) + 1),
    );
  }

  /// The lowest resolution that still gives each square of [box] as many
  /// image tokens as the first look gave each of the 64 (1120 / 64 = 17.5):
  /// low (280) up to 16 cells, medium (560) up to 32, else high.
  static LlmMediaResolution resolutionFor(CellBox box) {
    final count = (box.bottom - box.top + 1) * (box.right - box.left + 1);
    if (count <= 16) return LlmMediaResolution.low;
    if (count <= 32) return LlmMediaResolution.medium;
    return LlmMediaResolution.high;
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

  /// [jpeg] with its grid drawn on, or as it is if that fails.
  Future<Uint8List> _gridded(Uint8List jpeg, int rows, int cols) async {
    try {
      return await _grid(jpeg, rows: rows, cols: cols);
    } on Object {
      return jpeg;
    }
  }

  /// The `rows` of a reading as eight-character strings (each row a list of
  /// one-character squares).
  static List<String> _ranks(Object? rows) => [
    for (final row in (rows as List<Object?>? ?? const []))
      if (row is List<Object?>) row.whereType<String>().join() else if (row is String) row,
  ];

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
    } on LlmOutOfUses {
      throw const ScanFailure(ScanFailureKind.outOfUses);
    } on LlmPaused {
      throw const ScanFailure(ScanFailureKind.paused);
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
Read the chess position in this photo. Thin red lines have been drawn over it to mark the 64 squares: read one red cell at a time. It may be a real board or a printed diagram (in diagrams the dark squares are often hatched with diagonal lines; hatching is never a piece; white pieces are drawn hollow/outlined, black pieces filled in).

- board_found: false only if the photo doesn't show a whole 8×8 chess board.
- image_quality: "clear", or "too_dark" / "too_blurry" if you can't tell the pieces apart reliably.
- rows: the board as it appears in the photo, exactly 8 rows, the row at the TOP of the photo first. Each row is exactly 8 squares, left to right: K Q R B N P for white pieces, k q r b n p for black pieces, "." for an empty square. Go square by square; count to 8 in every row.
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
      // 8 × 8, each square one of the 13 symbols: the model can't send a
      // row that's a square short or long.
      'rows': {
        'type': 'array',
        'items': {
          'type': 'array',
          'items': {'type': 'string', 'enum': _squareSymbols},
          'minItems': 8,
          'maxItems': 8,
        },
        'minItems': 8,
        'maxItems': 8,
      },
      'white_at_bottom': {'type': 'boolean'},
      'unsure_cells': {'type': 'array', 'items': _cellSchema},
    },
    'required': ['board_found', 'image_quality', 'rows', 'white_at_bottom', 'unsure_cells'],
  };

  static const _squareSymbols = ['K', 'Q', 'R', 'B', 'N', 'P', 'k', 'q', 'r', 'b', 'n', 'p', '.'];

  static const _cellSchema = {
    'type': 'object',
    'properties': {
      'row': {'type': 'integer'},
      'col': {'type': 'integer'},
    },
    'required': ['row', 'col'],
  };

  static String _recheckPrompt(
    List<String> ranks,
    List<({int row, int col})> cells,
    CellBox? closeUp,
  ) =>
      '''
You read this board as (top row of the photo first, "." empty):
${ranks.join('\n')}
Thin red lines mark the squares in the picture.
${closeUp == null ? '' : '\nThe picture is a close-up of part of that board: rows ${closeUp.top}–${closeUp.bottom} and columns ${closeUp.left}–${closeUp.right} of the 8×8 grid. Use the full grid’s row and column numbers in your answer.\n'}
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
            'piece': {'type': 'string', 'enum': _squareSymbols},
          },
          'required': ['row', 'col', 'piece'],
        },
      },
    },
    'required': ['cells'],
  };
}
