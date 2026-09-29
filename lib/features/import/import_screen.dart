import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/segmented_switch.dart';
import 'data/chess_com_models.dart';
import '../play/domain/game_controller.dart' show nowProvider;
import 'domain/importer.dart';
import 'import_controller.dart';

/// Import games from Chess.com or Lichess. Not designed yet: built from the
/// design system's tokens and components, flagged for design review.
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
    _platform = platform;
    _username.text = ref.read(importUsernameProvider(platform));
  });

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
    return Scaffold(
      appBar: AppBar(title: const Text('Import games')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: switch (progress.phase) {
                ImportPhase.idle => _Form(
                  now: ref.read(nowProvider)(),
                  platform: _platform,
                  onPlatform: _selectPlatform,
                  username: _username,
                  range: _range,
                  onRange: (range) => setState(() => _range = range),
                  onImport: _start,
                ),
                ImportPhase.checking || ImportPhase.importing => _Running(progress: progress),
                _ => _Finished(progress: progress, onRetry: _start),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.now,
    required this.platform,
    required this.onPlatform,
    required this.username,
    required this.range,
    required this.onRange,
    required this.onImport,
  });

  /// For the ranges' "since" dates.
  final DateTime now;
  final ImportPlatform platform;
  final ValueChanged<ImportPlatform> onPlatform;
  final TextEditingController username;
  final ImportRange range;
  final ValueChanged<ImportRange> onRange;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedSwitch(
          values: ImportPlatform.values,
          selected: platform,
          label: (platform) => platform.label,
          onSelect: onPlatform,
        ),
        const SizedBox(height: AppSpacing.s6),
        Text(
          '${platform.label.toUpperCase()} USERNAME',
          style: type.overline.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s3),
        TextField(
          controller: username,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.go,
          style: type.body,
          decoration: InputDecoration(
            hintText: platform == ImportPlatform.lichess
                ? 'e.g. DrNykterstein'
                : 'e.g. magnuscarlsen',
          ),
          onSubmitted: (_) => onImport(),
        ),
        const SizedBox(height: AppSpacing.s2),
        Text(
          'Only public games are read. No login or password.',
          style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: AppSpacing.s6),
        Text('HOW FAR BACK', style: type.overline.copyWith(color: colors.textSecondary)),
        const SizedBox(height: AppSpacing.s3),
        // Two by two: each option says exactly what it covers.
        for (final row in [ImportRange.values.take(2), ImportRange.values.skip(2)]) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.s2,
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
          const SizedBox(height: AppSpacing.s2),
        ],
        Text(
          'Games you already have are skipped.',
          style: type.label.copyWith(color: colors.textTertiary, fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: AppSpacing.s8),
        FilledButton(
          onPressed: username.text.trim().isEmpty ? null : onImport,
          child: const Text('Import games'),
        ),
      ],
    );
  }
}

/// One import range: a title and what it covers, as a selectable card.
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
        color: selected ? colors.focus.withValues(alpha: 0.12) : colors.bgRaised,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
          side: BorderSide(
            color: selected ? colors.focus : colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        title,
                        style: type.heading.copyWith(
                          fontSize: 15,
                          color: selected
                              ? Color.lerp(colors.focus, colors.textPrimary, 0.4)
                              : colors.textPrimary,
                        ),
                      ),
                      Text(
                        detail,
                        style: type.label.copyWith(
                          color: colors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // The mark says "chosen" without relying on colour alone.
                Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? colors.focus : Colors.transparent,
                    border: selected ? null : Border.all(color: colors.border, width: 1.5),
                  ),
                  child: selected ? Icon(Icons.check, size: 12, color: colors.onFocus) : null,
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

class _Running extends ConsumerWidget {
  const _Running({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final month = progress.month;
    final lichess = progress.platform == ImportPlatform.lichess;
    final status = progress.phase == ImportPhase.checking
        ? 'Looking up ${progress.username}…'
        : lichess
        ? (progress.gamesRead == 0
              ? 'Finding your games…'
              : '${progress.gamesRead} ${progress.gamesRead == 1 ? 'game' : 'games'} read')
        : month == null
        ? 'Finding your games…'
        : 'Month ${progress.monthsDone + 1} of ${progress.monthsTotal} · ${monthLabel(month)}';
    // Lichess streams games without a total: no fraction to show.
    final fraction = lichess || progress.monthsTotal == 0
        ? null
        : progress.monthsDone / progress.monthsTotal;

    return _Panel(
      children: [
        Text('Importing from ${progress.platform.label}', style: type.heading),
        Text(status, style: type.body.copyWith(color: colors.textSecondary)),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            color: colors.focus,
            backgroundColor: colors.bgElevated,
          ),
        ),
        _Counts(progress: progress),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: ref.read(importControllerProvider.notifier).cancel,
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _Finished extends ConsumerWidget {
  const _Finished({required this.progress, required this.onRetry});

  final ImportProgress progress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final controller = ref.read(importControllerProvider.notifier);
    final error = progress.error;

    final (title, message) = switch (progress.phase) {
      ImportPhase.done when progress.added == 0 && progress.alreadySaved == 0 => (
        'No games found',
        '${progress.username} has no standard chess games in this period.',
      ),
      ImportPhase.done => ('Import complete', null),
      ImportPhase.cancelled => ('Import stopped', null),
      _ => ('Couldn’t import', errorMessage(error, progress.username, progress.platform)),
    };

    return _Panel(
      children: [
        Text(title, style: type.heading),
        if (message != null)
          Text(
            message,
            style: type.body.copyWith(
              color: progress.phase == ImportPhase.failed ? colors.coral : colors.textSecondary,
            ),
          ),
        if (progress.phase != ImportPhase.failed) _Counts(progress: progress),
        const SizedBox(height: AppSpacing.s1),
        if (progress.phase == ImportPhase.failed && error != ImportError.playerNotFound)
          FilledButton(
            onPressed: () {
              controller.reset();
              onRetry();
            },
            child: const Text('Try again'),
          )
        else if (progress.added + progress.alreadySaved > 0)
          FilledButton(
            onPressed: () {
              controller.reset();
              context.pushReplacement(Routes.games);
            },
            child: const Text('See games'),
          ),
        OutlinedButton(
          onPressed: controller.reset,
          child: Text(progress.phase == ImportPhase.failed ? 'Change username' : 'Import more'),
        ),
      ],
    );
  }
}

class _Counts extends StatelessWidget {
  const _Counts({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final parts = [
      '${progress.added} new ${progress.added == 1 ? 'game' : 'games'}',
      if (progress.alreadySaved > 0) '${progress.alreadySaved} already saved',
      if (progress.skipped > 0) '${progress.skipped} skipped (variants or unfinished)',
    ];
    return Text(
      parts.join(' · '),
      style: context.type.mono.copyWith(fontSize: 13, color: context.colors.textSecondary),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s5),
      decoration: BoxDecoration(color: context.colors.bgRaised, borderRadius: AppRadius.mdAll),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s3,
        children: children,
      ),
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
