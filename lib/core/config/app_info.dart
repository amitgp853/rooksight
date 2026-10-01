/// Public facts about the app, used where services ask who is calling.
abstract final class AppInfo {
  static const name = 'MoveWise';
  static const version = '0.1.0';

  /// Where the Chess.com API team can find the developer.
  static const contactUrl = 'https://github.com/amitgp853/move_wise';

  /// Where people can support the developer, linked from Settings.
  static const kofiUrl = 'https://ko-fi.com/amitgp853';

  /// Settings changed without a release: the newest build, the oldest one
  /// allowed, and the Gemini models. Edit `config/remote.json` on `main`;
  /// phones pick it up within an hour or so (GitHub caches it for minutes).
  static const remoteConfigUrl =
      'https://raw.githubusercontent.com/amitgp853/move_wise/main/config/remote.json';

  /// The store page, when `remote.json` doesn't give one.
  static const playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.amitgp853.movewise';

  /// Sent with every Chess.com request, as their API guidelines ask.
  static const userAgent = '$name/$version (+$contactUrl)';
}
