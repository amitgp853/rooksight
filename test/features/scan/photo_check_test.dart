import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:move_wise/features/scan/domain/photo_check.dart';

/// A board [size] pixels wide: squares in [light] / [dark], with round
/// "pieces" on [pieces] of them.
img.Image board({
  int size = 800,
  int light = 225,
  int dark = 120,
  int pieces = 32,
  int seed = 1,
  int margin = 0,
}) {
  final image = img.Image(width: size + 2 * margin, height: size + 2 * margin);
  img.fill(image, color: img.ColorRgb8(90, 70, 50));
  final cell = size / 8;
  final random = Random(seed);
  final occupied = ({for (var i = 0; i < pieces; i++) random.nextInt(64)}).toSet();
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      final v = (r + c).isEven ? light : dark;
      img.fillRect(
        image,
        x1: (margin + c * cell).round(),
        y1: (margin + r * cell).round(),
        x2: (margin + (c + 1) * cell).round() - 1,
        y2: (margin + (r + 1) * cell).round() - 1,
        color: img.ColorRgb8(v, v, v - 10),
      );
      if (occupied.contains(r * 8 + c)) {
        final shade = random.nextBool() ? 245 : 25;
        img.fillCircle(
          image,
          x: (margin + (c + 0.5) * cell).round(),
          y: (margin + (r + 0.5) * cell).round(),
          radius: (cell * 0.36).round(),
          color: img.ColorRgb8(shade, shade, shade),
        );
      }
    }
  }
  return image;
}

void main() {
  test('a board with pieces looks like a board, sharp and bright enough', () {
    final check = PhotoCheck.ofImage(board());
    expect(check.looksLikeBoard, isTrue, reason: 'score ${check.boardScore}');
    expect(check.tooBlurry, isFalse, reason: 'sharpness ${check.sharpness}');
    expect(check.tooDark, isFalse);
  });

  test('a book diagram (flat, high contrast, crowded) looks like a board', () {
    final check = PhotoCheck.ofImage(board(light: 255, dark: 170, pieces: 40, seed: 3));
    expect(check.looksLikeBoard, isTrue, reason: 'score ${check.boardScore}');
  });

  test('a loosely cropped board still passes', () {
    // A little table around the board, as a quick crop leaves.
    final check = PhotoCheck.ofImage(img.copyResize(board(margin: 30), width: 800, height: 800));
    expect(check.looksLikeBoard, isTrue, reason: 'score ${check.boardScore}');
  });

  test('a heavily blurred board is too blurry', () {
    final check = PhotoCheck.ofImage(img.gaussianBlur(board(size: 400), radius: 12));
    expect(check.tooBlurry, isTrue, reason: 'sharpness ${check.sharpness}');
  });

  test('a photo taken in the dark is too dark', () {
    final dim = img.adjustColor(board(), brightness: 0.08);
    final check = PhotoCheck.ofImage(dim);
    expect(check.tooDark, isTrue, reason: 'brightness ${check.brightness}');
  });

  test('random 8 × 8 tiles rarely pass for a board (no false alarms)', () {
    var passed = 0;
    for (var seed = 0; seed < 100; seed++) {
      final random = Random(seed);
      final tiles = img.Image(width: 256, height: 256);
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final v = random.nextInt(256);
          img.fillRect(
            tiles,
            x1: c * 32,
            y1: r * 32,
            x2: c * 32 + 31,
            y2: r * 32 + 31,
            color: img.ColorRgb8(v, v, v),
          );
        }
      }
      if (PhotoCheck.ofImage(tiles).looksLikeBoard) passed++;
    }
    expect(passed, lessThanOrEqualTo(3));
  });

  test('noise, a gradient and random tiles are not boards', () {
    final random = Random(7);
    final noise = img.Image(width: 400, height: 400);
    for (final p in noise) {
      final v = random.nextInt(256);
      p.setRgb(v, v, v);
    }
    final gradient = img.Image(width: 400, height: 400);
    for (final p in gradient) {
      final v = (p.x * 255 / 399).round();
      p.setRgb(v, v, v);
    }
    final tiles = img.Image(width: 400, height: 400);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final v = random.nextInt(256);
        img.fillRect(
          tiles,
          x1: c * 50,
          y1: r * 50,
          x2: c * 50 + 49,
          y2: r * 50 + 49,
          color: img.ColorRgb8(v, v, v),
        );
      }
    }
    final plain = img.Image(width: 400, height: 400);
    img.fill(plain, color: img.ColorRgb8(180, 170, 160));

    for (final (name, image) in [
      ('noise', noise),
      ('gradient', gradient),
      ('tiles', tiles),
      ('plain', plain),
    ]) {
      final check = PhotoCheck.ofImage(image);
      expect(check.looksLikeBoard, isFalse, reason: '$name score ${check.boardScore}');
    }
  });
}
