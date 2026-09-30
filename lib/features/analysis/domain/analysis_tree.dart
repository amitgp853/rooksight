import 'package:dartchess/dartchess.dart';

import '../../play/domain/game_state.dart';

/// A position in the analysis: the start (the root) or the position after a
/// move. Its first child continues its line; the others are variations.
class AnalysisNode {
  AnalysisNode._root(this.position) : move = null, parent = null;

  AnalysisNode._(PlayedMove this.move, this.position, AnalysisNode this.parent);

  /// The move that led here; null at the start.
  final PlayedMove? move;
  final Position position;
  final AnalysisNode? parent;
  final List<AnalysisNode> children = [];

  bool get isRoot => parent == null;

  /// The position before [move].
  Position get before => parent!.position;

  /// Moves from the start.
  int get ply => isRoot ? 0 : parent!.ply + 1;

  /// Every step from the start is its parent's first choice.
  bool get isMainLine {
    for (AnalysisNode? n = this; n?.parent != null; n = n.parent) {
      if (n!.parent!.children.first != n) return false;
    }
    return true;
  }

  /// Starts a variation: an alternative to its parent's first choice.
  bool get isVariationStart => !isRoot && parent!.children.first != this;

  /// `7.` before a white move, `7…` before a black one.
  String get moveNumber {
    final fullmoves = before.fullmoves;
    return before.turn == Side.white ? '$fullmoves.' : '$fullmoves…';
  }

  /// `7. Nxe5`, `7… Nxe5`.
  String get label => '$moveNumber ${move!.san}';

  /// This node, and the ones before it back to (not including) the start.
  List<AnalysisNode> get path {
    final nodes = <AnalysisNode>[];
    for (AnalysisNode? n = this; n != null && !n.isRoot; n = n.parent) {
      nodes.add(n);
    }
    return nodes.reversed.toList();
  }

  /// Following first choices to the end of the line.
  AnalysisNode get end {
    var n = this;
    while (n.children.isNotEmpty) {
      n = n.children.first;
    }
    return n;
  }

  bool isInside(AnalysisNode ancestor) {
    for (AnalysisNode? n = this; n != null; n = n.parent) {
      if (n == ancestor) return true;
    }
    return false;
  }
}

/// A number or a move, as the move list shows it.
typedef MoveToken = ({String text, AnalysisNode? node});

/// A run of moves at one [depth]: 0 for the main line, 1 for a variation of
/// it, and so on.
typedef MoveBlock = ({int depth, List<MoveToken> tokens});

/// The moves explored on the analysis board: a main line and variations.
/// Any legal move for either side can be added; one already there is
/// followed instead of repeated.
class AnalysisTree {
  AnalysisTree(Position start) : root = AnalysisNode._root(start);

  /// [start] with [moves] (UCI) as the main line, as far as they are legal.
  factory AnalysisTree.withLine(Position start, Iterable<String> moves) {
    final tree = AnalysisTree(start);
    var node = tree.root;
    for (final uci in moves) {
      final move = Move.parse(uci);
      final next = move == null ? null : tree.play(node, move);
      if (next == null) break;
      node = next;
    }
    return tree;
  }

  final AnalysisNode root;

  /// Plays [move] after [from]: the existing child when it was played
  /// before, else a new one (the line's continuation if [from] had none,
  /// else a variation). Null if the move is illegal.
  AnalysisNode? play(AnalysisNode from, Move move) {
    final played = GameState.start(from.position).play(move);
    if (played == null) return null;
    final next = played.position;
    for (final child in from.children) {
      if (child.position.fen == next.fen) return child;
    }
    final node = AnalysisNode._(played.moves.single, next, from);
    from.children.add(node);
    return node;
  }

  /// Makes [node]'s line the main line: at each branch on the way to it, its
  /// side becomes the first choice.
  void promote(AnalysisNode node) {
    for (AnalysisNode? n = node; n?.parent != null; n = n.parent) {
      final siblings = n!.parent!.children;
      siblings
        ..remove(n)
        ..insert(0, n);
    }
  }

  /// Removes [node] and everything after it.
  void delete(AnalysisNode node) => node.parent?.children.remove(node);

  /// The game along [node]'s path, for move marks.
  GameState gameTo(AnalysisNode node) {
    var game = GameState.start(root.position);
    for (final n in node.path) {
      game = game.play(n.move!.move) ?? game;
    }
    return game;
  }

  /// [node]'s line from it to the end, as text: `8. Bxf6 Qxf6 9. Nbd2`.
  String lineText(AnalysisNode node) {
    final parts = <String>[];
    var first = true;
    for (AnalysisNode? n = node; n != null; n = n.children.firstOrNull) {
      if (first || n.before.turn == Side.white) parts.add(n.moveNumber);
      parts.add(n.move!.san);
      first = false;
    }
    return parts.join(' ');
  }

  /// The move list: the main line, broken where a move has alternatives,
  /// which follow it one level deeper (as Lichess shows them).
  List<MoveBlock> blocks() {
    final blocks = <MoveBlock>[];
    void line(AnalysisNode first, int depth) {
      var tokens = <MoveToken>[];
      var needNumber = true;
      for (AnalysisNode? n = first; n != null; n = n.children.firstOrNull) {
        if (needNumber || n.before.turn == Side.white) {
          tokens.add((text: n.moveNumber, node: null));
        }
        tokens.add((text: n.move!.san, node: n));
        needNumber = false;
        final siblings = n.parent!.children;
        if (siblings.first == n && siblings.length > 1) {
          blocks.add((depth: depth, tokens: tokens));
          for (final alternative in siblings.skip(1)) {
            line(alternative, depth + 1);
          }
          tokens = [];
          needNumber = true;
        }
      }
      if (tokens.isNotEmpty) blocks.add((depth: depth, tokens: tokens));
    }

    if (root.children.isNotEmpty) line(root.children.first, 0);
    return blocks;
  }
}
