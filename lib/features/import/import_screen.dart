// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/segmented_switch.dart';
import '../play/domain/game_controller.dart' show nowProvider;
import 'data/chess_com_models.dart';
import 'data/import_pause.dart';
import 'domain/importer.dart';
import 'import_controller.dart';

/// Import games from Chess.com or Lichess (`ImportGames.dc.html`: form,
/// progress, paused after a rate limit, offline, player not found, done).
/// The form stays in view, dimmed, while an import runs.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key, this.platform = ImportPlatform.chessCom});

  /// The platform selected first.
  final ImportPlatform platform;

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  late ImportPlatform _platform = widget.platform;
  late final _username = TextEditingController(text: ref.read(importUsernameProvider(_platform)));
  ImportRange _range = ImportRange.last3Months;

  /// Each platform has its own saved username.
  void _selectPlatform(ImportPlatform platform) => setState(() {
    _clearFailure();
    _platform = platform;
    _username.text = ref.read(importUsernameProvider(platform));
  });

  /// Editing after a failed import clears its message.
  void _clearFailure() {
    if (ref.read(importControllerProvider).phase == ImportPhase.failed) {
      ref.read(importControllerProvider.notifier).reset();
    }
  }

  @override
  void initState() {
    super.initState();
    _username.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _start() {
    FocusScope.of(context).unfocus();
    ref.read(importControllerProvider.notifier).start(_platform, _username.text, _range);
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(importControllerProvider);
    final pausedUntil = ref.watch(importPauseProvider);
    final controller = ref.read(importControllerProvider.notifier);
    final colors = context.colors;
    final type = context.type;

    final running = progress.isRunning;
    final paused = running && pausedUntil != null;
    final failed = progress.phase == ImportPhase.failed;
    final offline = failed && progress.error == ImportError.offline;
    final notFound = failed && progress.error == ImportError.playerNotFound;
    final finished = progress.phase == ImportPhase.done || progress.phase == ImportPhase.cancelled;
    final busy = running || finished;
    // While running or done, the form shows what was imported.
    final platform = busy ? progress.platform : _platform;

    final buttons = <Widget>[
      if (paused)
        _FooterButton(label: 'Try now', onPressed: ref.read(importPauseProvider.notifier).skip),
      if (running)
        _FooterButton(label: 'Cancel import', onPressed: controller.cancel, primary: false),
      if (finished && progress.added + progress.alreadySaved > 0)
        _FooterButton(
          label: 'See your games',
          onPressed: () {
            controller.reset();
            context.pushReplacement(Routes.games);
          },
        ),
      if (finished)
        _FooterButton(label: 'Import more', onPressed: controller.reset, primary: false),
      if (!busy)
        _FooterButton(
          label: 'Import games',
          onPressed: _username.text.trim().isEmpty ? null : _start,
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Import Games')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 6, AppSpacing.gutter, 0),
                children: [
                  if (offline)
                    const _Banner(
                      icon: Icons.cloud_off_outlined,
                      title: 'You’re offline',
                      text:
                          'Importing needs the internet. Your saved games, Stockfish and pass & '
                          'play still work.',
                    )
                  else if (paused)
                    _Banner(
                      icon: Icons.schedule_rounded,
                      tint: colors.brass,
                      title: '${progress.platform.label} asked us to slow down',
                      trailing: _Countdown(until: pausedUntil),
                    ),
                  if (offline || paused) const SizedBox(height: 22),
                  Opacity(
                    opacity: busy ? 0.5 : 1,
                    child: IgnorePointer(
                      ignoring: busy,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedSwitch(
                            values: ImportPlatform.values,
                            selected: platform,
                            label: (platform) => platform.label,
                            onSelect: _selectPlatform,
                          ),
                          const SizedBox(height: 22),
                          _UsernameField(
                            platform: platform,
                            controller: _username,
                            error: notFound
                                ? 'No ${platform.label} player called “${progress.username}”. '
                                      'Check the spelling and try again.'
                                : null,
                            onChanged: _clearFailure,
                            onSubmitted: busy ? null : _start,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  if (!busy)
                    _Ranges(
                      now: ref.read(nowProvider)(),
                      platform: platform,
                      range: _range,
                      onRange: (range) => setState(() => _range = range),
                    ),
                  if (running) _Progress(progress: progress, paused: paused),
                  if (finished) _Done(progress: progress, range: controller.range),
                  if (failed && !offline && !notFound)
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Text(
                        errorMessage(progress.error, progress.username, progress.platform),
                        style: type.body.copyWith(fontSize: 14, color: colors.coral),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 16, AppSpacing.gutter, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 10,
                children: buttons,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({
    required this.platform,
    required this.controller,
    required this.error,
    required this.onChanged,
    required this.onSubmitted,
  });

  final ImportPlatform platform;
  final TextEditingController controller;

  /// Shown under the field, which turns coral.
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final error = this.error;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s2,
      children: [
        Text(
          '${platform.label.toUpperCase()} USERNAME',
          style: type.overline.copyWith(color: colors.textSecondary),
        ),
        TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.go,
          onChanged: (_) => onChanged(),
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          style: type.body.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Your ${platform.label} username',
            filled: true,
            fillColor: colors.bgRaised,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            enabledBorder: border(error == null ? colors.border : colors.coral),
            focusedBorder: border(error == null ? colors.focus : colors.coral),
          ),
        ),
        if (error != null)
          Semantics(
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.s2,
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: colors.coral),
                Expanded(
                  child: Text(
                    error,
                    style: type.label.copyWith(fontWeight: FontWeight.w400, color: colors.coral),
                  ),
                ),
              ],
            ),
          ),
        Text(
          'Only public games are read. No login or password.',
          style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

class _Ranges extends StatelessWidget {
  const _Ranges({
    required this.now,
    required this.platform,
    required this.range,
    required this.onRange,
  });

  /// For the ranges' "since" dates.
  final DateTime now;
  final ImportPlatform platform;
  final ImportRange range;
  final ValueChanged<ImportRange> onRange;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('HOW FAR BACK', style: type.overline.copyWith(color: colors.textSecondary)),
        const SizedBox(height: 10),
        // Two by two: each option says exactly what it covers.
        for (final row in [ImportRange.values.take(2), ImportRange.values.skip(2)]) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                for (final option in row)
                  Expanded(
                    child: _RangeOption(
                      title: option.shortLabel,
                      detail: rangeDetail(option, platform, now),
                      selected: option == range,
                      onTap: () => onRange(option),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          'Games you already have are skipped.',
          style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}

/// One import range as a radio card: the dot, a title and what it covers.
class _RangeOption extends StatelessWidget {
  const _RangeOption({
    required this.title,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Semantics(
      selected: selected,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? colors.focus.withValues(alpha: 0.08) : colors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? colors.focus : colors.bgElevated, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 10,
              children: [
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? colors.focus : colors.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: selected
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: colors.focus, shape: BoxShape.circle),
                        )
                      : null,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 3,
                    children: [
                      Text(title, style: type.body.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        detail,
                        style: type.label.copyWith(
                          fontSize: 12,
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What [range] covers on [platform], as of [now]: Chess.com goes by
/// calendar month (`Since Jul 2026`), Lichess by date (`Since 1 Sep`).
String rangeDetail(ImportRange range, ImportPlatform platform, DateTime now) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  switch ((platform, range.months, range.days)) {
    case (ImportPlatform.chessCom, final count?, _):
      // Counting the current month.
      final first = DateTime(now.year, now.month - count + 1);
      return 'Since ${months[first.month - 1]} ${first.year}';
    case (ImportPlatform.lichess, _, final days?):
      final first = now.subtract(Duration(days: days));
      return 'Since ${first.day} ${months[first.month - 1]}'
          '${first.year == now.year ? '' : ' ${first.year}'}';
    case _:
      return 'Your whole history';
  }
}

/// A running import: which month, how many games, and a bar. Brass and
/// "Import paused" while waiting out a rate limit.
class _Progress extends StatelessWidget {
  const _Progress({required this.progress, required this.paused});

  final ImportProgress progress;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final month = progress.month;
    final lichess = progress.platform == ImportPlatform.lichess;
    final games = progress.added + progress.alreadySaved;
    final soFar = '$games ${games == 1 ? 'game' : 'games'} so far';
    final left = progress.phase == ImportPhase.checking
        ? 'Looking up ${progress.username}…'
        : lichess
        ? (progress.gamesRead == 0 ? 'Finding your games…' : soFar)
        : month == null
        ? 'Finding your games…'
        : 'Month ${progress.monthsDone + 1} of ${progress.monthsTotal} · $soFar';
    // Lichess streams games without a total: no fraction to show.
    final fraction = lichess || progress.monthsTotal == 0
        ? null
        : progress.monthsDone / progress.monthsTotal;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.s3,
          children: [
            Row(
              spacing: AppSpacing.s3,
              children: [
                if (!paused)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.focus),
                  ),
                Text(
                  paused ? 'Import paused' : 'Importing from ${progress.platform.label}',
                  style: type.heading.copyWith(fontSize: 16),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: paused ? (fraction ?? 0) : fraction,
                minHeight: 6,
                color: paused ? colors.brass : colors.focus,
                backgroundColor: colors.bgElevated,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    left,
                    style: type.label.copyWith(
                      fontWeight: FontWeight.w400,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                if (fraction != null)
                  Text(
                    '${(fraction * 100).round()}%',
                    style: type.mono.copyWith(fontSize: 13, color: colors.textSecondary),
                  ),
              ],
            ),
            Text(
              paused
                  ? 'Nothing is lost. Games fetched so far are already saved.'
                  : 'You can leave this screen. The import keeps going.',
              style: type.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A finished or stopped import: how many games, from where.
class _Done extends StatelessWidget {
  const _Done({required this.progress, required this.range});

  final ImportProgress progress;
  final ImportRange range;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final added = progress.added;
    final games = '$added ${added == 1 ? 'game' : 'games'}';
    final period = switch (range) {
      ImportRange.lastMonth => 'last month',
      ImportRange.last3Months => 'last 3 months',
      ImportRange.last12Months => 'last 12 months',
      ImportRange.everything => 'your whole history',
    };
    final (String title, String text) = switch (progress.phase) {
      ImportPhase.done when added == 0 && progress.alreadySaved == 0 => (
        'No games found',
        '${progress.username} has no standard chess games in this period.',
      ),
      ImportPhase.cancelled => ('Import stopped', '$games imported before you stopped.'),
      _ => (
        '$games imported',
        [
          'From ${progress.platform.label}, $period.',
          if (progress.alreadySaved > 0) '${progress.alreadySaved} you already had were skipped.',
          if (progress.skipped > 0)
            '${progress.skipped} variant or unfinished '
                '${progress.skipped == 1 ? 'game was' : 'games were'} left out.',
        ].join(' '),
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        decoration: BoxDecoration(color: colors.bgRaised, borderRadius: AppRadius.mdAll),
        child: Column(
          spacing: 10,
          children: [
            Text(title, textAlign: TextAlign.center, style: type.title.copyWith(fontSize: 22)),
            Text(
              text,
              textAlign: TextAlign.center,
              style: type.body.copyWith(fontSize: 14, height: 20 / 14, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline, or asked to slow down: an icon, a title and a line.
class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.title, this.text, this.trailing, this.tint});

  final IconData icon;
  final String title;
  final String? text;

  /// Takes the place of [text] (the rate limit's live countdown).
  final Widget? trailing;

  /// Brass for the rate limit; neutral when null.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final tint = this.tint;
    final body = type.label.copyWith(
      fontWeight: FontWeight.w400,
      height: 19 / 13,
      color: colors.textSecondary,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: AppSpacing.s3),
        decoration: BoxDecoration(
          color: tint?.withValues(alpha: 0.08) ?? colors.bgRaised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tint?.withValues(alpha: 0.45) ?? colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppSpacing.s3,
          children: [
            Icon(icon, size: 20, color: tint ?? colors.textSecondary),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    title,
                    style: type.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tint == null
                          ? colors.textPrimary
                          : Color.lerp(tint, colors.textPrimary, 0.55),
                    ),
                  ),
                  if (text case final text?) Text(text, style: body),
                  if (trailing case final trailing?) DefaultTextStyle(style: body, child: trailing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Their servers limit how fast games can be fetched. We’ll carry on
/// automatically in 0:42", counting down.
class _Countdown extends ConsumerStatefulWidget {
  const _Countdown({required this.until});

  final DateTime until;

  @override
  ConsumerState<_Countdown> createState() => _CountdownState();
}

class _CountdownState extends ConsumerState<_Countdown> {
  late final Timer _ticker = Timer.periodic(
    const Duration(milliseconds: 250),
    (_) => setState(() {}),
  );

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(ref.read(nowProvider)());
    final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
    return Text(
      'Their servers limit how fast games can be fetched. We’ll carry on automatically in '
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}.',
    );
  }
}

/// A footer button: primary (focus fill, 56 high) or secondary (50 high).
class _FooterButton extends StatelessWidget {
  const _FooterButton({required this.label, required this.onPressed, this.primary = true});

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final text = context.type.heading.copyWith(fontSize: 16);
    return primary
        ? FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: shape,
              textStyle: text,
            ),
            child: Text(label),
          )
        : OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              backgroundColor: colors.bgRaised,
              side: BorderSide(color: colors.border),
              shape: shape,
              textStyle: text,
            ),
            child: Text(label),
          );
  }
}

/// `March 2026`.
String monthLabel(ArchiveMonth month) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June', //
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${names[month.month - 1]} ${month.year}';
}

/// What to tell the player when an import fails.
String errorMessage(
  ImportError? error,
  String username, [
  ImportPlatform platform = ImportPlatform.chessCom,
]) => switch (error) {
  ImportError.playerNotFound =>
    'There’s no ${platform.label} player called “$username”. Check the spelling.',
  ImportError.offline => 'You seem to be offline. Check your connection and try again.',
  ImportError.rateLimited => '${platform.label} is busy right now. Wait a minute and try again.',
  ImportError.unavailable => '${platform.label} isn’t responding. Try again later.',
  ImportError.storage => 'The games couldn’t be saved on this phone.',
  null => 'Something went wrong.',
};
