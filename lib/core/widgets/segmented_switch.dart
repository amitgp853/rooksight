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
  });

  final List<T> values;
  final T selected;
  final String Function(T) label;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s1),
      decoration: BoxDecoration(color: colors.bgRaised, borderRadius: BorderRadius.circular(14)),
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
                      height: 40,
                      child: Center(
                        child: Text(
                          label(value),
                          style: type.body.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: value == selected ? colors.textPrimary : colors.textSecondary,
                          ),
                        ),
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
