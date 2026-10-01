import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/board/rooksight_board.dart';
import '../../core/routing/app_router.dart';
import '../../core/storage/chat_repository.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/pill_search_field.dart';
import '../play/domain/game_controller.dart' show nowProvider;
import 'chats.dart';
import 'widgets/chat_options_sheet.dart';

/// What the Chats screen asks of the AI Coach screen when it closes.
enum ChatsResult {
  /// Start a new chat.
  newChat,
}

/// The saved AI Coach chats (`CoachHistory.dc.html`): searchable, grouped by
/// "This week" and "Earlier", each with its options. Opening one never runs
/// the AI.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  final _search = TextEditingController();

  /// The chat whose options are open, highlighted behind the sheet.
  int? _optionsFor;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Back to the AI Coach with a fresh chat.
  void _newChat() {
    if (context.canPop()) {
      context.pop(ChatsResult.newChat);
    } else {
      context.pushReplacement(Routes.coach);
    }
  }

  Future<void> _options(StoredChat chat) async {
    setState(() => _optionsFor = chat.id);
    await showChatOptions(context, ref, chat);
    if (mounted) setState(() => _optionsFor = null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final all = ref.watch(chatsProvider('')).value;
    final shown = ref.watch(chatsProvider(_search.text)).value ?? all;
    final now = ref.read(nowProvider)();
    final count = all?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chats'),
            Text(
              all == null ? '' : '${count == 1 ? '1 chat' : '$count chats'} · saved on this phone',
              style: type.label.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          NewChatPill(onPressed: _newChat),
          const SizedBox(width: AppSpacing.s3),
        ],
        shape: Border(bottom: BorderSide(color: colors.bgElevated)),
      ),
      body: SafeArea(
        child: switch (all) {
          null => const SizedBox.shrink(),
          [] => _Empty(onAsk: _newChat),
          _ => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, AppSpacing.gutter, 4),
                child: PillSearchField(controller: _search, hint: 'Search chats'),
              ),
              Expanded(
                child: _List(
                  chats: shown ?? const [],
                  now: now,
                  searching: _search.text.trim().isNotEmpty,
                  highlighted: _optionsFor,
                  onOpen: (chat) => context.push(Routes.coachChat(chat.id)),
                  onOptions: _options,
                ),
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.chats,
    required this.now,
    required this.searching,
    required this.highlighted,
    required this.onOpen,
    required this.onOptions,
  });

  final List<StoredChat> chats;
  final DateTime now;
  final bool searching;
  final int? highlighted;
  final ValueChanged<StoredChat> onOpen;
  final ValueChanged<StoredChat> onOptions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final (:thisWeek, :earlier) = groupChats(chats, now);
    Widget header(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 18, AppSpacing.gutter, 6),
      child: Text(label.toUpperCase(), style: type.overline.copyWith(color: colors.textTertiary)),
    );
    Widget row(StoredChat chat) => _ChatRow(
      chat: chat,
      now: now,
      highlighted: chat.id == highlighted,
      onOpen: () => onOpen(chat),
      onOptions: () => onOptions(chat),
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.s6),
      children: [
        if (chats.isEmpty && searching)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s8),
            child: Text(
              'No chats match.',
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
          ),
        if (thisWeek.isNotEmpty) ...[header('This week'), ...thisWeek.map(row)],
        if (earlier.isNotEmpty) ...[header('Earlier'), ...earlier.map(row)],
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.s4,
            AppSpacing.gutter,
            0,
          ),
          child: Text(
            'Chats are saved only on this phone. Opening one never runs the AI; it answers '
            'again only when you send a message.',
            textAlign: TextAlign.center,
            style: type.label.copyWith(
              fontSize: 12,
              height: 17 / 12,
              fontWeight: FontWeight.w400,
              color: colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.chat,
    required this.now,
    required this.highlighted,
    required this.onOpen,
    required this.onOptions,
  });

  final StoredChat chat;
  final DateTime now;
  final bool highlighted;
  final VoidCallback onOpen;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final preview = chat.preview?.replaceAll('\n', ' ');
    final small = type.label.copyWith(fontSize: 12, fontWeight: FontWeight.w400);

    return Material(
      color: highlighted ? colors.bgRaised : Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.gutter, 12, 4, 12),
                child: Row(
                  spacing: AppSpacing.s3,
                  children: [
                    ChatThumbnail(chat: chat, size: 44, radius: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 3,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            spacing: AppSpacing.s2,
                            children: [
                              Expanded(
                                child: Text(
                                  chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    height: 20 / 15,
                                  ),
                                ),
                              ),
                              Text(
                                chatWhen(chat.updatedAt, now),
                                style: small.copyWith(color: colors.textTertiary),
                              ),
                            ],
                          ),
                          if (preview != null && preview.isNotEmpty)
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.label.copyWith(
                                fontWeight: FontWeight.w400,
                                color: colors.textSecondary,
                              ),
                            ),
                          Text(
                            '${chat.scopeLabel} · ${messagesLabel(chat.messageCount)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: small.copyWith(color: colors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              tooltip: 'Options for ${chat.title}',
              onPressed: onOptions,
              color: colors.textSecondary,
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// A chat's picture: the game position it's about, or a chart for
/// questions across many games.
class ChatThumbnail extends StatelessWidget {
  const ChatThumbnail({super.key, required this.chat, required this.size, required this.radius});

  final StoredChat chat;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fen = chat.thumbFen;
    if (fen != null) {
      return RooksightStaticBoard(
        fen: fen,
        size: size,
        coordinates: false,
        borderRadius: BorderRadius.circular(radius),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        chat.gameId == null ? Icons.bar_chart_rounded : Icons.chat_bubble_outline_rounded,
        size: size * 0.5,
        color: colors.focus,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAsk});

  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 24, 32, 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.s3,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colors.bgRaised,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, size: 28, color: colors.focus),
            ),
            const SizedBox(height: 4),
            Text('No chats yet', style: type.title.copyWith(fontSize: 20)),
            Text(
              'Your conversations with the AI Coach are kept here on your phone, so you can '
              'reopen one and carry on any time.',
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s3),
            FilledButton(
              onPressed: onAsk,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 52),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: type.body.copyWith(fontWeight: FontWeight.w600),
              ),
              child: const Text('Ask the AI Coach'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The outlined "New chat" pill, with a plus; it never wraps.
class NewChatPill extends StatelessWidget {
  const NewChatPill({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 34),
        fixedSize: const Size.fromHeight(34),
        padding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.border),
        shape: const StadiumBorder(),
        textStyle: context.type.label.copyWith(fontWeight: FontWeight.w600),
      ),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: const Text('New chat', maxLines: 1, softWrap: false),
    );
  }
}
