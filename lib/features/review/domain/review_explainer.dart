import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/chess/move_check.dart';
import '../../../core/llm/llm_client.dart';
import '../../../core/storage/game_repository.dart';
import '../../stats/domain/player_stats.dart' show namedOpening;
import 'game_analysis.dart';
import 'moment_facts.dart';
import 'move_review.dart';

/// The AI's words for one key moment, after the checks.
@immutable
class MomentExplanation {
  const MomentExplanation({required this.title, required this.explanation, this.lesson});

  final String title;
  final String explanation;

  /// A principle to remember, with no specific moves.
  final String? lesson;
}

/// What one AI call returns for a game.
@immutable
class ReviewExplanations {
  const ReviewExplanations({
    required this.verdict,
    required this.moments,
    this.summary,
    this.focus = const [],
  });

  /// One line for the report card.
  final String? verdict;

  /// Two or three sentences on how the game went.
  final String? summary;

  /// Up to three things to work on, as general advice.
  final List<String> focus;

  /// Explanations by move index.
  final Map<int, MomentExplanation> moments;

  Map<String, Object?> toJson() => {
    'verdict': verdict,
    'summary': summary,
    'focus': focus,
    'moments': [
      for (final MapEntry(key: index, value: m) in moments.entries)
        {'id': index, 'title': m.title, 'explanation': m.explanation, 'lesson': m.lesson},
    ],
  };

  /// Reads a saved or freshly generated answer. Older saves without
  /// `summary`, `focus` or `lesson` still load.
  factory ReviewExplanations.fromJson(Map<String, Object?> json) => ReviewExplanations(
    verdict: json['verdict'] as String?,
    summary: json['summary'] as String?,
    focus: [...?(json['focus'] as List<Object?>?)?.whereType<String>()],
    moments: {
      for (final m
          in (json['moments'] as List<Object?>? ?? const []).whereType<Map<String, Object?>>())
        if (m['id'] is int)
          m['id']! as int: MomentExplanation(
            title: m['title'] as String? ?? '',
            explanation: m['explanation'] as String? ?? '',
            lesson: m['lesson'] as String?,
          ),
    },
  );
}

/// Explains a game's key moments with one language-model call, then checks
/// every claim against what Stockfish and the rules actually say.
class ReviewExplainer {
  ReviewExplainer(this._llm);

  final LlmClient _llm;

  static const maxTitle = 70;
  static const maxVerdict = 120;
  static const maxFocus = 3;

  static const system = '''
You are a friendly, precise chess coach going over a game with the player who
played it. You get the game's key moments with facts computed by Stockfish:
- "eval_before", "eval_after": evaluations in pawns, from the side that moved.
- "best_move", "best_line": Stockfish's choice instead. No "best_line" means
  the move played was Stockfish's choice.
- "what_the_move_allowed": the opponent's best reply line after the move.
- "best_line_material", "allowed_material": the mover's material change in
  pawns at the end of each line; left out when nothing changes.
- "pieces_left_hanging", and forced mates ("mate_in_…") when there are any.

For each moment write:
- "title": a headline of at most 60 characters. It must match the verdict:
  never praise a mistake or blunder.
- "explanation": two or three sentences, speaking to the player as "you".
  Explain WHY, using the facts: what the move allowed (the reply line and the
  material it wins), or what the better move achieved. For the opponent's
  mistakes, explain the chance it gave the player and how to take it.
- "lesson": one sentence with a general principle to remember (no moves).

For the whole game write:
- "summary": two or three sentences on how the game went (no moves).
- "focus": up to three short, practical things to work on (no moves).
- "verdict": one line of at most 100 characters for a shareable report card
  (no moves).

Rules:
- Only mention moves that appear in the facts. Never invent moves or lines.
- Only say "mate" if the facts show a forced mate or a mating move.
- Only say a piece is won, lost or hanging if the material facts show it.
- Plain, encouraging language; no engine jargon beyond the numbers given.
- Match the player's level ("player_rating", else the opponent's rating):
  below about 1200, stick to basics (loose pieces, checks, captures, threats);
  from about 1800, you can talk about plans and structure. You may name the
  "opening" in the summary.
Reply with JSON only.''';

