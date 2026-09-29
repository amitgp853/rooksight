import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_failure_text.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/speech/speech_input.dart';
import '../../core/storage/analysis_repository.dart';
import '../../core/storage/game_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/logo_mark.dart';
import '../games/games_screen.dart' show opponentName;
import '../play/domain/pgn_import.dart';
import '../play/widgets/result_copy.dart' show moveLabel;
import '../review/domain/game_analysis.dart';
import '../review/domain/position_eval.dart';
import 'coach_controller.dart';
import 'domain/coach_tools.dart';
import 'widgets/agent_steps.dart';
import 'widgets/coach_answer_view.dart';
import 'widgets/game_picker_sheet.dart';

/// The coach chat (`design/source/Coach.dc.html`). Opened from a review's
/// key moment, it starts with a question about that move ready to send.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.gameId, this.moveIndex, this.question});

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
    if (question.trim().isEmpty || ref.read(coachControllerProvider).isBusy) return;
    if (_listening) _stopListening();
    // The attachment stays, so follow-ups are about the same game.
    ref.read(coachControllerProvider.notifier).ask(question, focus: _focus);
    _input.clear();
    FocusScope.of(context).unfocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final end = _scroll.position.maxScrollExtent;
      if (shouldReduceMotion(context, ref)) {
        _scroll.jumpTo(end);
      } else {
        _scroll.animateTo(end, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final state = ref.watch(coachControllerProvider);
    final hasKey = ref.watch(llmConfiguredProvider);
    ref.listen(coachControllerProvider, (_, _) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Coach'),
            Text(
              'Every move claim checked by Stockfish',
              style: type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          if (state.turns.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s2),
              child: OutlinedButton(
                onPressed: state.isBusy
                    ? null
                    : () => ref.read(coachControllerProvider.notifier).clear(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.border),
                ),
                child: const Text('New chat'),
              ),
            ),
        ],
        shape: Border(bottom: BorderSide(color: colors.border)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: state.turns.isEmpty
                  ? _Intro(
                      hasKey: hasKey,
                      onAsk: hasKey ? _send : null,
                      suggestions: _focus == null || _focus!.isMove ? suggestions : gameSuggestions,
                    )
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      children: [
                        for (final (i, turn) in state.turns.indexed)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.s6),
                            child: _Turn(
                              turn: turn,
                              onRetry: i == state.turns.length - 1
                                  ? () => ref.read(coachControllerProvider.notifier).retry()
                                  : null,
                            ),
                          ),
                      ],
                    ),
            ),
            _InputBar(
              controller: _input,
              enabled: hasKey,
              canSend: hasKey && !state.isBusy && _input.text.trim().isNotEmpty,
              focus: _focus,
              onClearFocus: () => setState(() => _focus = null),
              onAttach: hasKey && !state.isBusy ? _pickGame : null,
              onSend: _send,
              listening: _listening,
              onVoice: _voiceUnavailable ? null : _toggleVoice,
              // Tapping in to fix a word ends listening.
              onFieldTap: _listening ? _stopListening : null,
              reduceMotion: shouldReduceMotion(context, ref),
            ),
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
        if (turn.steps.isNotEmpty) AgentSteps(steps: turn.steps, running: turn.isRunning),
        if (turn.answer case final answer?) CoachAnswerView(answer: answer),
        if (turn.error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(llmFailureText(turn.error), style: type.body.copyWith(color: colors.coral)),
              if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
      ],
    );
  }
}

/// Before the first question (not in the design): what the coach does, and
/// a few questions to start with; or how to add a key.
class _Intro extends StatelessWidget {
  const _Intro({required this.hasKey, required this.onAsk, required this.suggestions});

  final bool hasKey;
  final ValueChanged<String>? onAsk;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        spacing: AppSpacing.s3,
        children: [
          const SizedBox(height: AppSpacing.s6),
          const LogoMark(size: 48),
          Text('Ask the AI Coach', style: type.title, textAlign: TextAlign.center),
          Text(
            hasKey
                ? 'It looks through your games and asks Stockfish before it answers. '
                      'Every move it mentions comes from Stockfish or your games.'
                : 'The AI Coach isn’t set up on this device yet.',
            style: type.body.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (hasKey) ...[
            const SizedBox(height: AppSpacing.s2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.s2,
              runSpacing: AppSpacing.s2,
              children: [
                for (final question in suggestions)
                  OutlinedButton(
                    onPressed: onAsk == null ? null : () => onAsk!(question),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: const StadiumBorder(),
                      side: BorderSide(color: colors.border),
                      foregroundColor: colors.textPrimary,
                    ),
                    child: Text(question),
                  ),
              ],
            ),
          ],
        ],
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
  });

  final TextEditingController controller;
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
                    hintText: listening
                        ? 'Listening… tap ■ to stop'
                        : 'Ask about a move or a pattern…',
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
