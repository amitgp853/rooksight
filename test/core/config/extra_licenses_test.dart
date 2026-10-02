// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rooksight/core/config/extra_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Stockfish and the bundled fonts are on the licence page', () async {
    registerExtraLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    String textFor(String package) => entries
        .firstWhere((entry) => entry.packages.contains(package))
        .paragraphs
        .map((paragraph) => paragraph.text)
        .join('\n');

    expect(textFor('Stockfish'), contains('The Stockfish developers'));
    expect(textFor('Stockfish'), contains('GNU GENERAL PUBLIC LICENSE'));
    for (final font in ['Sora', 'Instrument Sans', 'JetBrains Mono']) {
      expect(textFor(font), contains('SIL Open Font License'), reason: font);
    }
  });
}
