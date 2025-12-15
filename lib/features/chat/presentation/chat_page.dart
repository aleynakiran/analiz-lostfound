import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:campus_lost_found/features/chat/domain/chat_message.dart';
import 'package:campus_lost_found/providers/providers.dart';
import 'package:campus_lost_found/features/found_items/domain/found_item.dart';
import 'package:campus_lost_found/features/claims/domain/claim_request.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String itemId;

  const ChatPage({
    super.key,
    required this.itemId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(
    FoundItem item,
    ClaimRequest approvedClaim,
    AppUser user,
  ) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final chatRepo = ref.read(chatRepositoryProvider);

    await chatRepo.sendMessage(
      itemId: item.id,
      senderUid: user.id,
      text: text,
      finderUid: item.createdByOfficerId,
      claimantUid: approvedClaim.requesterStudentNo ?? user.id,
    );

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(foundItemsProvider);
    final claims = ref.watch(claimsProvider);
    final user = ref.watch(currentUserProvider);

    FoundItem? item;
    try {
      item = items.firstWhere((i) => i.id == widget.itemId);
    } catch (_) {
      item = null;
    }

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Item not found')),
      );
    }

    final approvedClaims = claims
        .where(
          (c) =>
              c.itemId == widget.itemId && c.status == ClaimStatus.approved,
        )
        .toList();

    if (approvedClaims.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(
          child: Text('Chat is available only after a claim is approved.'),
        ),
      );
    }

    final approvedClaim = approvedClaims.first;

    final messagesAsync = ref.watch(chatMessagesProvider(widget.itemId));

    return Scaffold(
      appBar: AppBar(
        title: Text('Chat • ${item.title}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                      _scrollController.position.maxScrollExtent,
                    );
                  }
                });

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('Start the conversation about this item.'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderUid == user.id;
                    return _MessageBubble(
                      message: msg,
                      isMe: isMe,
                    );
                  },
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                child: Text('Failed to load messages'),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () =>
                        _sendMessage(item!, approvedClaim, user),
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor =
        isMe ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant;
    final textColor =
        isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft:
                  isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight:
                  isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                TimeOfDay.fromDateTime(message.createdAt).format(context),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


