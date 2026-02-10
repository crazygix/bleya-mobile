import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../constants/theme.dart';
import '../widgets/swipeable_message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
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
    return SwipeableMessageBubble(
      message: message,
      isCurrentUser: isCurrentUser,
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
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              GlassHeader(
                leftAction: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 28,
                    color: BleyaTheme.primary,
                  ),
                ),
                title: 'Thread',
              ),
              Expanded(
                child: threadState.when(
                  data: (data) {
                    final parentMessage = data['parentMessage'] as Message;
                    final replies = data['replies'] as List<Message>;
                    final isParentCurrentUser = currentUserId != null &&
                        parentMessage.userId == currentUserId;

                    final hasReplies = replies.isNotEmpty;
                    final itemCount = hasReplies ? replies.length + 2 : 1;

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: BleyaTheme.contentPadding,
                        vertical: BleyaTheme.spacingLG,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildMessageBubble(
                            parentMessage,
                            isParentCurrentUser,
                          );
                        }

                        if (hasReplies && index == 1) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              top: BleyaTheme.spacing2XL,
                              bottom: BleyaTheme.spacing2XL,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: BleyaTheme.foreground
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                                const SizedBox(
                                  width: BleyaTheme.spacingLG,
                                ),
                                Text(
                                  'Replies',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: BleyaTheme.mutedForeground,
                                  ),
                                ),
                                const SizedBox(
                                  width: BleyaTheme.spacingLG,
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: BleyaTheme.foreground
                                        .withValues(alpha: 0.2),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final replyIndex = hasReplies ? index - 2 : index - 1;
                        final reply = replies[replyIndex];
                        final isCurrentUser = currentUserId != null &&
                            reply.userId == currentUserId;

                        return _buildMessageBubble(reply, isCurrentUser);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 48,
                            color: BleyaTheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load thread',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: BleyaTheme.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error.toString(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: BleyaTheme.mutedForeground,
                            ),
                          ),
                          const SizedBox(height: 24),
                          CupertinoButton.filled(
                            onPressed: () {
                              ref.invalidate(threadMessagesProvider(
                                  widget.parentMessage.id));
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              MessageInputField(
                controller: _replyController,
                onSend: _sendReply,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
