import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/move_wise_board.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/storage/saved_position_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/dialog_buttons.dart';
import '../../core/widgets/move_wise_sheet.dart';
import '../games/games_screen.dart' show shortDate;
import 'domain/analysis_args.dart';

/// Positions saved from the analysis board (scans, set-ups, game positions),
/// newest first. Tap one to carry on analysing where you left off.
class SavedPositionsScreen extends ConsumerWidget {
  const SavedPositionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final positions = ref.watch(savedPositionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Saved Positions')),
      body: switch (positions) {
        AsyncData(value: final list) when list.isEmpty => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpacing.s3,
              children: [
                Icon(Icons.bookmark_border_rounded, size: 40, color: colors.textTertiary),
                Text('No saved positions yet', style: type.heading),
                Text(
                  'On the analysis board, tap the bookmark to keep a position here, '
                  'with the moves you explore.',
                  textAlign: TextAlign.center,
                  style: type.body.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ),
        AsyncData(value: final list) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s2,
            AppSpacing.gutter,
            AppSpacing.s8,
          ),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s2),
          itemBuilder: (context, i) => _PositionTile(position: list[i]),
        ),
        AsyncError() => Center(
          child: Text(
            'Saved positions couldn’t be loaded.',
            style: type.body.copyWith(color: colors.textSecondary),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PositionTile extends ConsumerWidget {
  const _PositionTile({required this.position});

  final SavedPosition position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final type = context.type;
    final moves = position.moveCount;
    final details = [
      switch (position.source) {
        'scan' => 'Scan',
        'game' => 'From a game',
        _ => 'Set up',
      },
      moves == 0 ? 'no moves yet' : '$moves ${moves == 1 ? 'move' : 'moves'} explored',
      shortDate(position.updatedAt),
    ].join(' · ');

    final light = Theme.of(context).brightness == Brightness.light;
    // Outlined in light mode, like the cards on Home.
    return Material(
      color: colors.bgRaised,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.mdAll,
        side: light ? BorderSide(color: colors.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AnalysisArgs(fen: position.fen).location, extra: position),
        onLongPress: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            spacing: AppSpacing.s3,
            children: [
              ExcludeSemantics(
                child: MoveWiseStaticBoard(
                  fen: position.fen,
                  size: 64,
                  coordinates: false,
                  orientation: position.orientation == 'black' ? Side.black : Side.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    Text(
                      position.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: type.heading.copyWith(fontSize: 15),
                    ),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: type.label.copyWith(
                        fontWeight: FontWeight.w400,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Options for ${position.title}',
                onPressed: () => _showOptions(context, ref),
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context, WidgetRef ref) async {
    final choice = await showMoveWiseSheet<_Action>(
      context,
      reduceMotion: shouldReduceMotion(context, ref),
      builder: (_) => _PositionOptions(position: position),
    );
    if (!context.mounted) return;
    final repository = ref.read(savedPositionRepositoryProvider);
    switch (choice) {
      case _Action.rename:
        final name = await showDialog<String>(
          context: context,
          builder: (_) => PositionNameDialog(title: 'Rename position', initial: position.title),
        );
        if (name != null && name != position.title) await repository.rename(position.id, name);
      case _Action.delete:
        await repository.delete(position.id);
      case null:
        break;
    }
  }
}

enum _Action { rename, delete }

/// A saved position's options, like a saved chat's: Rename, and Delete with
/// its confirmation right there.
class _PositionOptions extends StatelessWidget {
  const _PositionOptions({required this.position});

  final SavedPosition position;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    void close(_Action? action) => Navigator.of(context).pop(action);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s2,
      children: [
        Text(
          position.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.label.copyWith(fontWeight: FontWeight.w400, color: colors.textSecondary),
        ),
        Material(
          color: colors.bgElevated,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => close(_Action.rename),
            child: SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  spacing: AppSpacing.s3,
                  children: [
                    Icon(Icons.edit_outlined, size: 20, color: colors.textSecondary),
                    Text('Rename', style: type.body.copyWith(fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: AppSpacing.s2),
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: colors.bgElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.s2,
            children: [
              Text('Delete this position?', style: type.heading),
              Text(
                'It’s removed from this phone with the moves you explored. This can’t be '
                'undone.',
                style: type.body.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              ConfirmRow(
                onCancel: () => close(null),
                action: DestructiveButton(
                  label: 'Delete position',
                  onPressed: () => close(_Action.delete),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Names a position (saving or renaming), in the app's dialog style (as the
/// coach's Rename chat). Pops with the trimmed name, or null.
class PositionNameDialog extends StatefulWidget {
  const PositionNameDialog({
    super.key,
    required this.title,
    required this.initial,
    this.note,
    this.action = 'Save',
  });

  final String title;
  final String initial;

  /// A line under the field.
  final String? note;
  final String action;

  static const maxLength = 60;

  @override
  State<PositionNameDialog> createState() => _PositionNameDialogState();
}

class _PositionNameDialogState extends State<PositionNameDialog> {
  late final _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.border),
    );
    return AlertDialog(
      backgroundColor: colors.bgRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title, style: type.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.s3,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            inputFormatters: [LengthLimitingTextInputFormatter(PositionNameDialog.maxLength)],
            style: type.body,
            decoration: InputDecoration(
              filled: true,
              fillColor: colors.bgElevated,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              enabledBorder: field,
              focusedBorder: field.copyWith(borderSide: BorderSide(color: colors.focus)),
            ),
          ),
          if (widget.note case final note?)
            Text(
              note,
              style: type.label.copyWith(
                fontWeight: FontWeight.w400,
                height: 19 / 13,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        ConfirmRow(
          onCancel: () => Navigator.of(context).pop(),
          action: ConfirmButton(
            label: widget.action,
            onPressed: _name.text.trim().isEmpty ? null : _save,
          ),
        ),
      ],
    );
  }
}
