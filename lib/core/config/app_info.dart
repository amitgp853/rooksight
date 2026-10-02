// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

/// Public facts about the app, used where services ask who is calling.
abstract final class AppInfo {
  static const name = 'Rooksight';
  static const version = '0.1.0';

  /// Where the Chess.com API team can find the developer.
  static const contactUrl = 'https://github.com/amitgp853/rooksight';

  /// The full source, linked from Settings → About, as the GPL asks.
  static const sourceUrl = 'https://github.com/amitgp853/rooksight';

  static const copyrightHolder = 'Amit Gupta';
  static const copyrightYear = 2026;
  static const license = 'GPL-3.0';

  /// Where people can support the developer, linked from Settings.
  static const kofiUrl = 'https://ko-fi.com/amitgp853';

  /// Settings changed without a release: the newest build, the oldest one
  /// allowed, and the Gemini models. Edit `config/remote.json` on `main`;
  /// phones pick it up within an hour or so (GitHub caches it for minutes).
  static const remoteConfigUrl =
      'https://raw.githubusercontent.com/amitgp853/rooksight/main/config/remote.json';

  /// The store page, when `remote.json` doesn't give one.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.amitgp853.rooksight';

  /// Sent with every Chess.com request, as their API guidelines ask.
  static const userAgent = '$name/$version (+$contactUrl)';
}
