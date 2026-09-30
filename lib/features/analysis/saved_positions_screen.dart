import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/move_wise_board.dart';
import '../../core/motion/reduce_motion.dart';
import '../../core/storage/saved_position_repository.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
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
      appBar: AppBar(title: const Text('Saved positions')),
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

    return Material(
      color: colors.bgRaised,
      borderRadius: AppRadius.mdAll,
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
    final choice = await showMoveWiseSheet<String>(
      context,
      reduceMotion: shouldReduceMotion(context, ref),
      // ListTiles paint their ink on a Material, not on the sheet's box.
      builder: (context) => Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                position.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.type.heading,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.of(context).pop('rename'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: context.colors.coral),
              title: Text('Delete', style: TextStyle(color: context.colors.coral)),
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    final repository = ref.read(savedPositionRepositoryProvider);
    switch (choice) {
      case 'rename':
        final name = await showDialog<String>(
          context: context,
          builder: (context) => _RenameDialog(initial: position.title),
        );
        if (name != null && name.isNotEmpty) await repository.rename(position.id, name);
      case 'delete':
        await repository.delete(position.id);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deleted “${position.title}”')));
        }
    }
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void done() => Navigator.of(context).pop(_name.text.trim());
    return AlertDialog(
      title: const Text('Rename'),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: 60,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => done(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: done, child: const Text('Save')),
      ],
    );
  }
}
