// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_info.dart';
import '../../../core/motion/reduce_motion.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/rooksight_sheet.dart';

/// Opens Settings at the AI Coach section. Completes when the player comes
/// back, so callers can check whether a key was added.
Future<void> openAiSetup(BuildContext context) => context.push(Routes.settingsAi);

/// Why the AI features need the player's own Gemini key, what it costs
/// (nothing) and what it unlocks. "Turn on AI coach" opens Settings; [inSettings]
/// leaves it out, since the key field is already on screen. Not in the
/// design; follows its sheet style.
Future<void> showAiSetupSheet(
  BuildContext context,
  WidgetRef ref, {
  bool inSettings = false,
}) async {
  final setUp = await showRooksightSheet<bool>(
    context,
    reduceMotion: shouldReduceMotion(context, ref),
    builder: (context) => _AiSetupSheet(inSettings: inSettings),
  );
  if (setUp == true && context.mounted) await openAiSetup(context);
}

class _AiSetupSheet extends StatelessWidget {
  const _AiSetupSheet({required this.inSettings});

  final bool inSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    const name = AppInfo.name;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.s4,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppSpacing.s1,
                  children: [
                    Text('Turn on your AI coach', style: type.title.copyWith(fontSize: 20)),
                    Text(
                      'Free · about 2 minutes · only once',
                      style: type.body.copyWith(color: colors.textSecondary),
                    ),
                  ],
                ),
                const _Point(
                  icon: Icons.auto_awesome_outlined,
                  title: 'What you get',
                  body:
                      'Ask the coach about your games, see your mistakes explained in plain '
                      'words, and scan a board from a photo.',
                ),
                const _Point(
                  icon: Icons.help_outline_rounded,
                  title: 'Why do I need to do this?',
                  body:
                      '$name is free and has no ads, so it can’t pay for an AI for everyone. '
                      'Google gives every person a free “key”, a code that switches the AI '
                      'on. You copy it from Google’s website and paste it here. That’s it.',
                ),
                const _Point(
                  icon: Icons.money_off_rounded,
                  title: 'Is it really free?',
                  body:
                      'Yes. You just sign in with your Google account, with no card and no '
                      'payment. It covers normal daily use. If you use it a lot in one day, '
                      '$name tells you, and it works again the next day.',
                ),
                const _Point(
                  icon: Icons.lock_outline_rounded,
                  title: 'Is it safe?',
                  body:
                      'Your key stays on this phone. Your questions go only to Google, never '
                      'to us.',
                ),
                const _Point(
                  icon: Icons.verified_outlined,
                  title: 'Why not just ask ChatGPT?',
                  body:
                      'Chatbots often get chess moves wrong. $name’s coach looks at your '
                      'games, and a chess engine checks every move before you see it.',
                ),
                const _Point(
                  icon: Icons.trending_up_rounded,
                  title: 'Want more?',
                  body:
                      'If you already pay for Google’s AI, use that key instead and ask as '
                      'much as you like.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s5),
        if (inSettings)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Got it'),
          )
        else ...[
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Turn on AI coach'),
          ),
          const SizedBox(height: AppSpacing.s2),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              foregroundColor: colors.textSecondary,
            ),
            child: const Text('Not now'),
          ),
        ],
      ],
    );
  }
}

/// One reason: an icon, a short title and a sentence or two.
class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.s3,
      children: [
        Icon(icon, size: 20, color: colors.focus),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(title, style: type.body.copyWith(fontWeight: FontWeight.w600)),
              Text(
                body,
                style: type.body.copyWith(
                  fontSize: 13,
                  height: 19 / 13,
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The ⓘ that opens [showAiSetupSheet], next to a "not set up" message.
class AiInfoButton extends ConsumerWidget {
  const AiInfoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Why turn on the AI coach?',
      onPressed: () => showAiSetupSheet(context, ref),
      color: context.colors.textSecondary,
      icon: const Icon(Icons.info_outline_rounded, size: 20),
    );
  }
}

/// "Turn on AI coach (free)" and its ⓘ, for places that need the AI but have no key.
/// [onSetUp] runs instead of opening Settings directly, for screens that
/// carry on once a key is added.
class AiSetupActions extends StatelessWidget {
  const AiSetupActions({super.key, this.onSetUp});

  final Future<void> Function()? onSetUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: AppSpacing.s1,
      children: [
        OutlinedButton.icon(
          onPressed: onSetUp ?? () => openAiSetup(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.key_rounded, size: 18),
          label: const Text('Turn on AI coach (free)'),
        ),
        const AiInfoButton(),
      ],
    );
  }
}
