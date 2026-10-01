import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/analytics/analytics.dart';
import '../../core/board/rooksight_board.dart';
import '../../core/config/api_keys.dart';
import '../../core/config/app_info.dart';
import '../../core/llm/gemini_client.dart';
import '../../core/llm/gemini_key.dart';
import '../../core/llm/llm_client.dart';
import '../../core/llm/llm_failure_text.dart';
import '../../core/routing/app_router.dart';
import '../../core/settings/display_settings.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/board_themes.dart';
import '../../core/widgets/segmented_switch.dart';
import '../import/domain/importer.dart' show ImportPlatform;
import '../scan/domain/scan_usage.dart';
import '../import/import_controller.dart';

/// Settings (`design/source/Settings.dc.html`). Sound, reduced motion and
/// review depth aren't in the design; they follow its card style.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s4, AppSpacing.s2, AppSpacing.s4, 32),
        children: [
          const _Section(title: 'Game import', child: _ImportCard()),
          const _Section(title: 'Board theme', child: _BoardThemes()),
          _Section(
            title: 'Appearance',
            child: SegmentedSwitch(
              values: const [ThemeMode.dark, ThemeMode.light, ThemeMode.system],
              selected: ref.watch(themeModeProvider),
              label: (mode) => switch (mode) {
                ThemeMode.dark => 'Dark',
                ThemeMode.light => 'Light',
                ThemeMode.system => 'System',
              },
              onSelect: ref.read(themeModeProvider.notifier).set,
            ),
          ),
          const _Section(title: 'Sound and motion', child: _SoundAndMotion()),
          const _Section(title: 'Game review', child: _ReviewDepth()),
          // Only builds that send usage stats offer to stop them.
          if (ApiKeys.hasTelemetryDeck) const _Section(title: 'Privacy', child: _UsageStats()),
          const _Section(title: 'Support Rooksight', child: _SupportCard()),
          _Section(
            title: 'Developer',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                const _DeveloperCard(),
                // The Gemini key is a developer setting.
                if (ref.watch(developerModeProvider)) const _AiCoachCard(),
              ],
            ),
          ),
          Text(
            '${AppInfo.name} ${AppInfo.version} · Stockfish runs on your device',
            textAlign: TextAlign.center,
            style: type.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// An overline heading and its content, 28 apart from the next.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Semantics(
        container: true,
        label: title,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text(
              title.toUpperCase(),
              style: context.type.overline.copyWith(color: context.colors.textSecondary),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

/// A raised card, 16 inside. A Material, so switch rows show their ripple.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.bgRaised,
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: children,
        ),
      ),
    );
  }
}

TextStyle _fieldLabel(BuildContext context) =>
    context.type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w500);

TextStyle _help(BuildContext context) =>
    context.type.body.copyWith(fontSize: 13, height: 19 / 13, color: context.colors.textSecondary);

/// One username per platform, each with its own Import.
class _ImportCard extends StatelessWidget {
  const _ImportCard();

  @override
  Widget build(BuildContext context) {
    return _Card(
      children: [
        const _UsernameRow(platform: ImportPlatform.chessCom),
        Divider(height: AppSpacing.s4, color: context.colors.border),
        const _UsernameRow(platform: ImportPlatform.lichess),
        Text(
          'Only public games are read. No login, no password. One username per site '
          'is kept on this phone.',
          style: _help(context),
        ),
      ],
    );
  }
}

class _UsernameRow extends ConsumerStatefulWidget {
  const _UsernameRow({required this.platform});

  final ImportPlatform platform;

  @override
  ConsumerState<_UsernameRow> createState() => _UsernameRowState();
}

