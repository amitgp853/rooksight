import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// The buttons at the foot of a confirmation, as on "Delete this game?":
/// the same height and shape everywhere.
ButtonStyle _base(BuildContext context) => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
  shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
  textStyle: context.type.heading.copyWith(fontSize: 16),
);

/// The quiet way out of a confirmation: raised fill, hairline border.
class CancelButton extends StatelessWidget {
  const CancelButton({super.key, required this.onPressed, this.label = 'Cancel'});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton(
      onPressed: onPressed,
      style: _base(context).copyWith(
        backgroundColor: WidgetStatePropertyAll(colors.bgElevated),
        foregroundColor: WidgetStatePropertyAll(colors.textPrimary),
        side: WidgetStatePropertyAll(BorderSide(color: colors.border)),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// The design system's destructive button (delete, resign): red text and a
/// red border, never a red fill.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = _base(context).copyWith(
      foregroundColor: WidgetStatePropertyAll(colors.coral),
      side: WidgetStatePropertyAll(BorderSide(color: colors.coral.withValues(alpha: 0.45))),
    );
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    final icon = this.icon;
    return icon == null
        ? OutlinedButton(onPressed: onPressed, style: style, child: text)
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: style,
            icon: Icon(icon, size: 20),
            label: text,
          );
  }
}

/// The main action of a confirmation that isn't destructive (Save, Offer
/// draw), the same size as [CancelButton].
class ConfirmButton extends StatelessWidget {
  const ConfirmButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSpacing.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s3),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        textStyle: context.type.heading.copyWith(fontSize: 16),
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Cancel and the main action side by side, equal widths: the foot of every
/// confirmation and name dialog.
class ConfirmRow extends StatelessWidget {
  const ConfirmRow({
    super.key,
    required this.onCancel,
    required this.action,
    this.cancelLabel = 'Cancel',
  });

  final VoidCallback onCancel;
  final String cancelLabel;

  /// A [DestructiveButton] or a [ConfirmButton].
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      spacing: AppSpacing.s3,
      children: [
        Expanded(
          child: CancelButton(onPressed: onCancel, label: cancelLabel),
        ),
        Expanded(child: action),
      ],
    );
  }
}
