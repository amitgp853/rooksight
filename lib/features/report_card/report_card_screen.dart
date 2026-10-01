import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/gemini_client.dart';
import '../../core/llm/llm_failure_text.dart';
import '../../core/storage/game_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../review/domain/game_analysis.dart';
import '../review/review_controller.dart';
import '../settings/widgets/ai_setup_sheet.dart';
import 'data/image_sharer.dart';
import 'domain/game_report.dart';
import 'widgets/report_card.dart';

/// The report card for a game (`design/source/ShareReport.dc.html`): a
/// preview of the 1080 × 1350 image, and ways to share it. Games not yet
/// reviewed are analysed first (Stockfish only, no AI).
class ReportCardScreen extends ConsumerWidget {
  const ReportCardScreen({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(gameId);
    final state = id == null
        ? const ReviewState(phase: ReviewPhase.notFound)
        : ref.watch(reviewControllerProvider(id));
    final colors = context.colors;
    final type = context.type;
    Widget message(String text, {Widget? action}) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s3,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            ?action,
          ],
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Report Card')),
      body: SafeArea(
        child: switch ((state.phase, state.saved, state.analysis)) {
          (ReviewPhase.notFound, _, _) => message('This game couldn’t be found.'),
          (ReviewPhase.failed, _, _) => message(
            'Couldn’t analyse this game.',
            action: TextButton(
              onPressed: () => ref.read(reviewControllerProvider(id!).notifier).retry(),
              child: const Text('Try again'),
            ),
          ),
          (_, final saved?, final analysis?) when analysis.isComplete => _Ready(
            gameId: id!,
            saved: saved,
            analysis: analysis,
            state: state,
          ),
          (_, _, final analysis?) => _Analysing(
            progress: analysis.evals.length / analysis.game.history.length,
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// The card needs Stockfish's review of every move first (not in the design).
class _Analysing extends StatelessWidget {
  const _Analysing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s3,
          children: [
            Text('Analysing your game… ${(progress * 100).round()}%', style: type.heading),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: colors.focus,
                backgroundColor: colors.bgElevated,
              ),
            ),
            Text(
              'Stockfish checks every move on your phone first.',
              textAlign: TextAlign.center,
              style: type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ready extends ConsumerStatefulWidget {
  const _Ready({
    required this.gameId,
    required this.saved,
    required this.analysis,
    required this.state,
  });

  final int gameId;
  final SavedGame saved;
  final GameAnalysis analysis;
  final ReviewState state;

  @override
  ConsumerState<_Ready> createState() => _ReadyState();
}

class _ReadyState extends ConsumerState<_Ready> {
  final _card = GlobalKey();
  final _shareButton = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final png = await capturePng(_card, width: ReportCard.width);
      final box = _shareButton.currentContext?.findRenderObject() as RenderBox?;
      await ref
          .read(imageSharerProvider)
          .sharePng(
            png,
            fileName: 'rooksight-report-${widget.gameId}.png',
            origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
          );
    } on Object catch (error) {
      debugPrint('Sharing the report card failed: $error');
      messenger.showSnackBar(const SnackBar(content: Text('Couldn’t share the image.')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyPgn() async {
    await Clipboard.setData(ClipboardData(text: widget.saved.record.pgn));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PGN copied')));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final state = widget.state;
    final report = GameReport.of(
      widget.saved,
      widget.analysis,
      aiVerdict: state.explanations?.verdict,
    );
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final caption = type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, 0),
            child: Column(
              spacing: AppSpacing.s4,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: ReportCard.width / ReportCard.height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.mdAll,
                        border: Border.all(color: colors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x80000000),
                            blurRadius: 48,
                            offset: Offset(0, 24),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: AppRadius.mdAll,
                        // The capture is the card alone: square corners, no frame.
                        child: RepaintBoundary(
                          key: _card,
                          child: FittedBox(child: ReportCard(report: report)),
                        ),
                      ),
                    ),
                  ),
                ),
                Text('1080 × 1350 · 4:5 portrait image', style: caption),
                if (!report.aiVerdict) _AiVerdict(gameId: widget.gameId, state: state),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s4, AppSpacing.s4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              FilledButton.icon(
                key: _shareButton,
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: buttonShape,
                  textStyle: type.heading.copyWith(fontSize: 17),
                ),
                icon: _sharing
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.onFocus),
                      )
                    : const Icon(Icons.ios_share, size: 22),
                label: const Text('Share image'),
              ),
              OutlinedButton(
                onPressed: _copyPgn,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: buttonShape,
                  backgroundColor: colors.bgRaised,
                  side: BorderSide(color: colors.border),
                  foregroundColor: colors.textPrimary,
                  textStyle: type.heading.copyWith(fontSize: 15),
                ),
                child: const Text('Copy PGN'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Before the game is explained, the card's verdict is built from the
/// numbers; this offers the AI's instead (the review's single request).
class _AiVerdict extends ConsumerWidget {
  const _AiVerdict({required this.gameId, required this.state});

  final int gameId;
  final ReviewState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final caption = type.label.copyWith(color: colors.textSecondary, fontWeight: FontWeight.w400);
    final player = state.saved!.record.playerSide;
    final hasMoments = state.analysis!.keyMoments(player).isNotEmpty;
    if (!hasMoments) return const SizedBox.shrink();
    if (!ref.watch(llmConfiguredProvider)) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          const AiSetupActions(),
          Text(
            'Turn on the free AI coach for a one-line verdict on this game',
            textAlign: TextAlign.center,
            style: caption.copyWith(fontSize: 12, color: colors.textTertiary),
          ),
        ],
      );
    }

    return switch (state.explainPhase) {
      ExplainPhase.running => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpacing.s2,
        children: [
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: colors.focus),
          ),
          Text('Asking AI for a verdict…', style: caption),
        ],
      ),
      ExplainPhase.failed => Column(
        children: [
          Text(
            llmFailureText(state.explainError),
            textAlign: TextAlign.center,
            style: caption.copyWith(color: colors.coral),
          ),
          TextButton(
            onPressed: ref.read(reviewControllerProvider(gameId).notifier).explain,
            child: const Text('Try again'),
          ),
        ],
      ),
      // Explained, but the verdict didn't pass the checks: keep the summary.
      ExplainPhase.done => const SizedBox.shrink(),
      ExplainPhase.none => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          OutlinedButton.icon(
            onPressed: ref.read(reviewControllerProvider(gameId).notifier).explain,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              foregroundColor: colors.brass,
              backgroundColor: colors.brass.withValues(alpha: 0.08),
              side: BorderSide(color: colors.brass.withValues(alpha: 0.5)),
              textStyle: context.type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Get AI verdict'),
          ),
          Text(
            'Replaces the game summary with a one-line AI verdict',
            textAlign: TextAlign.center,
            style: caption.copyWith(fontSize: 12, color: colors.textTertiary),
          ),
        ],
      ),
    };
  }
}
