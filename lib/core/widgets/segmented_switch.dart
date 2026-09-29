import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Equal-width options in a raised track, the chosen one filled (the stats
/// design's period switch).
class SegmentedSwitch<T> extends StatelessWidget {
  const SegmentedSwitch({
    super.key,
    required this.values,
    required this.selected,
    required this.label,
    required this.onSelect,
    this.detail,
    this.trackColor,
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  /// A second, smaller line under each label (e.g. `depth 18`).
  final String Function(T)? detail;

  /// Defaults to the raised surface; inside a card, the base one.
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(
        color: trackColor ?? colors.bgRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        spacing: AppSpacing.s1,
        children: [
          for (final value in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                child: Material(
                  color: value == selected
                      ? Color.alphaBlend(colors.focus.withValues(alpha: 0.28), colors.bgBase)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelect(value),
                    child: SizedBox(
                      height: detail == null ? 40 : 52,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        spacing: 1,
                        children: [
                          Text(
                            label(value),
                            style: type.body.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: value == selected ? colors.textPrimary : colors.textSecondary,
                            ),
                          ),
                          if (detail case final detail?)
                            Text(
                              detail(value),
                              style: type.mono.copyWith(
                                fontSize: 11,
                                height: 1.3,
                                color: value == selected
                                    ? Color.lerp(colors.focus, colors.textPrimary, 0.3)
                                    : colors.textTertiary,
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
