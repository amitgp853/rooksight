import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dialog_buttons.dart';
import '../play/domain/game_config.dart';
import '../play/widgets/setup_controls.dart';
import 'domain/pass_config.dart';
import 'domain/unfinished_pass_game.dart';
import 'widgets/side_chip.dart';

/// Pass & play setup (`PassSetup.dc.html`): the players' names and colours,
/// each player's clock, and how the board behaves.
class PassSetupScreen extends ConsumerStatefulWidget {
  const PassSetupScreen({super.key});

  @override
  ConsumerState<PassSetupScreen> createState() => _PassSetupScreenState();
}

class _PassSetupScreenState extends ConsumerState<PassSetupScreen> {
  late PassConfig _config = ref.read(passConfigProvider);
  late final _firstName = TextEditingController(text: _config.firstName);
  late final _secondName = TextEditingController(text: _config.secondName);

  @override
  void dispose() {
    _firstName.dispose();
    _secondName.dispose();
    super.dispose();
  }

  /// The config with the names as typed (blank falls back to the default).
  PassConfig get _named => _config.copyWith(
    firstName: PassConfig.cleanName(_firstName.text, PassConfig.defaultFirstName),
    secondName: PassConfig.cleanName(_secondName.text, PassConfig.defaultSecondName),
  );

  Future<void> _start() async {
    final unfinished = ref.read(unfinishedPassGameProvider);
    if (unfinished != null) {
      final config = unfinished.config;
      final abandon = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: context.colors.bgRaised,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Abandon your current game?'),
          content: Text(
            'Your game ${config.nameOf(Side.white)} vs ${config.nameOf(Side.black)} is saved '
            'on Home. Starting a new one ends it.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            ConfirmRow(
              cancelLabel: 'Keep it',
              onCancel: () => Navigator.of(context).pop(false),
              action: DestructiveButton(
                label: 'Start new game',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      );
      if (abandon != true || !mounted) return;
      ref.read(unfinishedPassGameProvider.notifier).clear();
    }
    ref.read(passConfigProvider.notifier).set(_named);
    // Replace setup, so Back from the game returns Home.
    context.pushReplacement(Routes.passGame);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    // Rebuilds as names are typed, for the Start button.
    final whiteName = _named.nameOf(Side.white);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pass & Play'),
            Text(
              'Two players on one phone',
              style: type.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.s2,
                  AppSpacing.gutter,
                  AppSpacing.s6,
                ),
                children: [
                  const SectionOverline('Players'),
                  const SizedBox(height: 10),
                  _Players(
                    config: _config,
                    firstName: _firstName,
                    secondName: _secondName,
                    onNameChanged: () => setState(() {}),
                    onSwap: () => setState(() => _config = _config.swapped),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(
                        () => _config = _config.copyWith(
                          firstSide: Random().nextBool() ? Side.white : Side.black,
                        ),
                      ),
                      child: const Text('Pick colours at random'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  const SectionOverline('Clock · each player'),
                  const SizedBox(height: 10),
                  TimeControlGrid(
                    options: TimeControl.passOptions,
                    value: _config.timeControl,
                    onChanged: (t) => setState(() => _config = _config.copyWith(timeControl: t)),
                  ),
                  const SizedBox(height: 26),
                  const SectionOverline('Board'),
                  const SizedBox(height: 10),
                  _Card(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 4),
                    children: [
                      _SwitchRow(
                        label: 'Flip board after each move',
                        hint: 'The player to move always sees their pieces at the bottom.',
                        value: _config.autoFlip,
                        onChanged: (on) => setState(() => _config = _config.withAutoFlip(on)),
                      ),
                      _SwitchRow(
                        label: 'Face-to-face layout',
                        hint:
                            'Phone lies flat between you; the top half is turned for your '
                            'opponent.',
                        value: _config.faceToFace,
                        onChanged: (on) => setState(() => _config = _config.withFaceToFace(on)),
                      ),
                      _SwitchRow(
                        label: 'Allow takebacks',
                        hint: 'The other player confirms each takeback.',
                        value: _config.takebacks,
                        onChanged: (on) =>
                            setState(() => _config = _config.copyWith(takebacks: on)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.s4,
                AppSpacing.gutter,
                AppSpacing.s3,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.s3,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: AppSpacing.s2,
                    children: [
                      Icon(Icons.save_outlined, size: 16, color: colors.textSecondary),
                      Text(
                        'Saved on this phone, ready for AI review',
                        style: type.label.copyWith(
                          fontWeight: FontWeight.w400,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  FilledButton(
                    onPressed: _start,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: type.heading,
                    ),
                    child: Text(
                      'Start · $whiteName plays White',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The two players, White first, with the swap button between them.
class _Players extends StatelessWidget {
  const _Players({
    required this.config,
    required this.firstName,
    required this.secondName,
    required this.onNameChanged,
    required this.onSwap,
  });

  final PassConfig config;
  final TextEditingController firstName;
  final TextEditingController secondName;
  final VoidCallback onNameChanged;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final whiteIsFirst = config.firstSide == Side.white;
    _PlayerRow row(Side side) {
      final first = (side == Side.white) == whiteIsFirst;
      return _PlayerRow(
        side: side,
        controller: first ? firstName : secondName,
        defaultName: first ? PassConfig.defaultFirstName : PassConfig.defaultSecondName,
        onChanged: onNameChanged,
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s4, vertical: 6),
          children: [row(Side.white), row(Side.black)],
        ),
        Positioned(
          right: -6,
          top: 0,
          bottom: 0,
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.bgBase, width: 3),
              ),
              child: IconButton.filled(
                tooltip: 'Swap colours',
                onPressed: onSwap,
                style: IconButton.styleFrom(
                  backgroundColor: colors.focus,
                  foregroundColor: colors.onFocus,
                ),
                constraints: const BoxConstraints.tightFor(width: 38, height: 38),
                icon: const Icon(Icons.swap_vert_rounded, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.side,
    required this.controller,
    required this.defaultName,
    required this.onChanged,
  });

  final Side side;
  final TextEditingController controller;
  final String defaultName;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final label = side == Side.white ? 'White · moves first' : 'Black · moves second';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
      // Room on the right for the swap button.
      child: Padding(
        padding: const EdgeInsets.only(right: 36),
        child: Row(
          spacing: 14,
          children: [
            SideChip(side: side),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    label,
                    style: type.label.copyWith(fontSize: 12, color: colors.textSecondary),
                  ),
                  SizedBox(
                    height: 40,
                    child: TextField(
                      controller: controller,
                      onChanged: (_) => onChanged(),
                      textCapitalization: TextCapitalization.words,
                      inputFormatters: [LengthLimitingTextInputFormatter(PassConfig.maxNameLength)],
                      style: type.body.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: defaultName,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        semanticCounterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A raised card whose rows are split by hairlines.
class _Card extends StatelessWidget {
  const _Card({required this.children, required this.padding});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: colors.bgElevated),
            child,
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    // The whole row toggles, not just the switch.
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
          child: Row(
            spacing: 14,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(label, style: type.body.copyWith(fontWeight: FontWeight.w500)),
                    Text(
                      hint,
                      style: type.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}
