/// Public facts about the app, used where services ask who is calling.
abstract final class AppInfo {
  static const name = 'MoveWise';
  static const version = '0.1.0';

  /// Where the Chess.com API team can find the developer.
  static const contactUrl = 'https://github.com/amitgp853/move_wise';

  /// Sent with every Chess.com request, as their API guidelines ask.
  static const userAgent = '$name/$version (+$contactUrl)';
}
