import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/board_reader.dart';
import '../domain/scan_usage.dart';

/// A button on the error screen.
typedef ScanAction = ({String label, VoidCallback onPressed});

/// When a scan fails (`ScanError*.dc.html`): what went wrong, what usually
/// fixes it, and two ways on. The photo is shown when the problem is the
/// photo itself.
class ScanErrorView extends StatelessWidget {
  const ScanErrorView({
    super.key,
    required this.failure,
    required this.photo,
    required this.primary,
    required this.secondary,
    required this.onClose,
    this.tertiary,
  });

  final ScanFailure failure;
  final Uint8List? photo;
  final ScanAction primary;
  final ScanAction secondary;

  /// A quiet third option under the buttons (e.g. "Scan anyway").
  final ScanAction? tertiary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final copy = scanErrorCopy(failure);
    final light = Theme.of(context).brightness == Brightness.light;
    final showPhoto = photo != null && copy.photoBadge != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 56,
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Text('Scan Position', style: type.heading),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                children: [
                  if (showPhoto)
                    Center(
                      child: SizedBox.square(
                        dimension: 220,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Image.memory(photo!, fit: BoxFit.cover),
                              ),
                            ),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE3B25C),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 8)],
                                ),
                                child: Icon(
                                  copy.photoBadge,
                                  size: 18,
                                  color: const Color(0xFF0B1224),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 40),
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: colors.bgRaised,
                          borderRadius: BorderRadius.circular(26),
                          border: light ? Border.all(color: colors.border) : null,
                        ),
                        child: Icon(
                          copy.icon,
                          size: 40,
                          color: copy.coral ? colors.coral : colors.brass,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    copy.title,
                    textAlign: TextAlign.center,
                    style: type.title.copyWith(fontSize: 22, height: 28 / 22),
                  ),
                  const SizedBox(height: AppSpacing.s2),
                  Text(
                    copy.body,
                    textAlign: TextAlign.center,
                    style: type.body.copyWith(color: colors.textSecondary),
                  ),
                  if (copy.tips.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: colors.bgRaised,
                        borderRadius: AppRadius.mdAll,
                        border: light ? Border.all(color: colors.border) : null,
                      ),
                      child: Column(
                        children: [
                          for (final (i, tip) in copy.tips.indexed) ...[
                            if (i > 0) Divider(height: 1, color: colors.bgElevated),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: Row(
                                spacing: 12,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: colors.bgElevated,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: type.heading.copyWith(
                                          fontSize: 12,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                          color: colors.focus,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      tip,
                                      style: type.body.copyWith(fontSize: 14, height: 20 / 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: [
                  FilledButton(
                    onPressed: primary.onPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: type.heading,
                    ),
                    child: Text(primary.label),
                  ),
                  OutlinedButton(
                    onPressed: secondary.onPressed,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: colors.bgRaised,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: type.heading.copyWith(fontSize: 15),
                    ),
                    child: Text(secondary.label),
                  ),
                  if (tertiary case final third?)
                    TextButton(onPressed: third.onPressed, child: Text(third.label)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The words and pictures for each way a scan can fail.
typedef ScanErrorCopy = ({
  String title,
  String body,
  List<String> tips,
  IconData? photoBadge,
  IconData icon,
  bool coral,
});

ScanErrorCopy scanErrorCopy(ScanFailure failure) => switch (failure.kind) {
  ScanFailureKind.noBoard => (
    title: 'We couldn’t find a board',
    body: 'The photo doesn’t show a full chess board we can read. A clearer shot usually fixes it.',
    tips: const [
      'Get all 64 squares in the frame, edges included',
      'Shoot from straight above, not from the side',
      'Use even light without strong glare',
    ],
    photoBadge: Icons.search_rounded,
    icon: Icons.search_rounded,
    coral: false,
  ),
  ScanFailureKind.blurry => (
    title: 'Too dark or too blurry',
    body: failure.local
        ? 'Checked on your phone: the pieces won’t be clear enough to read, so no AI request '
              'was used.'
        : 'We can see a board, but not the pieces clearly enough to be sure of the position.',
    tips: const [
      'Turn on a light or the flash',
      'Hold still for a second before you tap',
      'Tap the screen to focus on the board',
    ],
    photoBadge: Icons.wb_sunny_outlined,
    icon: Icons.wb_sunny_outlined,
    coral: false,
  ),
  ScanFailureKind.illegal => (
    title: 'This position can’t happen',
    body: _illegalBody(failure),
    tips: const [],
    photoBadge: null,
    icon: Icons.warning_amber_rounded,
    coral: true,
  ),
  ScanFailureKind.offline => (
    title: 'You’re offline',
    body:
        'Reading a photo needs the internet. You can still set up the position by hand, and '
        'Stockfish analysis works offline.',
    tips: const [],
    photoBadge: null,
    icon: Icons.wifi_off_rounded,
    coral: false,
  ),
  ScanFailureKind.noKey => (
    title: 'Scanning needs your AI Coach key',
    body:
        'Board scans are read by Gemini using your own key. Add one in Settings › Developer '
        'mode, or set the position up by hand.',
    tips: const [],
    photoBadge: null,
    icon: Icons.key_rounded,
    coral: false,
  ),
  ScanFailureKind.invalidKey => (
    title: 'Your AI Coach key was rejected',
    body:
        'Gemini didn’t accept the key. Check it in Settings › Developer mode, or set the '
        'position up by hand.',
    tips: const [],
    photoBadge: null,
    icon: Icons.key_off_rounded,
    coral: false,
  ),
  ScanFailureKind.limit => (
    title: 'Daily AI limit reached',
    body:
        'Your Gemini key has used today’s free requests. Scanning works again when the limit '
        'resets. Setting up by hand and Stockfish work now.',
    tips: const [],
    photoBadge: null,
    icon: Icons.schedule_rounded,
    coral: false,
  ),
  ScanFailureKind.dailyCap => (
    title: 'That’s ${ScanUsage.dailyLimit} scans today',
    body:
        'Scanning pauses until tomorrow, so your Gemini key’s free requests last. You can '
        'still set the position up by hand, and Stockfish works as usual.',
    tips: const [],
    photoBadge: null,
    icon: Icons.event_busy_rounded,
    coral: false,
  ),
  ScanFailureKind.failed => (
    title: 'The scan didn’t work',
    body:
        'The AI didn’t give a usable answer this time. Try again, or set the position up by '
        'hand.',
    tips: const [],
    photoBadge: null,
    icon: Icons.error_outline_rounded,
    coral: false,
  ),
};

String _illegalBody(ScanFailure failure) {
  final problem = failure.result?.problem;
  if (problem == null) return 'The scan found a position that breaks the rules.';
  final shadow = problem.squares.length > 1 ? ' One is probably a shadow or a misread piece.' : '';
  return '${problem.message}$shadow';
}
