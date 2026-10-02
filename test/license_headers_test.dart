// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/license_headers.dart';

void main() {
  test('adds the Dart header on top', () {
    expect(
      withHeader('void main() {}\n', python: false),
      '// Copyright (C) 2026 Amit Gupta\n'
      '// SPDX-License-Identifier: GPL-3.0-or-later\n'
      '\n'
      'void main() {}\n',
    );
  });

  test('adds the Python header below a shebang', () {
    expect(
      withHeader('#!/usr/bin/env python3\nprint(1)\n', python: true),
      '#!/usr/bin/env python3\n'
      '# Copyright (C) 2026 Amit Gupta\n'
      '# SPDX-License-Identifier: GPL-3.0-or-later\n'
      '\n'
      'print(1)\n',
    );
  });

  test('leaves a file that has the header unchanged', () {
    final once = withHeader('void main() {}\n', python: false);
    expect(withHeader(once, python: false), once);
  });

  test('skips generated files', () {
    expect(isGenerated('lib/a.g.dart', ''), isTrue);
    expect(isGenerated('lib/a.dart', '// GENERATED CODE - DO NOT MODIFY BY HAND\n'), isTrue);
    expect(isGenerated('lib/a.dart', 'void main() {}\n'), isFalse);
  });

  test('every source file has the header (run tool/license_headers.dart)', () {
    final missing = [
      for (final file in sourceFiles())
        if (!isGenerated(file.path, file.readAsStringSync()) && !hasHeader(file.readAsStringSync()))
          file.path,
    ];
    expect(missing, isEmpty);
  });

  test('the header names the same holder and licence as NOTICE', () {
    final notice = File('NOTICE').readAsStringSync();
    expect(notice, contains('Copyright (C) $year $holder'));
    expect(notice, contains(spdx));
  });
}
