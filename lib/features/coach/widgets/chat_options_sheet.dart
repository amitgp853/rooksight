import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/motion/reduce_motion.dart';
import '../../../core/storage/chat_repository.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/move_wise_sheet.dart';
import '../domain/coach_chat.dart';

/// A saved chat's options (`CoachHistoryDelete.dc.html`): Rename, and
/// Delete with its confirmation right there. Returns true if it was deleted.
Future<bool> showChatOptions(BuildContext context, WidgetRef ref, StoredChat chat) async {
  final action = await showMoveWiseSheet<_Action>(
    context,
    reduceMotion: shouldReduceMotion(context, ref),
    builder: (_) => _ChatOptions(chat: chat),
  );
  if (!context.mounted) return false;
  switch (action) {
    case _Action.rename:
      final title = await showDialog<String>(
        context: context,
        builder: (_) => _RenameDialog(title: chat.title),
      );
      if (title != null && title.trim().isNotEmpty && title.trim() != chat.title) {
        await ref.read(chatRepositoryProvider).rename(chat.id, title.trim());
      }
      return false;
    case _Action.delete:
      await ref.read(chatRepositoryProvider).delete(chat.id);
      return true;
    case null:
      return false;
  }
}

enum _Action { rename, delete }

class _ChatOptions extends StatelessWidget {
  const _ChatOptions({required this.chat});

  final StoredChat chat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    void close(_Action? action) => Navigator.of(context).pop(action);
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    final buttonText = type.body.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.s2,
      children: [
        Text(
          chat.title,
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
              Text('Delete this chat?', style: type.heading),
              Text(
                'The conversation is removed from this phone. Your games and their reviews '
                'stay. This can’t be undone.',
                style: type.body.copyWith(
                  fontSize: 14,
                  height: 20 / 14,
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s1),
              Row(
                spacing: AppSpacing.s2,
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => close(null),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(color: colors.border),
                        foregroundColor: colors.textPrimary,
                        shape: buttonShape,
                        textStyle: buttonText,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => close(_Action.delete),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: colors.coral,
                        foregroundColor: colors.bgBase,
                        shape: buttonShape,
                        textStyle: buttonText,
                      ),
                      child: const Text('Delete chat'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Not in the design: a small dialog in the app's style, the title ready to
/// edit.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.title});

  final String title;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _title = TextEditingController(text: widget.title)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.title.length);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isNotEmpty) Navigator.of(context).pop(_title.text);
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
      title: Text('Rename chat', style: type.heading),
      content: TextField(
        controller: _title,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        inputFormatters: [LengthLimitingTextInputFormatter(CoachMemory.titleLength)],
        style: type.body,
        decoration: InputDecoration(
          filled: true,
          fillColor: colors.bgElevated,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          enabledBorder: field,
          focusedBorder: field.copyWith(borderSide: BorderSide(color: colors.focus)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: _title.text.trim().isEmpty ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