class _UsernameRowState extends ConsumerState<_UsernameRow> {
  late final _username = TextEditingController(
    text: ref.read(importUsernameProvider(widget.platform)),
  );

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  void _save() =>
      ref.read(importUsernameProvider(widget.platform).notifier).set(_username.text.trim());

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final platform = widget.platform;
    final border = OutlineInputBorder(
      borderRadius: AppRadius.smAll,
      borderSide: BorderSide(color: colors.border),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s2,
      children: [
        Text('${platform.label} username', style: _fieldLabel(context)),
        Row(
          spacing: AppSpacing.s2,
          children: [
            Expanded(
              child: TextField(
                controller: _username,
                autocorrect: false,
                autofillHints: const [AutofillHints.username],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                onTapOutside: (_) {
                  _save();
                  FocusScope.of(context).unfocus();
                },
                style: type.body,
                decoration: InputDecoration(
                  hintText: 'Your ${platform.label} username',
                  hintStyle: type.body.copyWith(color: colors.textTertiary),
                  filled: true,
                  fillColor: colors.bgElevated,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: BorderSide(color: colors.focus)),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                _save();
                context.push(
                  platform == ImportPlatform.lichess ? Routes.importLichess : Routes.import,
                );
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4),
                shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
                textStyle: type.heading.copyWith(fontSize: 14),
              ),
              child: const Text('Import'),
            ),
          ],
        ),
      ],
    );
  }
}

/// Where a key test stands.
enum _KeyTest { untested, testing, works, failed }

class _AiCoachCard extends ConsumerStatefulWidget {
  const _AiCoachCard();

  @override
  ConsumerState<_AiCoachCard> createState() => _AiCoachCardState();
}

class _AiCoachCardState extends ConsumerState<_AiCoachCard> {
  final _input = TextEditingController();
  _KeyTest _test = _KeyTest.untested;
  Object? _error;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Saves the key and checks it straight away.
  Future<void> _save(String key) async {
    if (key.trim().isEmpty) return;
    await ref.read(savedGeminiKeyProvider.notifier).save(key);
    _input.clear();
    if (mounted) await _testKey();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '';
    if (text.trim().isNotEmpty) await _save(text);
  }

