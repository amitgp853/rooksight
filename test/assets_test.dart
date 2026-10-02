// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/render_pieces.dart' show strokeBehindFill;

void main() {
  const pieces = ['K', 'Q', 'R', 'B', 'N', 'P'];

  test('all 12 pieces are rendered at every scale', () {
    for (final dir in ['assets/pieces', 'assets/pieces/2.0x', 'assets/pieces/3.0x']) {
      for (final colour in ['w', 'b']) {
        for (final piece in pieces) {
          final path = '$dir/$colour$piece.png';
          expect(File(path).existsSync(), isTrue, reason: '$path missing: run tool/render_pieces');
        }
      }
    }
  });

  // flutter_svg ignores paint-order, so the renderer must split the outline
  // into its own path drawn before the fill.
  test('strokeBehindFill removes paint-order from every design piece', () {
    for (final file in Directory('design/pieces').listSync().whereType<File>()) {
      final svg = strokeBehindFill(file.readAsStringSync());
      expect(svg, isNot(contains('paint-order')), reason: file.path);
    }
  });

  test('bundled fonts are named the way google_fonts looks them up', () {
    for (final name in [
      'Sora-SemiBold',
      'InstrumentSans-Regular',
      'InstrumentSans-Medium',
      'InstrumentSans-SemiBold',
      'JetBrainsMono-Medium',
    ]) {
      expect(File('assets/google_fonts/$name.ttf').existsSync(), isTrue, reason: name);
    }
  });
}
