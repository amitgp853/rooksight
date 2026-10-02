# Contributing to Rooksight

Thank you for wanting to help. Bug reports and ideas are welcome as
[issues](https://github.com/amitgp853/rooksight/issues).

## Contributor License Agreement

Contributions are accepted **only under the
[Contributor License Agreement](CLA.md)**. It lets the maintainer, Amit Gupta,
relicense your contribution. You keep your copyright.

To agree, tick the CLA box in the pull request description (the
[template](.github/pull_request_template.md) has it). Pull requests without
the ticked box can't be merged.

## Before you open a pull request

- Run `flutter analyze` and `flutter test`. Both must pass.
- New source files need the licence header. Add it with
  `dart run tool/license_headers.dart`, or check with `--check`:

  ```dart
  // Copyright (C) 2026 Amit Gupta
  // SPDX-License-Identifier: GPL-3.0-or-later
  ```

- Ask in an issue before adding a dependency. It must be compatible with
  GPL-3.0.
- Don't change the logo, app icon or splash files. They are not under the GPL
  (see [TRADEMARKS.md](TRADEMARKS.md)).
- Never commit API keys, `.env` files or other secrets.
