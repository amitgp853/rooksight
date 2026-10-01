import 'package:rooksight/core/storage/import_log.dart';
import 'package:rooksight/features/import/data/chess_com_api.dart';
import 'package:rooksight/features/import/data/chess_com_models.dart';

import '../features/import/chess_com_fixtures.dart';

ArchiveMonth month(int year, int m) => ArchiveMonth.fromUrl(
  'https://api.chess.com/pub/player/fan/games/$year/${m.toString().padLeft(2, '0')}',
)!;

ChessComGame game(String id, {String rules = 'chess'}) => ChessComGame.fromJson(
  chessComGame(url: 'https://www.chess.com/game/live/$id', rules: rules, white: 'fan'),
);

class FakeChessCom implements ChessComApi {
  FakeChessCom(this.months, {this.failure, this.unchanged = const {}});

  /// Games per month key.
  final Map<String, List<ChessComGame>> months;

  /// Months that are listed but answer "not modified".
  final Set<String> unchanged;
  final ImportFailure? failure;
  final fetched = <String>[];
  final etagsSent = <String?>[];

  @override
  Future<void> checkPlayer(String username) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<List<ArchiveMonth>> archives(String username) async => [
    for (final key in {...months.keys, ...unchanged})
      month(int.parse(key.split('/')[0]), int.parse(key.split('/')[1])),
  ]..sort();

  @override
  Future<MonthGames> monthGames(ArchiveMonth month, {String? etag}) async {
    fetched.add(month.key);
    etagsSent.add(etag);
    final games = months[month.key];
    return games == null
        ? MonthGames.notModified(etag: etag)
        : MonthGames(games, etag: 'etag-${month.key}');
  }
}

class FakeImportLog implements ImportLog {
  final months = <String, ImportedMonth>{};

  @override
  Future<ImportedMonth?> get(String username, String month) async => months[month];

  @override
  Future<void> record(String username, String month, ImportedMonth imported) async =>
      months[month] = imported;
}
