import 'dart:convert';
import 'dart:typed_data';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:move_wise/core/llm/llm_client.dart';
import 'package:move_wise/features/scan/domain/board_reader.dart';
import 'package:move_wise/features/scan/domain/board_setup.dart';
import 'package:move_wise/features/scan/domain/position_check.dart';
import 'package:move_wise/features/scan/domain/scan_photo.dart';

import '../../support/fake_llm.dart';

/// The starting position as eight rows, White at the bottom.
const _startRanks = [
  'rnbqkbnr',
  'pppppppp',
  '........',
  '........',
  '........',
  '........',
  'PPPPPPPP',
  'RNBQKBNR',
];

LlmReply _json(Map<String, Object?> json) => LlmReply(message: LlmMessage.model(jsonEncode(json)));

Map<String, Object?> _reading({
  List<String> ranks = _startRanks,
  bool found = true,
  String quality = 'clear',
  bool whiteAtBottom = true,
  List<Map<String, int>> unsure = const [],
}) => {
  'board_found': found,
  'image_quality': quality,
  'ranks': ranks,
  'white_at_bottom': whiteAtBottom,
  'unsure_cells': unsure,
};

void main() {
  group('BoardSetup', () {
    test('reads rows from the photo into squares', () {
      final setup = BoardSetup.fromRanks(_startRanks)!;
      expect(setup.board.fen, Chess.initial.board.fen);
      expect(setup.fen, Chess.initial.fen);
    });

    test('turns the grid round when Black was at the bottom', () {
      final reversed = [for (final r in _startRanks.reversed) r.split('').reversed.join()];
      final setup = BoardSetup.fromRanks(reversed, whiteAtBottom: false)!;
      expect(setup.board.fen, Chess.initial.board.fen);
    });

    test('rejects a grid that is not 8 × 8 pieces', () {
      expect(BoardSetup.fromRanks(_startRanks.take(7).toList()), isNull);
      expect(BoardSetup.fromRanks([..._startRanks.take(7), 'RNBQKBN']), isNull);
      expect(BoardSetup.fromRanks([..._startRanks.take(7), 'RNBQKBNX']), isNull);
    });

    test('castling rights only where king and rook are at home', () {
      final setup = BoardSetup.fromFen('r3k3/8/8/8/8/8/8/4K2R w - - 0 1');
      expect(setup.canCastle((side: Side.white, wing: CastlingSide.king)), isTrue);
      expect(setup.canCastle((side: Side.white, wing: CastlingSide.queen)), isFalse);
      expect(setup.canCastle((side: Side.black, wing: CastlingSide.queen)), isTrue);
      final all = setup.copyWith(castling: BoardSetup.allCastlingRights);
      expect(all.fen, 'r3k3/8/8/8/8/8/8/4K2R w Kq - 0 1');
      final noKingside = all.withCastling((
        side: Side.white,
        wing: CastlingSide.king,
      ), allowed: false);
      expect(noKingside.fen, 'r3k3/8/8/8/8/8/8/4K2R w q - 0 1');
    });

    test('placing and removing pieces', () {
      final setup = BoardSetup.empty()
          .withPiece(Square.e1, Piece.whiteKing)
          .withPiece(Square.e8, Piece.blackKing)
          .withPiece(Square.d4, Piece.whiteQueen)
          .withPiece(Square.d4, null);
      expect(setup.board.fen, '4k3/8/8/8/8/8/8/4K3');
    });
  });

  group('checkPosition', () {
    PositionProblem? check(String fen) => checkPosition(BoardSetup.fromFen(fen));

    test('a legal position passes', () {
      expect(check(Chess.initial.fen), isNull);
    });

    test('two white kings: names the squares', () {
      final problem = check('4k3/8/8/8/8/8/8/4K1K1 w - - 0 1')!;
      expect(problem.message, 'Each side needs exactly one king. White has two, on e1 and g1.');
      expect(problem.squares, {Square.e1, Square.g1});
    });

    test('a missing king', () {
      expect(check('8/8/8/8/8/8/8/4K3 w - - 0 1')!.message, startsWith('Black has no king'));
    });

    test('pawns on the back rank', () {
      final problem = check('4k2P/8/8/8/8/8/8/4K3 w - - 0 1')!;
      expect(problem.cause, PositionProblemCause.backRankPawns);
      expect(problem.squares, {Square.h8});
    });

    test('too many pieces', () {
      expect(
        check('4k3/8/8/8/QQQQQQQQ/QQQQQQQQ/Q7/4K3 w - - 0 1')!.cause,
        PositionProblemCause.tooManyPieces,
      );
    });

    test('the side not to move is in check', () {
      final problem = check('4k2R/8/8/8/8/8/8/4K3 b - - 0 1');
      expect(problem, isNull, reason: 'Black to move, in check: fine');
      final wrong = check('4k2R/8/8/8/8/8/8/4K3 w - - 0 1')!;
      expect(wrong.cause, PositionProblemCause.wrongCheck);
      expect(wrong.message, startsWith('Black is in check'));
    });
  });

  group('BoardReader', () {
    final photo = Uint8List.fromList([0xFF, 0xD8]);

    test('reads a legal position in one request, with the photo attached', () async {
      final llm = FakeLlm(
        turns: [
          _json(
            _reading(
              unsure: [
                {'row': 7, 'col': 4},
              ],
            ),
          ),
        ],
      );
      final seen = <List<ScanStep>>[];
      final result = await BoardReader(llm).read(photo, onSteps: seen.add);

      expect(result!.setup.fen, Chess.initial.fen);
      expect(result.unsure, {Square.e1});
      expect(llm.requests, hasLength(1));
      expect(llm.requests.single.messages.single.images.single.bytes, photo);
      expect(seen.last.map((s) => s.label), [
        'Finding the board…',
        'Identifying pieces…',
        'Checking the position is legal…',
      ]);
      expect(seen.last.every((s) => s.done), isTrue);
      expect(seen.last[1].detail, '32 pieces · 1 unsure');
    });

    test('Black to move when Black is in check', () async {
      final llm = FakeLlm(
        turns: [
          _json(
            _reading(
              ranks: [
                '....k..R',
                '........',
                '........',
                '........',
                '........',
                '........',
                '........',
                '....K...',
              ],
            ),
          ),
        ],
      );
      final result = await BoardReader(llm).read(photo, onSteps: (_) {});
      expect(result!.setup.turn, Side.black);
    });

    test('an impossible position gets a second look at those squares', () async {
      final twoKings = [..._startRanks.take(7), 'RNBQKBKR'];
      final llm = FakeLlm(
        turns: [
          _json(_reading(ranks: twoKings)),
          _json({
            'cells': [
              {'row': 7, 'col': 4, 'piece': 'K'},
              {'row': 7, 'col': 6, 'piece': 'N'},
            ],
          }),
        ],
      );
      final seen = <List<ScanStep>>[];
      final boxes = <CellBox>[];
      final closeUp = Uint8List.fromList([9, 9]);
      final reader = BoardReader(
        llm,
        crop: (board, box) async {
          boxes.add(box);
          return closeUp;
        },
      );
      final result = await reader.read(photo, onSteps: seen.add);

      expect(result!.setup.fen, Chess.initial.fen);
      expect(llm.requests, hasLength(2));
      // Only e1–g1 and one cell around them, at low resolution.
      expect(boxes.single, (top: 6, left: 3, bottom: 7, right: 7));
      final second = llm.requests.last;
      expect(second.messages.single.images.single.bytes, closeUp);
      expect(second.mediaResolution, LlmMediaResolution.low);
      expect(second.messages.single.text, contains('rows 6–7 and columns 3–7'));
      expect(llm.requests.first.mediaResolution, isNull, reason: 'first look: full detail');
      final last = seen.last;
      expect(last.last.label, 'Double-checking e1 and g1…');
      expect(last.last.retry, isTrue);
      expect(last.last.detail, 'e1 king · g1 knight');
      expect(last[2].detail, 'White looks like it has 2 kings');
      expect(result.unsure, containsAll([Square.e1, Square.g1]));
    });

    test('still impossible after the second look: an illegal failure with the reading', () async {
      final twoKings = [..._startRanks.take(7), 'RNBQKBKR'];
      final llm = FakeLlm(
        turns: [
          _json(_reading(ranks: twoKings)),
          _json({'cells': <Object?>[]}),
        ],
      );
      await expectLater(
        BoardReader(llm).read(photo, onSteps: (_) {}),
        throwsA(
          isA<ScanFailure>().having((f) => f.kind, 'kind', ScanFailureKind.illegal).having(
            (f) => f.result?.problem?.squares,
            'squares',
            {Square.e1, Square.g1},
          ),
        ),
      );
    });

    test('the close-up gives each square at least the first look’s detail', () {
      expect(BoardReader.closeUpOf([(row: 0, col: 0)]), (top: 0, left: 0, bottom: 1, right: 1));
      expect(
        BoardReader.resolutionFor((top: 0, left: 0, bottom: 2, right: 2)),
        LlmMediaResolution.low,
      );
      expect(
        BoardReader.resolutionFor((top: 0, left: 0, bottom: 3, right: 5)),
        LlmMediaResolution.medium,
      );
      expect(BoardReader.resolutionFor(BoardReader.fullBoard), LlmMediaResolution.high);
    });

    test('squares far apart: the whole photo, at its default resolution', () async {
      final llm = FakeLlm(
        turns: [
          _json(
            _reading(
              ranks: [..._startRanks.take(7), 'RNBQKBKR'],
              unsure: [
                {'row': 0, 'col': 0},
              ],
            ),
          ),
          _json({
            'cells': [
              {'row': 7, 'col': 6, 'piece': 'N'},
            ],
          }),
        ],
      );
      var cropped = false;
      await BoardReader(
        llm,
        crop: (b, _) async {
          cropped = true;
          return b;
        },
      ).read(photo, onSteps: (_) {});
      expect(cropped, isFalse);
      expect(llm.requests.last.messages.single.images.single.bytes, photo);
      expect(llm.requests.last.mediaResolution, isNull);
    });

    test('no board, and a dark photo', () async {
      Future<ScanFailureKind> kind(Map<String, Object?> json) async {
        try {
          await BoardReader(FakeLlm(turns: [_json(json)])).read(photo, onSteps: (_) {});
        } on ScanFailure catch (f) {
          return f.kind;
        }
        fail('expected a failure');
      }

      expect(await kind(_reading(found: false, ranks: [])), ScanFailureKind.noBoard);
      expect(await kind(_reading(quality: 'too_dark', ranks: ['...'])), ScanFailureKind.blurry);
    });

    test('AI failures map to the error screens', () async {
      Future<ScanFailureKind> kind(LlmFailure failure) async {
        try {
          await BoardReader(FakeLlm(failure: failure)).read(photo, onSteps: (_) {});
        } on ScanFailure catch (f) {
          return f.kind;
        }
        fail('expected a failure');
      }

      expect(await kind(const LlmOffline()), ScanFailureKind.offline);
      expect(await kind(const LlmMissingKey()), ScanFailureKind.noKey);
      expect(await kind(const LlmInvalidKey()), ScanFailureKind.invalidKey);
      expect(await kind(const LlmRateLimited()), ScanFailureKind.limit);
      expect(await kind(const LlmUnavailable()), ScanFailureKind.failed);
    });

    test('a reply that is not JSON fails', () async {
      await expectLater(
        BoardReader(FakeLlm(reply: 'not json')).read(photo, onSteps: (_) {}),
        throwsA(isA<ScanFailure>().having((f) => f.kind, 'kind', ScanFailureKind.failed)),
      );
    });

    test('a cancelled scan stops quietly', () async {
      final result = await BoardReader(
        FakeLlm(turns: [_json(_reading())]),
      ).read(photo, onSteps: (_) {}, isCancelled: () => true);
      expect(result, isNull);
    });
  });
}