  Future<void> _remove() async {
    final removed = ref.read(savedGeminiKeyProvider);
    await ref.read(savedGeminiKeyProvider.notifier).remove();
    if (!mounted) return;
    setState(() {
      _test = _KeyTest.untested;
      _revealed = false;
    });
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Key removed'),
          action: removed == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  onPressed: () => ref.read(savedGeminiKeyProvider.notifier).save(removed),
                ),
        ),
      );
  }

  /// One tiny request, to see whether the key is accepted.
  Future<void> _testKey() async {
    setState(() => _test = _KeyTest.testing);
    try {
      await ref
          .read(llmClientProvider)
          .generate(const LlmRequest(messages: [LlmMessage.user('Reply with the word OK.')]));
      if (mounted) setState(() => _test = _KeyTest.works);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _test = _KeyTest.failed;
          _error = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final saved = ref.watch(savedGeminiKeyProvider);
    final field = BoxDecoration(
      color: colors.bgElevated,
      borderRadius: AppRadius.smAll,
      border: Border.all(color: colors.border),
    );
    final button = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      backgroundColor: colors.bgElevated,
      side: BorderSide(color: colors.border),
      foregroundColor: colors.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return _Card(
      children: [
        Row(
          children: [
            Expanded(child: Text('AI Coach key (Gemini)', style: _fieldLabel(context))),
            if (saved != null && _test == _KeyTest.works) const _KeyWorks(),
          ],
        ),
        if (saved == null) ...[
          TextField(
            controller: _input,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: _save,
            style: type.mono.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Paste your key',
              hintStyle: type.body.copyWith(fontSize: 14, color: colors.textTertiary),
              filled: true,
              fillColor: colors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide(color: colors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide(color: colors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.smAll,
                borderSide: BorderSide(color: colors.focus),
              ),
              suffixIcon: IconButton(
                tooltip: 'Paste',
                onPressed: _paste,
                color: colors.textSecondary,
                icon: const Icon(Icons.content_paste_rounded, size: 20),
              ),
            ),
          ),
          Text(
            'Stored only on this phone. The AI Coach runs only when you tap a button '
            'that asks for it.',
            style: _help(context),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _input.text.trim().isEmpty ? null : () => _save(_input.text),
              style: button,
              child: const Text('Save key'),
            ),
          ),
        ] else ...[
          Container(
            height: 48,
            padding: const EdgeInsets.only(left: 14, right: 2),
            decoration: field,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _revealed ? saved : _masked(saved),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.mono.copyWith(fontSize: 14, color: colors.textPrimary),
                  ),
                ),
                IconButton(
                  tooltip: _revealed ? 'Hide key' : 'Show key',
                  onPressed: () => setState(() => _revealed = !_revealed),
                  color: colors.textSecondary,
                  icon: Icon(
                    _revealed ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Stored only on this phone. The AI Coach runs only when you tap a button '
            'that asks for it.',
            style: _help(context),
          ),
          Text(
            'Board scans today: ${ref.watch(scanUsageProvider)} of ${ScanUsage.dailyLimit}.',
            style: _help(context),
          ),
          Row(
            spacing: AppSpacing.s2,
            children: [
              OutlinedButton(
                onPressed: _test == _KeyTest.testing ? null : _testKey,
                style: button,
                child: Text(_test == _KeyTest.testing ? 'Testing…' : 'Test key'),
              ),
              TextButton(
                onPressed: _remove,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  foregroundColor: colors.coral,
                  textStyle: type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
        if (saved != null && _test == _KeyTest.failed)
          Text(llmFailureText(_error), style: _help(context).copyWith(color: colors.coral)),
        // Open until there's a key; afterwards a tap away.
        _KeySteps(key: ValueKey(saved == null), initiallyExpanded: saved == null),
      ],
    );
  }

  /// Dots, with the last four characters to tell keys apart.
  static String _masked(String key) =>
      key.length <= 4 ? '•' * key.length : '${'•' * 12}${key.substring(key.length - 4)}';
}

/// The design's "Key works" badge.
class _KeyWorks extends StatelessWidget {
  const _KeyWorks();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 24,
      padding: const EdgeInsets.fromLTRB(4, 0, 8, 0),
      decoration: BoxDecoration(
        color: colors.focus.withValues(alpha: 0.14),
        borderRadius: AppRadius.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: colors.focus, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 11, color: colors.onFocus),
          ),
          Text(
            'Key works',
            style: context.type.label.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color.lerp(colors.focus, colors.textPrimary, 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Four mini boards to pick from.
class _BoardThemes extends ConsumerWidget {
  const _BoardThemes();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final selected = ref.watch(boardThemeProvider);
    return Row(
      spacing: 10,
      children: [
        for (final theme in BoardTheme.values)
          Expanded(
            child: Semantics(
              inMutuallyExclusiveGroup: true,
              checked: theme == selected,
              label: '${theme.label} board',
              child: Material(
                color: colors.bgRaised,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme == selected ? colors.focus : colors.bgRaised,
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => ref.read(boardThemeProvider.notifier).set(theme),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
                    child: Column(
                      spacing: 6,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) => RooksightStaticBoard(
                            fen: '8/8/8/3k4/8/4K3/8/8 w - - 0 1',
                            size: constraints.maxWidth,
                            theme: theme,
                            coordinates: false,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        Text(
                          theme.label,
                          style: context.type.body.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme == selected ? colors.textPrimary : colors.textSecondary,
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
    );
  }
}

class _SoundAndMotion extends ConsumerWidget {
  const _SoundAndMotion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final type = context.type;
    Widget toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) =>
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: _fieldLabel(context)),
          subtitle: Text(subtitle, style: _help(context)),
          value: value,
          onChanged: onChanged,
        );
    return DefaultTextStyle(
      style: type.body,
      child: _Card(
        children: [
          toggle(
            'Sound',
            'Move, capture, castle and check sounds.',
            ref.watch(soundEnabledProvider),
            ref.read(soundEnabledProvider.notifier).set,
          ),
          toggle(
            'Haptic feedback',
            'A light tap when pieces land, on captures and checks, and at low time.',
            ref.watch(hapticsEnabledProvider),
            ref.read(hapticsEnabledProvider.notifier).set,
          ),
          toggle(
            'Reduce motion',
            'Fades instead of slides. Follows your phone unless you turn it on here.',
            ref.watch(reduceMotionSettingProvider),
            ref.read(reduceMotionSettingProvider.notifier).set,
          ),
        ],
      ),
    );
  }
}

/// The anonymous usage stats toggle. Not in the design; follows its card style.
class _UsageStats extends ConsumerWidget {
  const _UsageStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Share anonymous usage stats', style: _fieldLabel(context)),
          subtitle: Text(
            'Counts like “a game was played” or “a board was scanned”, so I know what to '
            'improve. Never your games, chats, usernames or keys.',
            style: _help(context),
          ),
          value: ref.watch(usageStatsEnabledProvider),
          onChanged: ref.read(usageStatsEnabledProvider.notifier).set,
        ),
      ],
    );
  }
}

class _ReviewDepth extends ConsumerWidget {
  const _ReviewDepth();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      children: [
        Text('Stockfish analysis depth', style: _fieldLabel(context)),
        SegmentedSwitch(
          values: AnalysisDepth.values,
          selected: ref.watch(analysisDepthProvider),
          label: (option) => option.label,
          detail: (option) => 'depth ${option.plies}',
          trackColor: context.colors.bgBase,
          onSelect: ref.read(analysisDepthProvider.notifier).set,
        ),
        Text(
          'Deeper analysis is more accurate but takes longer. It all runs on this phone, '
          'offline.',
          style: _help(context),
        ),
      ],
    );
  }
}

