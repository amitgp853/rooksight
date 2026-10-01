// Renders the Rooksight piece set from `design/pieces/*.svg` to the PNGs that
// chessground needs (it only accepts raster images).
//
// Run from the project root whenever the SVGs change:
//
//   flutter test tool/render_pieces.dart
//
// It runs as a test because that gives us Flutter's renderer without a device.
// Output: assets/pieces/{,2.0x/,3.0x/}<piece>.png, where 1x = 128 px.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Size of one board square at 1x, in pixels.
const _baseSize = 128;
const _scales = [1, 2, 3];

/// The design draws pieces at 90% of the square, centred.
const _pieceFraction = 0.9;

// Drop shadow from the spec: `0 1.5px 1.5px rgba(0,0,0,0.35)` on a 48.75 px
// square. CSS blur radius is twice the Gaussian sigma.
const _designSquare = 48.75;
const _shadowOffsetY = 1.5 / _designSquare;
const _shadowSigma = 0.75 / _designSquare;
const _shadowColor = Color(0x59000000);

void main() {
  test('render piece PNGs', () async {
    final sources = Directory(
      'design/pieces',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList();
    expect(sources, hasLength(12));

    for (final source in sources) {
      final name = source.uri.pathSegments.last.replaceAll('.svg', '');
      final svg = strokeBehindFill(source.readAsStringSync());
      final picture = await vg.loadPicture(SvgStringLoader(svg), null);

      for (final scale in _scales) {
        final size = _baseSize * scale;
        final bytes = await _render(picture, size);
        final dir = scale == 1 ? 'assets/pieces' : 'assets/pieces/$scale.0x';
        Directory(dir).createSync(recursive: true);
        File('$dir/$name.png').writeAsBytesSync(bytes);
      }
      picture.picture.dispose();
    }
  });
}

/// flutter_svg ignores `paint-order="stroke"`, so split each such path into a
/// stroke-only copy drawn first and a fill-only copy drawn on top. That keeps
/// only the outer half of the outline visible, as the design intends.
String strokeBehindFill(String svg) {
  final path = RegExp(
    r'<path d="([^"]+)" fill="([^"]+)" stroke="([^"]+)" stroke-width="([^"]+)" '
    r'stroke-linejoin="round" paint-order="stroke"/>',
  );
  final result = svg.replaceAllMapped(
    path,
    (m) =>
        '<path d="${m[1]}" fill="none" stroke="${m[3]}" stroke-width="${m[4]}" '
        'stroke-linejoin="round"/><path d="${m[1]}" fill="${m[2]}"/>',
  );
  if (result.contains('paint-order')) {
    throw StateError('Unexpected SVG structure; update strokeBehindFill.');
  }
  return result;
}

Future<List<int>> _render(PictureInfo picture, int size) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final pieceSize = size * _pieceFraction;
  final inset = (size - pieceSize) / 2;
  final scale = pieceSize / picture.size.width;

  void drawPiece() {
    canvas
      ..save()
      ..translate(inset, inset)
      ..scale(scale)
      ..drawPicture(picture.picture)
      ..restore();
  }

  // Shadow: the piece's silhouette, tinted, blurred and offset down.
  final sigma = _shadowSigma * size;
  canvas
    ..save()
    ..translate(0, _shadowOffsetY * size)
    ..saveLayer(
      null,
      Paint()
        ..colorFilter = const ColorFilter.mode(_shadowColor, BlendMode.srcIn)
        ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
    );
  drawPiece();
  canvas
    ..restore()
    ..restore();

  drawPiece();

  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
