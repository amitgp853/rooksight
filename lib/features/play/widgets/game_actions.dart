import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// One of the four buttons under the board: Hint, Undo, Flip, More.
class GameActionButton extends StatelessWidget {
  const GameActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.brass = false,
    this.locked = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// Brass styling, reserved for Hint.
  final bool brass;

  /// Shown at 45% with a lock, but still tappable (e.g. Undo outside
  /// practice mode opens the options sheet).
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = onPressed != null;
    final foreground = brass ? colors.brass : colors.textPrimary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: brass ? colors.brass.withValues(alpha: 0.45) : colors.bgRaised),
    );

    return Opacity(
      opacity: locked || !enabled ? 0.45 : 1,
      child: Material(
        color: brass ? colors.brass.withValues(alpha: 0.12) : colors.bgRaised,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 4,
              children: [
                Icon(locked ? Icons.lock_outline : icon, size: 22, color: foreground),
                Text(
                  label,
                  style: context.type.label.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foreground,
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
