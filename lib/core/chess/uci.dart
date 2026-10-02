// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:dartchess/dartchess.dart';

/// [text] as a UCI move (`e2e4`, `e7e8q`), or null if it isn't one.
///
/// Use instead of `Move.parse`, which throws a RangeError on text shorter
/// than two characters (an empty best move turned the review page blank).
Move? parseUci(String? text) {
  if (text == null || text.length < 4 || text.length > 5) return null;
  return Move.parse(text);
}