  static const schema = <String, Object?>{
    'type': 'object',
    'properties': {
      'summary': {'type': 'string'},
      'focus': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'verdict': {'type': 'string'},
      'moments': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer'},
            'title': {'type': 'string'},
            'explanation': {'type': 'string'},
            'lesson': {'type': 'string'},
          },
          'required': ['id', 'title', 'explanation', 'lesson'],
        },
      },
    },
    'required': ['summary', 'focus', 'verdict', 'moments'],
  };

  /// One call for [moments] of [analysis]; the answer is checked.
  Future<ReviewExplanations> explain(
    GameAnalysis analysis,
    GameRecord record,
    List<MoveReview> moments,
  ) async {
    final facts = [for (final m in moments) factsFor(analysis, m, player: record.playerSide)];
    final reply = await _llm.respond(
      LlmRequest(
        system: system,
        messages: [
          LlmMessage.user(prompt(record, facts, opening: namedOpening(record, analysis.game))),
        ],
        jsonSchema: schema,
      ),
    );
    if (reply.usage case final usage?) {
      debugPrint('Review (${facts.length} moments, ${_llm.model}): $usage');
    }
    if (reply.text.isEmpty) throw const LlmUnavailable('empty reply');
    return checked(reply.text, facts);
  }

  /// The facts sent to the model: only the key moments, compactly.
  static String prompt(GameRecord record, List<MomentFacts> facts, {String? opening}) {
    final data = {
      'player_colour': record.playerSide.name,
      'player_rating': ?record.playerRating,
      'opponent': record.opponentName ?? (record.engineElo != null ? 'Stockfish' : 'Opponent'),
      'opponent_rating': ?(record.opponentRating ?? record.engineElo),
      'opening': ?opening,
      'result': record.result,
      'ending': ?record.endReason,
      'moments': [for (final f in facts) f.toJson()],
    };
    return 'Explain the key moments of this game.\n${jsonEncode(data)}';
  }

  /// Parses the model's JSON and keeps only what the facts support.
  static ReviewExplanations checked(String reply, List<MomentFacts> facts) {
    final Object? json;
    try {
      json = jsonDecode(reply);
    } on FormatException {
      throw const LlmUnavailable('reply is not JSON');
    }
    if (json is! Map<String, Object?>) throw const LlmUnavailable('unexpected reply');
    final raw = ReviewExplanations.fromJson(json);

    final byIndex = {for (final f in facts) f.index: f};
    final moments = <int, MomentExplanation>{};
    for (final MapEntry(key: index, value: text) in raw.moments.entries) {
      final fact = byIndex[index];
      if (fact == null) continue;
      final title = grounded(_clip(text.title, maxTitle), fact);
      final explanation = grounded(text.explanation, fact);
      final praisesAnError = (fact.quality?.isError ?? false) && _praise.hasMatch(title);
      if (title.isEmpty || explanation.isEmpty || praisesAnError) continue; // Plain text instead.
      final lesson = general(text.lesson ?? '');
      moments[index] = MomentExplanation(
        title: title,
        explanation: explanation,
        lesson: lesson.isEmpty ? null : lesson,
      );
    }

    final verdict = general(_clip(raw.verdict ?? '', maxVerdict));
    final summary = general(raw.summary ?? '');
    return ReviewExplanations(
      verdict: verdict.isEmpty ? null : verdict,
      summary: summary.isEmpty ? null : summary,
      focus: [
        for (final item in raw.focus.take(maxFocus))
          if (general(item) case final kept when kept.isNotEmpty) kept,
      ],
      moments: moments,
    );
  }

  /// [text] without sentences whose moves, mates or material claims the
  /// [facts] don't support.
  static String grounded(String text, MomentFacts facts) => _sentences(text)
      .where((s) => MoveCheck.movesIn(s).every(facts.allowedMoves.contains))
      .where((s) => facts.mateIsReal || !_mate.hasMatch(s))
      .where((s) => _materialClaimHolds(s, facts))
      .join(' ')
      .trim();

  /// [text] without sentences that name any move or square: for the
  /// summary, lessons, focus points and verdict, which have no position to
  /// check against (a bare "g4" there is a pawn move nothing can verify).
  static String general(String text) => _sentences(
    text,
  ).where((s) => MoveCheck.movesIn(s).isEmpty && !_square.hasMatch(s)).join(' ').trim();

  static final _square = RegExp(r'\b[a-h][1-8]\b');

  static final _mate = RegExp(
    r'\b(?:mate|mates|mated|mating|checkmate\w*)\b',
    caseSensitive: false,
  );

  static final _materialClaim = RegExp(
    r'\b(?:win|wins|won|winning|lose|loses|lost|losing|drop|drops|dropped|hang|hangs|hung|hanging|gives? away|gave away|blunder\w*)\b(?:\W+\w+){0,3}?\W+(queen|rook|knight|bishop|piece|exchange)\b',
    caseSensitive: false,
  );

  static final _praise = RegExp(
    r'\b(?:strong|great|excellent|brilliant|good|best|clever|nice|smart|powerful)\b',
    caseSensitive: false,
  );

  /// A claim that a queen, rook or piece is won or lost needs a material
  /// swing that size in Stockfish's lines (or a piece left hanging).
  static bool _materialClaimHolds(String sentence, MomentFacts facts) {
    for (final match in _materialClaim.allMatches(sentence)) {
      final needed = switch (match[1]!.toLowerCase()) {
        'queen' => 8,
        'rook' => 4,
        'exchange' => 2,
        _ => 3, // knight, bishop, piece
      };
      if (facts.biggestSwing < needed) return false;
    }
    return true;
  }

  static Iterable<String> _sentences(String text) =>
      text.trim().split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.isNotEmpty);

  static String _clip(String text, int max) {
    final trimmed = text.trim();
    return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max - 1).trimRight()}…';
  }
}
