// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds the licences Flutter doesn't collect from packages to the licence page
/// (Settings → About → Licences): Stockfish's GPL-3.0 and the bundled fonts' OFL.
/// The texts load only when that page opens.
void registerExtraLicenses() {
  LicenseRegistry.addLicense(() async* {
    // The repo's LICENSE is the unmodified GPL-3.0 text, which Stockfish uses too.
    final gpl = await rootBundle.loadString('LICENSE');
    yield LicenseEntryWithLineBreaks(
      const ['Stockfish'],
      'Stockfish, a UCI chess playing engine derived from Glaurung 2.1\n'
      'Copyright (C) 2004-2023 The Stockfish developers (see AUTHORS file)\n'
      'https://stockfishchess.org\n\n'
      '$gpl',
    );
    for (final (font, file) in _fonts) {
      yield LicenseEntryWithLineBreaks([font], await rootBundle.loadString(file));
    }
  });
}

const _fonts = [
  ('Sora', 'assets/google_fonts/OFL-sora.txt'),
  ('Instrument Sans', 'assets/google_fonts/OFL-instrumentsans.txt'),
  ('JetBrains Mono', 'assets/google_fonts/OFL-jetbrainsmono.txt'),
];
