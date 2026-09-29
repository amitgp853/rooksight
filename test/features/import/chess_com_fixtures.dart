/// A Chess.com archive game as the API returns it (trimmed to the fields
/// MoveWise reads). The PGN carries clock comments, as real ones do.
Map<String, Object?> chessComGame({
  String url = 'https://www.chess.com/game/live/100',
  String rules = 'chess',
  String white = 'MoveWiseFan',
  String black = 'opponent42',
  String whiteResult = 'checkmated',
  String blackResult = 'win',
  String timeControl = '180+2',
  String timeClass = 'blitz',
  int endTime = 1759000000,
  String? pgn,
}) => {
  'url': url,
  'pgn':
      pgn ??
      '[Event "Live Chess"]\n[Site "Chess.com"]\n[White "$white"]\n[Black "$black"]\n'
          '[Result "0-1"]\n\n1. f3 {[%clk 0:02:59.9]} 1... e5 {[%clk 0:02:59.8]} '
          '2. g4 {[%clk 0:02:58]} 2... Qh4# {[%clk 0:02:57]} 0-1\n',
  'time_control': timeControl,
  'end_time': endTime,
  'rated': true,
  'time_class': timeClass,
  'rules': rules,
  'white': {'rating': 1510, 'result': whiteResult, 'username': white},
  'black': {'rating': 1544, 'result': blackResult, 'username': black},
};
