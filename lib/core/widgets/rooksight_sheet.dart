import 'package:flutter/material.dart';

import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Scrim behind sheets: rgba(8, 11, 15, 0.55).
const _scrim = Color(0x8C080B0F);

/// Sheet motion from the spec: slide up over 320ms.
const _sheetCurve = Cubic(0.2, 0.9, 0.3, 1);

/// Shows a bottom sheet in the Rooksight style. With [reduceMotion] it fades
/// in (200ms) instead of sliding.
Future<T?> showRooksightSheet<T>(
  BuildContext context, {
  required bool reduceMotion,
  required WidgetBuilder builder,
}) {
  if (reduceMotion) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: _scrim,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => Align(
        alignment: Alignment.bottomCenter,
        child: Material(
          type: MaterialType.transparency,
          child: _SheetFrame(child: builder(context)),
        ),
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    barrierColor: _scrim,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 320),
      curve: _sheetCurve,
      reverseDuration: Duration(milliseconds: 200),
    ),
    builder: (context) => _SheetFrame(child: builder(context)),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        10,
        AppSpacing.gutter,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: colors.bgRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: const [
          BoxShadow(color: Color(0x80000000), blurRadius: 40, offset: Offset(0, -16)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.s3),
              decoration: BoxDecoration(
                color: colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
