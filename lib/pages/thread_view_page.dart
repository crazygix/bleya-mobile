import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../constants/theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import 'user_details_page.dart';

class ThreadViewPage extends ConsumerStatefulWidget {
  final Message parentMessage;
  final Room room;

  const ThreadViewPage({
    super.key,
    required this.parentMessage,
    required this.room,
  });

  @override
  ConsumerState<ThreadViewPage> createState() => _ThreadViewPageState();
}

class _ThreadViewPageState extends ConsumerState<ThreadViewPage> {
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _previousReplyCount = 0;
  ProviderSubscription<AsyncValue<Map<String, dynamic>>>? _threadSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to thread state changes to auto-scroll when new replies arrive
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _threadSubscription = ref.listenManual<AsyncValue<Map<String, dynamic>>>(
        threadMessagesProvider(widget.parentMessage.id),
        (previous, next) {
          next.whenData((data) {
            final replies = data['replies'] as List<Message>;
            if (replies.length > _previousReplyCount) {
              _scrollToBottom();
            }
            _previousReplyCount = replies.length;
          });
        },
      );
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendReply() {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    final controller =
        ref.read(chatRoomControllerProvider(widget.room).notifier);
    controller.sendMessage(text, parentMessageId: widget.parentMessage.id);
    _replyController.clear();

    // The reply will appear automatically via socket listener in threadMessagesProvider
  }

  @override
  void dispose() {
    _threadSubscription?.close();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(Message message, bool isCurrentUser) {
    return MessageBubble(
      messageText: message.text,
      isCurrentUser: isCurrentUser,
      username: message.username,
      onUsernameTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserDetailsPage(
              userId: message.userId,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadState =
        ref.watch(threadMessagesProvider(widget.parentMessage.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thread'),
      ),
      body: threadState.when(
        data: (data) {
          final parentMessage = data['parentMessage'] as Message;
          final replies = data['replies'] as List<Message>;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Parent message section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: BleyaTheme.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: BleyaTheme.primaryMedium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (parentMessage.username.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => UserDetailsPage(
                                      userId: parentMessage.userId,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                parentMessage.username,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: BleyaTheme.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (parentMessage.username.isNotEmpty)
                            const SizedBox(height: 4),
                          Text(
                            parentMessage.text,
                            style: TextStyle(
                              fontSize: 16,
                              color: BleyaTheme.foreground87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: BleyaTheme.greyText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    if (replies.isNotEmpty)
                      Divider(color: BleyaTheme.greyBorder, thickness: 1),
                    if (replies.isNotEmpty) const SizedBox(height: 8),
                    // Replies section
                    ...replies.map((reply) {
                      final isCurrentUser = currentUserId != null &&
                          reply.userId == currentUserId;
                      return _buildMessageBubble(reply, isCurrentUser);
                    }),
                  ],
                ),
              ),
              MessageInputField(
                controller: _replyController,
                hintText: 'Reply to thread...',
                onSend: _sendReply,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: BleyaTheme.error),
              const SizedBox(height: 16),
              Text('Failed to load thread: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(
                      threadMessagesProvider(widget.parentMessage.id));
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
