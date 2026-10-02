// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

/// Adds the copyright and licence header to every source file that lacks it.
///
///     dart run tool/license_headers.dart          # add missing headers
///     dart run tool/license_headers.dart --check  # list them, exit 1 if any
///
/// Covers the .dart files in lib/, test/ and tool/, and the Python files in
/// tool/. Generated files (*.g.dart, or marked "GENERATED CODE") are skipped.
library;

import 'dart:io';

const holder = 'Amit Gupta';
const year = 2026;
const spdx = 'GPL-3.0-or-later';

const _dartRoots = ['lib', 'test', 'tool'];
const _pythonRoots = ['tool'];

/// The header lines for a file, with [comment] as the line prefix.
List<String> headerLines(String comment) => [
  '$comment Copyright (C) $year $holder',
  '$comment SPDX-License-Identifier: $spdx',
];

/// Whether [content] is generated and must be left alone.
bool isGenerated(String path, String content) =>
    path.endsWith('.g.dart') || content.startsWith('// GENERATED CODE');

/// Whether [content] already has the SPDX line in its first few lines.
bool hasHeader(String content) =>
    content.split('\n').take(5).any((line) => line.contains('SPDX-License-Identifier:'));

/// [content] with the header on top: after a shebang, if there is one.
String withHeader(String content, {required bool python}) {
  if (hasHeader(content)) return content;
  final header = '${headerLines(python ? '#' : '//').join('\n')}\n\n';
  if (content.startsWith('#!')) {
    final end = content.indexOf('\n') + 1;
    return content.substring(0, end) + header + content.substring(end);
  }
  return header + content;
}

/// Every source file the header belongs in, as relative paths.
Iterable<File> sourceFiles() sync* {
  Iterable<File> filesIn(String root, String extension) => Directory(root).existsSync()
      ? Directory(
          root,
        ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith(extension))
      : const [];

  for (final root in _dartRoots) {
    yield* filesIn(root, '.dart');
  }
  for (final root in _pythonRoots) {
    yield* filesIn(root, '.py');
  }
}

void main(List<String> args) {
  final check = args.contains('--check');
  final missing = <String>[];
  for (final file in sourceFiles()) {
    final content = file.readAsStringSync();
    if (isGenerated(file.path, content) || hasHeader(content)) continue;
    missing.add(file.path);
    if (!check) {
      file.writeAsStringSync(withHeader(content, python: file.path.endsWith('.py')));
    }
  }

  missing.sort();
  if (check) {
    for (final path in missing) {
      stdout.writeln('Missing licence header: $path');
    }
    if (missing.isNotEmpty) {
      stdout.writeln('Run: dart run tool/license_headers.dart');
      exitCode = 1;
    }
  } else {
    stdout.writeln('Added the header to ${missing.length} file(s).');
  }
}
