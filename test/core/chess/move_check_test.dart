import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/chess/move_check.dart';

Position fen(String fen) => Chess.fromSetup(Setup.parseFen(fen));

void main() {
  group('movesIn', () {
    test('finds piece moves, captures, castling and promotions', () {
      expect(MoveCheck.movesIn('After 23. Nxd5 exd5 you castled with O-O, then Rxd8+ and b8=Q#.'), {
        'Nxd5',
        'exd5',
        'O-O',
        'Rxd8',
        'b8=Q',
      });
    });

    test('a pawn push counts only with a move number', () {
      expect(MoveCheck.movesIn('The d5 square was weak.'), isEmpty);
      expect(MoveCheck.movesIn('23. d5 was better, as was 23…e5.'), {'d5', 'e5'});
    });

    test('ordinary words are not moves', () {
      expect(MoveCheck.movesIn('Be careful: Queens and Knights matter.'), isEmpty);
    });
  });

  test('legalSans lists every legal move, without check marks', () {
    final sans = MoveCheck.legalSans(Chess.initial);
    expect(sans, hasLength(20));
    expect(sans, containsAll(['e4', 'Nf3', 'Na3']));
  });

  test('promotions are listed for every piece', () {
    final sans = MoveCheck.legalSans(fen('8/1P4k1/8/8/8/8/6K1/8 w - - 0 1'));
    expect(sans, containsAll(['b8=Q', 'b8=R', 'b8=B', 'b8=N']));
  });

  group('keepChecked', () {
    final allowed = {'Nxd5', 'Rd1', 'exd5'};

    test('keeps sentences whose moves are allowed', () {
      expect(
        MoveCheck.keepChecked('Nxd5 lost a knight. Rd1 kept the pressure.', allowed),
        'Nxd5 lost a knight. Rd1 kept the pressure.',
      );
    });

    test('drops sentences with invented moves', () {
      expect(
        MoveCheck.keepChecked(
          'Nxd5 lost a knight. Qh5 would have won instantly. Rd1 was calm.',
          allowed,
        ),
        'Nxd5 lost a knight. Rd1 was calm.',
      );
    });

    test('returns nothing when every sentence is invented', () {
      expect(MoveCheck.keepChecked('Qh5 wins. Bb5 too!', allowed), '');
    });

    test('squares alone never cause a drop', () {
      expect(MoveCheck.keepChecked('The d5 square was defended twice.', allowed), isNotEmpty);
    });
  });
}
