/// Why talking to Chess.com or Lichess failed.
sealed class ImportFailure implements Exception {
  const ImportFailure();
}

class PlayerNotFound extends ImportFailure {
  const PlayerNotFound(this.username);
  final String username;
}

/// Still rate-limited (HTTP 429) after waiting.
class RateLimited extends ImportFailure {
  const RateLimited();
}

/// No connection, or the request timed out.
class Offline extends ImportFailure {
  const Offline();
}

/// The service answered with an unexpected status (e.g. 5xx) or bad data.
class ServiceUnavailable extends ImportFailure {
  const ServiceUnavailable([this.statusCode]);
  final int? statusCode;
}
