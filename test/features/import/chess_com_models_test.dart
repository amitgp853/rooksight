import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/storage/game_repository.dart';
import 'package:rooksight/features/import/data/chess_com_models.dart';

import 'chess_com_fixtures.dart';

void main() {
  group('toRecord', () {
    test('maps a lost blitz game from the player’s side', () {
      final record = ChessComGame.fromJson(chessComGame()).toRecord('rooksightfan')!;

      expect(record.source, GameSource.chesscom);
      expect(record.externalId, 'https://www.chess.com/game/live/100');
      expect(record.playerSide, Side.white);
      expect(record.result, '0-1');
      expect(record.outcome, PlayerOutcome.loss);
      expect(record.endReason, 'checkmate');
      expect(record.opponentName, 'opponent42');
      expect(record.opponentRating, 1544);
      expect(record.playerRating, 1510);
      expect(record.timeClass, 'blitz');
      expect(record.timeControl, '180+2');
      expect(record.plyCount, 4);
      expect(record.endedAt, DateTime.fromMillisecondsSinceEpoch(1759000000000, isUtc: true));
    });

    test('finds the player on the black side, case-insensitively', () {
      final record = ChessComGame.fromJson(chessComGame()).toRecord('OPPONENT42')!;
      expect(record.playerSide, Side.black);
      expect(record.outcome, PlayerOutcome.win);
    });

    test('maps draw codes', () {
      for (final (code, reason) in [
        ('agreed', 'agreement'),
        ('repetition', 'threefoldRepetition'),
        ('stalemate', 'stalemate'),
        ('insufficient', 'insufficientMaterial'),
        ('50move', 'fiftyMoveRule'),
        ('timevsinsufficient', 'timeout'),
      ]) {
        final json = chessComGame(whiteResult: code, blackResult: code);
        final record = ChessComGame.fromJson(json).toRecord('rooksightfan')!;
        expect(record.result, '1/2-1/2', reason: code);
        expect(record.endReason, reason, reason: code);
      }
    });

    test('bare seconds become a +0 time control', () {
      final json = chessComGame(timeControl: '600', timeClass: 'rapid');
      expect(ChessComGame.fromJson(json).toRecord('rooksightfan')!.timeControl, '600+0');
    });

    test('skips variants, other people’s games and games without moves', () {
      expect(
        ChessComGame.fromJson(chessComGame(rules: 'chess960')).toRecord('rooksightfan'),
        isNull,
      );
      expect(ChessComGame.fromJson(chessComGame()).toRecord('someone_else'), isNull);
      final empty = chessComGame(pgn: '[Result "*"]\n\n*');
      expect(ChessComGame.fromJson(empty).toRecord('rooksightfan'), isNull);
    });
  });

  group('ArchiveMonth', () {
    test('parses archive URLs and sorts by date', () {
      final months = [
        ArchiveMonth.fromUrl('https://api.chess.com/pub/player/x/games/2026/03')!,
        ArchiveMonth.fromUrl('https://api.chess.com/pub/player/x/games/2025/12')!,
      ]..sort();
      expect(months.map((m) => m.key), ['2025/12', '2026/03']);
    });

    test('rejects other URLs', () {
      expect(ArchiveMonth.fromUrl('https://api.chess.com/pub/player/x'), isNull);
    });
  });
}
