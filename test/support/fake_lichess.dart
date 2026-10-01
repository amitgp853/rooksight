import 'package:rooksight/features/import/data/import_failure.dart';
import 'package:rooksight/features/import/data/lichess_api.dart';
import 'package:rooksight/features/import/data/lichess_models.dart';

/// A [LichessApi] for tests: [played] newest first, filtered by `since` on
/// their creation time, as Lichess does.
class FakeLichess implements LichessApi {
  FakeLichess(this.played, {this.failure});

  final List<LichessGame> played;
  final ImportFailure? failure;
  final sinceAsked = <DateTime?>[];

  @override
  Future<void> checkPlayer(String username) async {
    if (failure != null) throw failure!;
  }

  @override
  Stream<LichessGame> games(String username, {DateTime? since}) async* {
    sinceAsked.add(since);
    for (final game in played) {
      if (since != null && game.createdAt.isBefore(since)) continue;
      yield game;
    }
  }
}
