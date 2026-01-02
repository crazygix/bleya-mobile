import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
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

    final controller = ref.read(chatRoomControllerProvider(widget.room).notifier);
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue[600] : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isCurrentUser && message.username.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => UserDetailsPage(
                          userId: message.userId,
                        ),
                      ),
                    );
                  },
                  child: Text(
                    message.username,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              if (!isCurrentUser && message.username.isNotEmpty)
                const SizedBox(height: 4),
              Text(
                message.text,
                style: TextStyle(
                  color: isCurrentUser ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadState = ref.watch(threadMessagesProvider(widget.parentMessage.id));
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
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
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
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (parentMessage.username.isNotEmpty)
                            const SizedBox(height: 4),
                          Text(
                            parentMessage.text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Divider
                    if (replies.isNotEmpty)
                      Divider(color: Colors.grey[300], thickness: 1),
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      spreadRadius: 1,
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: InputDecoration(
                          hintText: 'Reply to thread...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendReply,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Failed to load thread: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(threadMessagesProvider(widget.parentMessage.id));
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

