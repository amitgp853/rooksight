// Copyright (C) 2026 Amit Gupta
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/game_config.dart';

/// A section heading in caps, e.g. "PLAY AS".
class SectionOverline extends StatelessWidget {
  const SectionOverline(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.type.overline.copyWith(color: context.colors.textSecondary),
  );
}

/// The time controls as a 3-column grid of choices.
class TimeControlGrid extends StatelessWidget {
  const TimeControlGrid({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<TimeControl> options;
  final TimeControl value;
  final ValueChanged<TimeControl> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    // Selected text: a lighter focus blue in dark mode, as designed.
    final selectedText = Color.lerp(colors.focus, colors.textPrimary, 0.6)!;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.s2,
      crossAxisSpacing: AppSpacing.s2,
      childAspectRatio: 1.6,
      children: [
        for (final option in options)
          ChoiceButton(
            selected: option == value,
            onTap: () => onChanged(option),
            height: 68,
            radius: 14,
            background: colors.bgRaised,
            selectedColor: colors.focus.withValues(alpha: 0.14),
            selectedBorder: colors.focus,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 2,
              children: [
                Text(
                  option.label,
                  style: type.mono.copyWith(
                    fontSize: 17,
                    color: option == value ? selectedText : colors.textPrimary,
                  ),
                ),
                Text(
                  option.kind,
                  style: type.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
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

/// A selectable option: tinted (and outlined, with [selectedBorder]) when
/// [selected].
class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.selected,
    required this.onTap,
    required this.height,
    required this.selectedColor,
    required this.child,
    this.radius = 12,
    this.background = Colors.transparent,
    this.selectedBorder,
  });

  final bool selected;
  final VoidCallback onTap;
  final double height;
  final double radius;
  final Color background;
  final Color selectedColor;
  final Color? selectedBorder;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? selectedColor : background,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius,
          side: selected && selectedBorder != null
              ? BorderSide(color: selectedBorder!)
              : BorderSide(color: background),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
