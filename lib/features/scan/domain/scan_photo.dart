import 'dart:math' as math;
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// A photo ready to show and crop: upright (camera orientation applied), at
/// most [maxSide] pixels on its long side, JPEG-encoded, with its size.
@immutable
class ScanPhoto {
  const ScanPhoto({required this.bytes, required this.width, required this.height});

  final Uint8List bytes;
  final int width;
  final int height;

  /// Plenty for cropping by eye; keeps rotating quick.
  static const maxSide = 2048;

  /// What the model reads: a square this size is enough for 64 squares and
  /// keeps the request small.
  static const scanSide = 1024;

  /// [raw] (a camera or gallery file) made upright and not too large. Returns
  /// null if it isn't an image.
  static Future<ScanPhoto?> fromBytes(Uint8List raw) => compute(_normalize, raw);

  /// Turned by a quarter turn to the right ([clockwise]) or the left.
  Future<ScanPhoto> rotated({required bool clockwise}) =>
      compute(_rotate, (bytes, clockwise ? 90 : -90));

  /// The part inside [crop] (fractions of the width and height), as a
  /// [scanSide]-pixel JPEG for the model.
  Future<Uint8List> crop(Rect crop) => compute(_crop, (bytes, crop));

  /// A close-up of [cells] of [board] (a photo cropped to the 64 squares),
  /// for a second look at a few squares.
  static Future<Uint8List> cropCells(Uint8List board, CellBox cells) {
    final rect = Rect.fromLTRB(
      cells.left / 8,
      cells.top / 8,
      (cells.right + 1) / 8,
      (cells.bottom + 1) / 8,
    );
    return compute(_crop, (board, rect));
  }
}

/// A block of board cells in the photo's grid, inclusive: row 0 is the top
/// of the photo, column 0 its left.
typedef CellBox = ({int top, int left, int bottom, int right});

ScanPhoto? _normalize(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  var image = img.bakeOrientation(decoded);
  final long = math.max(image.width, image.height);
  if (long > ScanPhoto.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: ScanPhoto.maxSide)
        : img.copyResize(image, height: ScanPhoto.maxSide);
  }
  return _encode(image);
}

ScanPhoto _rotate((Uint8List, num) args) {
  final (bytes, angle) = args;
  return _encode(img.copyRotate(img.decodeJpg(bytes)!, angle: angle));
}

Uint8List _crop((Uint8List, Rect) args) {
  final (bytes, crop) = args;
  final image = img.decodeJpg(bytes)!;
  final x = (crop.left * image.width).round().clamp(0, image.width - 1);
  final y = (crop.top * image.height).round().clamp(0, image.height - 1);
  final w = (crop.width * image.width).round().clamp(1, image.width - x);
  final h = (crop.height * image.height).round().clamp(1, image.height - y);
  var cut = img.copyCrop(image, x: x, y: y, width: w, height: h);
  if (math.max(cut.width, cut.height) > ScanPhoto.scanSide) {
    cut = img.copyResize(
      cut,
      width: ScanPhoto.scanSide,
      height: (ScanPhoto.scanSide * cut.height / cut.width).round(),
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(cut, quality: 85);
}

ScanPhoto _encode(img.Image image) =>
    ScanPhoto(bytes: img.encodeJpg(image, quality: 88), width: image.width, height: image.height);
