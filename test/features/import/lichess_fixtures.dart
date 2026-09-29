/// A Lichess export game as the API returns it with `pgnInJson` and
/// `opening` (trimmed to the fields MoveWise reads).
Map<String, Object?> lichessGame({
  String id = 'abcd1234',
  String variant = 'standard',
  String speed = 'blitz',
  String status = 'mate',
  String? winner = 'black',
  String white = 'MoveWiseFan',
  String? black = 'opponent42',
  int? blackAiLevel,
  int createdAt = 1759000000000,
  int? clockInitial = 180,
  int clockIncrement = 2,
  String? pgn,
}) => {
  'id': id,
  'rated': true,
  'variant': variant,
  'speed': speed,
  'perf': speed,
  'createdAt': createdAt,
  'lastMoveAt': createdAt + 60000,
  'status': status,
  'winner': ?winner,
  'players': {
    'white': {
      'user': {'name': white, 'id': white.toLowerCase()},
      'rating': 1650,
    },
    'black': black == null
        ? {'aiLevel': blackAiLevel ?? 3}
        : {
            'user': {'name': black, 'id': black.toLowerCase()},
            'rating': 1702,
          },
  },
  'opening': {'eco': 'A00', 'name': 'Barnes Opening', 'ply': 1},
  if (clockInitial != null) 'clock': {'initial': clockInitial, 'increment': clockIncrement},
  'pgn':
      pgn ??
      '[Event "Rated blitz game"]\n[Site "https://lichess.org/$id"]\n[White "$white"]\n'
          '[Black "${black ?? 'lichess AI level 3'}"]\n[Result "0-1"]\n'
          '[Opening "Barnes Opening: Fool\'s Mate"]\n\n1. f3 e5 2. g4 Qh4# 0-1\n',
};
