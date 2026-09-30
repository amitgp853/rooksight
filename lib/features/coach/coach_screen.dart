import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/move_wise_board.dart';
import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_client.dart';
import '../../core/llm/llm_failure_text.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/routing/app_router.dart';
import '../../core/speech/speech_input.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/chat_repository.dart';
import '../../core/storage/game_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_mark.dart';
import '../games/games_screen.dart' show opponentName;
import '../play/domain/game_controller.dart' show nowProvider;
import '../play/domain/pgn_import.dart';
import '../play/widgets/result_copy.dart' show moveLabel;
import '../review/domain/game_analysis.dart';
import '../review/domain/position_eval.dart';
import 'chats.dart';
import 'chats_screen.dart';
import 'coach_controller.dart';
import 'domain/coach_tools.dart';
import 'widgets/agent_steps.dart';
import 'widgets/chat_options_sheet.dart';
import 'widgets/coach_answer_view.dart';
import 'widgets/game_picker_sheet.dart';

/// The AI Coach (`Coach.dc.html`, `CoachThread.dc.html`). A new chat by
/// default, saved when its first question is sent; or, with [chatId], a
/// saved chat read back from the phone (never running the AI) to continue.
/// Opened from a review's key moment, it starts with a question about that
/// move ready to send.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.chatId, this.gameId, this.moveIndex, this.question});

  /// A saved chat to reopen.
  final int? chatId;

  /// The game and move a review asked about.
  final int? gameId;
  final int? moveIndex;

  /// A question to start with, ready to send (e.g. from the stats).
  final String? question;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  /// The game, or move of a game, the questions are about. It stays for
  /// follow-up questions until removed.
  CoachFocus? _focus;

  /// Voice questions: the words go into the field, to check before sending.
  late final SpeechInput _speech = ref.read(speechInputProvider);
  bool _listening = false;

  /// The phone has no speech recognition: the mic is hidden.
  bool _voiceUnavailable = false;

  static const suggestions = [
    'Why do I keep losing?',
    'What should I work on first?',
    'Explain my costliest mistake',
  ];

  /// With a game attached.
  static const gameSuggestions = [
    'What went wrong in this game?',
    'Where did I lose the advantage?',
    'What should I have played instead?',
  ];

  /// A saved chat, read back: its own header and composer.
  bool get _saved => widget.chatId != null;

  late final _provider = coachControllerProvider(widget.chatId);

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
    if (widget.question case final question?) _input.text = question;
    switch ((widget.gameId, widget.moveIndex)) {
      case (final game?, final move?):
        _loadMoveFocus(game, move);
      case (final game?, null):
        _loadGameFocus(game);
      case _:
    }
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Names the move asked about and suggests a question for it.
  Future<void> _loadMoveFocus(int gameId, int index) async {
    final saved = await ref.read(gameRepositoryProvider).byId(gameId);
    if (saved == null || !mounted) return;
    final game = gameFromPgn(saved.record.pgn);
    if (index >= game.moves.length) return;
    final stored = await ref.read(analysisRepositoryProvider).analysis(gameId);
    if (!mounted) return;
    final analysis = stored == null
        ? null
        : GameAnalysis(game, stored.evals.map(PositionEval.fromJson).toList());
    final quality = analysis?.moves.where((m) => m.index == index).firstOrNull?.quality;
    final label = moveLabel(game, index);
    setState(() {
      _focus = CoachFocus(gameId: gameId, index: index, label: label);
      _input.text = quality == null || quality.isError
          ? 'What went wrong with $label, and what should I have played?'
          : 'Why was $label a good move?';
    });
  }

  Future<void> _loadGameFocus(int gameId) async {
    final saved = await ref.read(gameRepositoryProvider).byId(gameId);
    if (saved != null && mounted) _attach(saved);
  }

  void _attach(SavedGame game) => setState(
    () => _focus = CoachFocus(
      gameId: game.id,
      label: 'vs ${opponentName(game.record)} · ${playedWhen(game.record.endedAt, DateTime.now())}',
    ),
  );

  Future<void> _pickGame() async {
    final game = await pickGame(context, reduceMotion: shouldReduceMotion(context, ref));
    if (game != null && mounted) _attach(game);
  }

  /// Starts or stops listening. What's heard goes after anything already
  /// typed; sending stays a tap, as chess words are easily misheard.
  Future<void> _toggleVoice() async {
    if (_listening) return _stopListening();
    final typed = _input.text.trim();
    final started = await _speech.start(
      onWords: (words) {
        if (!mounted) return;
        final text = [if (typed.isNotEmpty) typed, if (words.isNotEmpty) words].join(' ');
        _input.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onStopped: (problem) {
        if (!mounted) return;
        setState(() => _listening = false);
        switch (problem) {
          case null:
          case SpeechProblem.notHeard when _input.text.trim() != typed:
            // Ended normally, or some words came through before the error.
            break;
          case SpeechProblem.notHeard:
            _tell('I didn’t catch that. Tap the mic and try again.');
          case SpeechProblem.offline:
            _tell('Voice input needs an internet connection on this phone.');
          case SpeechProblem.failed:
            _tell('Voice input stopped. Try again, or type your question.');
        }
      },
    );
    if (!mounted) return;
    switch (started) {
      case SpeechStart.listening:
        setState(() => _listening = true);
      case SpeechStart.denied:
        _tell('To ask by voice, allow MoveWise to use the microphone in your phone’s Settings.');
      case SpeechStart.unavailable:
        setState(() => _voiceUnavailable = true);
        _tell('Voice input isn’t available on this phone.');
      case SpeechStart.failed:
        _tell('Voice input couldn’t start. Try again, or type your question.');
    }
  }

  /// Shows the mic as stopped straight away, without waiting for the phone to
  /// confirm; its last words still land in the field.
  Future<void> _stopListening() {
    setState(() => _listening = false);
    return _speech.stop();
  }

  void _tell(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  void _send([String? text]) {
    final question = text ?? _input.text;
    if (question.trim().isEmpty || ref.read(_provider).isBusy) return;
    if (_listening) _stopListening();
    // The attachment stays, so follow-ups are about the same game.
    ref.read(_provider.notifier).ask(question, focus: _focus);
    _input.clear();
    FocusScope.of(context).unfocus();
  }

  /// A fresh chat; the one before is already saved.
  void _newChat() {
    if (_saved) {
      context.pushReplacement(Routes.coach);
      return;
    }
    ref.invalidate(_provider);
    setState(() {
      _focus = null;
      _input.clear();
    });
  }

  Future<void> _openChats() async {
    final result = await context.push<ChatsResult>(Routes.coachChats);
    if (result == ChatsResult.newChat && mounted) _newChat();
  }

  Future<void> _options(StoredChat chat) async {
    final deleted = await showChatOptions(context, ref, chat);
    if (deleted && mounted) context.pop();
  }

  void _scrollToEnd({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (!animate || shouldReduceMotion(context, ref)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(_provider);
    final hasKey = ref.watch(llmConfiguredProvider);
    // A saved chat opens at its end; new messages scroll into view.
    ref.listen(_provider, (previous, next) => _scrollToEnd(animate: previous?.loading != true));
    final chat = widget.chatId == null ? null : ref.watch(chatProvider(widget.chatId!)).value;
    final last = state.turns.lastOrNull;
    final offline = last?.error is LlmOffline;

    // Why the composer is off, if it is.
    final String? blocked = !hasKey
        ? 'The AI Coach isn’t set up on this phone yet. Add your key in Settings › Developer '
              'mode.'
        : state.isFull
        ? 'Context memory is full. Please start a new chat.'
        : offline
        ? 'You’re offline. You can read this chat; continuing it needs the internet.'
        : null;

    return Scaffold(
      appBar: _saved
          ? _SavedHeader(chat: chat, onOptions: chat == null ? null : () => _options(chat))
          : AppBar(
              titleSpacing: 0,
              title: const Text('AI Coach'),
              actions: [
                IconButton(
                  tooltip: 'Your chats',
                  onPressed: _openChats,
                  icon: const Icon(Icons.history_rounded),
                ),
                NewChatPill(onPressed: state.turns.isEmpty || state.isBusy ? null : _newChat),
                const SizedBox(width: AppSpacing.s3),
              ],
              shape: Border(bottom: BorderSide(color: colors.bgElevated)),
            ),
      body: SafeArea(
        child: Column(
          children: [
            if (_saved && chat?.gameId != null) _ContextRow(chat: chat!),
            Expanded(
              child: state.loading
                  ? const SizedBox.shrink()
                  : state.turns.isEmpty && !_saved
                  ? _Intro(
                      hasKey: hasKey,
                      withGame: _focus != null && !_focus!.isMove,
                      onAsk: hasKey ? _send : null,
                      suggestions: _focus == null || _focus!.isMove ? suggestions : gameSuggestions,
                    )
                  : _Transcript(
                      state: state,
                      controller: _scroll,
                      dividers: _saved,
                      onRetry: () => ref.read(_provider.notifier).retry(),
                    ),
            ),
            if (blocked != null && (_saved || state.turns.isNotEmpty))
              _Banner(
                text: blocked,
                icon: !hasKey
                    ? Icons.key_rounded
                    : state.isFull
                    ? Icons.inventory_2_outlined
                    : Icons.wifi_off_rounded,
                action: state.isFull
                    ? NewChatPill(onPressed: _newChat)
                    : offline && hasKey
                    ? TextButton(
                        onPressed: state.isBusy ? null : () => ref.read(_provider.notifier).retry(),
                        child: const Text('Try again'),
                      )
                    : null,
              ),
            _InputBar(
              controller: _input,
              enabled: blocked == null,
              canSend: blocked == null && !state.isBusy && _input.text.trim().isNotEmpty,
              focus: _focus,
              onClearFocus: () => setState(() => _focus = null),
              onAttach: blocked == null && !state.isBusy ? _pickGame : null,
              onSend: _send,
              listening: _listening,
              onVoice: _voiceUnavailable ? null : _toggleVoice,
              // Tapping in to fix a word ends listening.
              onFieldTap: _listening ? _stopListening : null,
              reduceMotion: shouldReduceMotion(context, ref),
              hint: _saved ? 'Continue the chat…' : 'Ask about a move or a pattern…',
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved chat's header: its title over when it started and how long it
/// is, and its options.
class _SavedHeader extends StatelessWidget implements PreferredSizeWidget {
  const _SavedHeader({required this.chat, required this.onOptions});

  final StoredChat? chat;
  final VoidCallback? onOptions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final chat = this.chat;
    return AppBar(
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chat?.title ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: type.heading.copyWith(fontSize: 16, height: 22 / 16),
          ),
          if (chat != null)
            Text(
              'Started ${shortDay(chat.createdAt, DateTime.now())} · '
              '${messagesLabel(chat.messageCount)}',
              style: type.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Chat options',
          onPressed: onOptions,
          icon: const Icon(Icons.more_horiz_rounded),
        ),
        const SizedBox(width: 6),
      ],
      shape: Border(bottom: BorderSide(color: colors.bgElevated)),
    );
  }
}

/// "About" and the game the chat is about; opens its review. Reads "Game
/// deleted" (and does nothing) once the game is gone.
class _ContextRow extends ConsumerWidget {
  const _ContextRow({required this.chat});

  final StoredChat chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final gameId = chat.gameId!;
    final exists = ref.watch(_gameExistsProvider(gameId)).value ?? true;
    final fen = chat.thumbFen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.gutter, vertical: AppSpacing.s2),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.bgElevated)),
      ),
      child: Row(
        spacing: AppSpacing.s2,
        children: [
          Text('About', style: type.label.copyWith(fontSize: 12, color: colors.textTertiary)),
          Flexible(
            child: Material(
              color: colors.bgElevated,
              shape: StadiumBorder(
                side: BorderSide(
                  color: Color.alphaBlend(colors.focus.withValues(alpha: 0.3), colors.bgElevated),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: exists ? () => context.push(Routes.review('$gameId')) : null,
                child: SizedBox(
                  height: 30,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 10, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: AppSpacing.s2,
                      children: [
                        if (fen != null && exists)
                          MoveWiseStaticBoard(
                            fen: fen,
                            size: 22,
                            coordinates: false,
                            borderRadius: BorderRadius.circular(4),
                          )
                        else
                          const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            exists ? chat.scopeLabel : 'Game deleted',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: type.label.copyWith(
                              color: exists ? colors.textPrimary : colors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final _gameExistsProvider = FutureProvider.autoDispose.family<bool, int>(
  (ref, id) async => await ref.watch(gameRepositoryProvider).byId(id) != null,
);

/// The conversation: questions, steps and answers. In a saved chat, days
/// are divided and restored steps start folded.
class _Transcript extends StatelessWidget {
  const _Transcript({
    required this.state,
    required this.controller,
    required this.dividers,
    required this.onRetry,
  });

  final CoachState state;
  final ScrollController controller;
  final bool dividers;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final turns = state.turns;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.all(AppSpacing.s4),
      children: [
        for (final (i, turn) in turns.indexed) ...[
          if (dividers && (i == 0 || !_sameDay(turns[i - 1].at, turn.at)))
            _DayDivider(label: dayDivider(turn.at, now)),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s6),
            child: _Turn(turn: turn, onRetry: i == turns.length - 1 ? onRetry : null),
          ),
        ],
      ],
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A centred date between hairlines.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final line = Expanded(child: Container(height: 1, color: colors.bgElevated));
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        spacing: AppSpacing.s3,
        children: [
          line,
          Text(label, style: context.type.label.copyWith(fontSize: 12, color: colors.textTertiary)),
          line,
        ],
      ),
    );
  }
}

/// Why the composer is off: offline, no key, or a full chat.
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.icon, this.action});

  final String text;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        // Clear of the transcript above and the composer below.
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: colors.bgRaised,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          spacing: 10,
          children: [
            Icon(icon, size: 18, color: colors.brass),
            Expanded(
              child: Text(
                text,
                style: context.type.label.copyWith(
                  height: 18 / 13,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// One question: the player's bubble, the coach's steps, and its answer.
class _Turn extends StatelessWidget {
  const _Turn({required this.turn, this.onRetry});

  final CoachTurn turn;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final error = turn.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s4,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 290),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 12),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(colors.focus.withValues(alpha: 0.28), colors.bgBase),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(6),
                    ),
                  ),
                  child: Text(
                    turn.question,
                    style: type.body.copyWith(fontSize: 15, height: 22 / 15),
                  ),
                ),
              ),
            ),
            if (turn.focus case final focus?)
              // Which game (or move) the answer is about.
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  focus.isMove ? 'About ${focus.label}' : 'Game: ${focus.label}',
                  style: type.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: colors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
        if (turn.steps.isNotEmpty)
          AgentSteps(
            steps: turn.steps,
            running: turn.isRunning,
            // Read back from a saved chat: folded, a tap to look.
            initiallyOpen: !turn.restored,
          ),
        if (turn.answer case final answer?) CoachAnswerView(answer: answer),
        if (error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error is NotAnswered ? 'Not answered yet.' : llmFailureText(error),
                style: type.body.copyWith(
                  color: error is NotAnswered ? colors.textSecondary : colors.coral,
                ),
              ),
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
      ],
    );
  }
}