/// A thank-you note and a link to Ko-fi. Not in the design; follows its card style.
class _SupportCard extends StatelessWidget {
  const _SupportCard();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Card(
      children: [
        Text('Enjoying ${AppInfo.name}?', style: _fieldLabel(context)),
        Text(
          '${AppInfo.name} is free, open source and has no ads. If it has helped you improve '
          'at chess, you can buy me a coffee. Thank you! – Amit Gupta',
          style: _help(context),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => _openLink(context, AppInfo.kofiUrl),
            icon: const Icon(Icons.coffee_outlined, size: 18),
            label: const Text('Support on Ko-fi'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: colors.bgElevated,
              side: BorderSide(color: colors.border),
              foregroundColor: colors.textPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: context.type.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

/// Opens [url] in the phone's browser; if that fails, copies it instead.
Future<void> _openLink(BuildContext context, String url) async {
  final opened = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  ).catchError((_) => false);
  if (opened || !context.mounted) return;
  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Couldn’t open the browser. Link copied.')));
}

/// A link in help text: focus blue, underlined, with an "opens outside" mark.
class _Link extends StatelessWidget {
  const _Link(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: () => _openLink(context, url),
        borderRadius: AppRadius.xsAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: _help(context).copyWith(
                    color: colors.focus,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: colors.focus,
                  ),
                ),
              ),
              Icon(Icons.open_in_new_rounded, size: 14, color: colors.focus),
            ],
          ),
        ),
      ),
    );
  }
}

/// How to get a free Gemini key, step by step, with links.
class _KeySteps extends StatelessWidget {
  const _KeySteps({super.key, required this.initiallyExpanded});

  final bool initiallyExpanded;

  static const studio = 'https://aistudio.google.com/apikey';
  static const limits = 'https://ai.google.dev/gemini-api/docs/rate-limits';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget step(int n, Widget child) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s2,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.bgElevated, shape: BoxShape.circle),
          child: Text('$n', style: context.type.label.copyWith(fontSize: 11)),
        ),
        Expanded(child: child),
      ],
    );
    return Theme(
      // No divider lines above and below the tile.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: AppSpacing.s1),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        iconColor: colors.textSecondary,
        collapsedIconColor: colors.textSecondary,
        title: Text('How to get a free key', style: _fieldLabel(context)),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              step(
                1,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open aistudio.google.com and sign in with a Google account.',
                      style: _help(context),
                    ),
                    const _Link('aistudio.google.com/apikey', studio),
                  ],
                ),
              ),
              step(2, Text('Tap “Get API key”, then “Create API key”.', style: _help(context))),
              step(3, Text('Copy the key, come back here and tap Paste.', style: _help(context))),
              step(
                4,
                Text(
                  'Tap Save key, then Test key. You should see “Key works”.',
                  style: _help(context),
                ),
              ),
              Text(
                'The free tier has per-minute and daily request limits. Rooksight sends one '
                'request per explanation, so everyday use normally fits. Google can change '
                'these limits; check AI Studio for today’s numbers.',
                style: _help(context),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: _Link('About the free-tier limits', limits),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Developer mode: off by default. When on, the AI Coach section (the
/// Gemini key) appears below it.
class _DeveloperCard extends ConsumerWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Card(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Developer mode', style: _fieldLabel(context)),
          subtitle: Text(
            'Shows advanced settings, including your own AI Coach key.',
            style: _help(context),
          ),
          value: ref.watch(developerModeProvider),
          onChanged: ref.read(developerModeProvider.notifier).set,
        ),
      ],
    );
  }
}