/// "Pick up where you left off": the latest saved chat, one tap to reopen.
class _PickUp extends ConsumerWidget {
  const _PickUp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final latest = ref.watch(chatsProvider('')).value?.firstOrNull;
    if (latest == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s2,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PICK UP WHERE YOU LEFT OFF',
                style: type.overline.copyWith(color: colors.textTertiary),
              ),
            ),
            TextButton(
              onPressed: () => context.push(Routes.coachChats),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                textStyle: type.label.copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text('All chats'),
            ),
          ],
        ),
        Material(
          color: colors.bgRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push(Routes.coachChat(latest.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                spacing: AppSpacing.s3,
                children: [
                  ChatThumbnail(chat: latest, size: 40, radius: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        Text(
                          latest.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.body.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${chatWhen(latest.updatedAt, ref.read(nowProvider)())} · '
                          '${messagesLabel(latest.messageCount)}',
                          style: type.label.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Before the first question (`CoachEmpty.dc.html`, `CoachEmptyGame.dc.html`):
/// what the AI Coach does and questions to start with; or that it needs a key.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.hasKey,
    required this.withGame,
    required this.onAsk,
    required this.suggestions,
  });

  final bool hasKey;

  /// A game is attached: the text and questions are about it.
  final bool withGame;
  final ValueChanged<String>? onAsk;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final text = !hasKey
        ? 'The AI Coach isn’t set up on this device yet.'
        : withGame
        ? 'Ask anything about this game. The AI Coach sees every move and checks each one '
              'it mentions with Stockfish.'
        : 'Ask about your games, a move or a pattern. Every move it suggests is checked by '
              'Stockfish before you see it. Tap + to pick a game.';

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: ConstrainedBox(
          // Sits at the bottom, just above the composer, when there's room.
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 22,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s2),
                child: Column(
                  spacing: AppSpacing.s3,
                  children: [
                    const LogoMark(size: 56),
                    Text(
                      'Ask the AI Coach',
                      textAlign: TextAlign.center,
                      style: type.title.copyWith(fontSize: 22),
                    ),
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
              // Hidden with a game attached: this chat is about that game.
              if (!withGame) const _PickUp(),
              if (hasKey)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.s2,
                  children: [
                    Text('TRY ASKING', style: type.overline.copyWith(color: colors.textTertiary)),
                    for (final question in suggestions)
                      OutlinedButton(
                        onPressed: onAsk == null ? null : () => onAsk!(question),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          alignment: Alignment.centerLeft,
                          backgroundColor: colors.bgRaised,
                          side: BorderSide(color: colors.border),
                          foregroundColor: colors.textPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: type.body.copyWith(fontWeight: FontWeight.w500),
                        ),
                        child: Row(
                          spacing: AppSpacing.s3,
                          children: [
                            Expanded(child: Text(question)),
                            Icon(Icons.arrow_upward_rounded, size: 16, color: colors.focus),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The mic in the question field. While listening it turns focus blue and a
/// ring pulses behind it (a still ring with reduced motion); tapping stops.
class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onPressed, required this.reduceMotion});

  final bool listening;
  final VoidCallback? onPressed;
  final bool reduceMotion;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.listening && !widget.reduceMotion) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0.4;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final listening = widget.listening;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (listening)
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Container(
              width: 36 + 12 * _pulse.value,
              height: 36 + 12 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.focus.withValues(alpha: 0.25 * (1 - _pulse.value)),
              ),
            ),
          ),
        IconButton(
          tooltip: listening ? 'Stop listening' : 'Ask by voice',
          onPressed: widget.onPressed,
          style: IconButton.styleFrom(
            foregroundColor: listening ? colors.onFocus : colors.textSecondary,
            backgroundColor: listening ? colors.focus : Colors.transparent,
            fixedSize: const Size.square(36),
            minimumSize: const Size.square(36),
            padding: EdgeInsets.zero,
          ),
          icon: Icon(listening ? Icons.stop_rounded : Icons.mic_none_rounded, size: 22),
        ),
      ],
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.canSend,
    required this.focus,
    required this.onClearFocus,
    required this.onAttach,
    required this.onSend,
    required this.listening,
    required this.onVoice,
    required this.reduceMotion,
    required this.onFieldTap,
    this.hint = 'Ask about a move or a pattern…',
  });

  final TextEditingController controller;

  /// The field's placeholder.
  final String hint;
  final bool enabled;
  final bool canSend;

  /// The game or move the questions are about, shown as a chip.
  final CoachFocus? focus;
  final VoidCallback onClearFocus;

  /// Opens the game picker.
  final VoidCallback? onAttach;
  final VoidCallback onSend;

  /// Voice input: the mic, or no mic when [onVoice] is null.
  final bool listening;
  final VoidCallback? onVoice;
  final bool reduceMotion;
  final VoidCallback? onFieldTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: colors.border),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s4, 12, AppSpacing.s4, AppSpacing.s4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: AppSpacing.s2,
        children: [
          if (focus case final focus?)
            InputChip(
              avatar: Icon(
                focus.isMove ? Icons.place_outlined : Icons.sports_esports_outlined,
                size: 16,
                color: colors.focus,
              ),
              label: Text(
                focus.isMove ? 'About ${focus.label}' : 'Game: ${focus.label}',
                style: focus.isMove ? type.mono.copyWith(fontSize: 13) : type.label,
              ),
              onDeleted: onClearFocus,
              deleteButtonTooltipMessage: focus.isMove ? 'Not about this move' : 'Remove the game',
              backgroundColor: colors.bgRaised,
              side: BorderSide(color: colors.border),
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.xsAll),
            ),
          Row(
            spacing: AppSpacing.s2,
            children: [
              IconButton(
                tooltip: 'Attach a game',
                onPressed: onAttach,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(48),
                  backgroundColor: colors.bgRaised,
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                ),
                icon: const Icon(Icons.add_rounded),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => canSend ? onSend() : null,
                  onTap: onFieldTap,
                  style: type.body.copyWith(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: listening ? 'Listening… tap ■ to stop' : hint,
                    suffixIcon: onVoice == null
                        ? null
                        : _MicButton(
                            listening: listening,
                            onPressed: enabled ? onVoice : null,
                            reduceMotion: reduceMotion,
                          ),
                    hintStyle: type.body.copyWith(fontSize: 15, color: colors.textTertiary),
                    filled: true,
                    fillColor: colors.bgRaised,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s4,
                      vertical: 13,
                    ),
                    border: pill,
                    enabledBorder: pill,
                    disabledBorder: pill,
                    focusedBorder: pill.copyWith(borderSide: BorderSide(color: colors.focus)),
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(48),
                  backgroundColor: colors.focus,
                  foregroundColor: colors.onFocus,
                  disabledBackgroundColor: colors.bgElevated,
                  disabledForegroundColor: colors.textTertiary,
                ),
                icon: const Icon(Icons.arrow_upward, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
