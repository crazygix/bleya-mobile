import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../platform/app_button.dart';
import '../platform/app_route.dart';
import '../services/socket_service.dart';
import '../utils/app_toast.dart';
import '../constants/theme.dart';
import '../widgets/app_skeleton.dart';
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
  late ProviderContainer _container;
  late SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = ref.read(socketServiceProvider);

    // Join the room to receive real-time updates for messages (including replies)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _socketService.joinRoom(widget.room);
      _socketService.openThread(widget.parentMessage.id);

      // Track that this thread is currently open
      ref.read(currentOpenThreadIdProvider.notifier).state =
          widget.parentMessage.id;
    });
  }

  /// A moderator removed the message this thread hangs off: close the thread.
  void _closeRemovedThread() {
    AppToast.showInfo(context, 'This message was removed.');
    final route = ModalRoute.of(context);
    if (route == null) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      // Another screen (e.g. a profile) is on top: remove only this one.
      Navigator.of(context).removeRoute(route);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Capture the container to use safely in dispose
    _container = ProviderScope.containerOf(context, listen: false);
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

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    // Clear right away as usual; the text comes back if the server doesn't
    // store the reply.
    _replyController.clear();

    final controller =
        ref.read(chatRoomControllerProvider(widget.room).notifier);
    final result = await controller.sendMessage(
      text,
      parentMessageId: widget.parentMessage.id,
    );
    if (!mounted) return;

    final error = result.error;
    if (error != null) {
      restoreUnsentDraft(_replyController, text);
      AppToast.showError(context, error.message);
    }

    // The reply will appear automatically via socket listener in threadMessagesProvider
  }

  @override
  void dispose() {
    _socketService.closeThread();

    // Defer to escape the unmount frame — Riverpod forbids state mutations
    // during widget disposal. Microtask (not Timer) so widget tests don't
    // trip the "Timer still pending" assertion on teardown. Swallow the
    // StateError that fires when the container itself is being torn down
    // (e.g. ProviderScope disposed in the same frame in tests).
    Future.microtask(() {
      try {
        _container.read(currentOpenThreadIdProvider.notifier).state = null;
      } on StateError {
        // Container already disposed; nothing to clear.
      }
    });

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
          AppRoute.build(
            builder: (context) => UserDetailsPage(
              userId: message.userId,
              showSayHeyButton: !widget.room.isPrivate,
              directRoomId: widget.room.isPrivate ? widget.room.id : null,
            ),
          ),
        );
      },
      showReplyBadge: false,
    );
  }

  Widget _buildThreadLoadingSkeleton() {
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: BleyaTheme.contentPadding,
        vertical: BleyaTheme.spacingLG,
      ),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: BleyaTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 120, height: 14),
                SizedBox(height: 8),
                AppSkeleton(height: 14),
                SizedBox(height: 8),
                AppSkeleton(width: 80, height: 12),
              ],
            ),
          ),
        ),
        const SizedBox(height: BleyaTheme.spacing2XL),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: BleyaTheme.foreground.withValues(alpha: 0.2),
              ),
            ),
            const SizedBox(width: BleyaTheme.spacingLG),
            Text(
              'Replies',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: BleyaTheme.mutedForeground,
              ),
            ),
            const SizedBox(width: BleyaTheme.spacingLG),
            Expanded(
              child: Container(
                height: 1,
                color: BleyaTheme.foreground.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
        const SizedBox(height: BleyaTheme.spacing2XL),
        ...List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: BleyaTheme.spacingLG),
            child: Align(
              alignment:
                  index.isEven ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 260),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: BleyaTheme.glassSurface.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: BleyaTheme.border.withValues(alpha: 0.25),
                  ),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSkeleton(width: 100, height: 14),
                    SizedBox(height: 8),
                    AppSkeleton(height: 14),
                    SizedBox(height: 8),
                    AppSkeleton(width: 72, height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final threadState =
        ref.watch(threadMessagesProvider(widget.parentMessage.id));

    ref.listen<bool>(threadParentRemovedProvider(widget.parentMessage.id),
        (previous, removed) {
      if (removed) _closeRemovedThread();
    });

    // Listen for new messages to auto-scroll
    ref.listen(threadMessagesProvider(widget.parentMessage.id),
        (previous, next) {
      next.whenData((data) {
        final replies = data.replies;
        if (replies.length > _previousReplyCount) {
          _scrollToBottom();
        }
        _previousReplyCount = replies.length;
      });
    });

    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final directChatStatusAsync =
        widget.room.isPrivate && widget.room.otherUserId != null
            ? ref.watch(directChatStatusProvider(widget.room.otherUserId!))
            : null;
    final directChatStatus = directChatStatusAsync?.valueOrNull;
    final isDirectMessagingBlocked =
        widget.room.isPrivate && (directChatStatus?.isBlocked ?? false);
    final blockedByMe = directChatStatus?.isBlockedByMe ?? false;

    return Scaffold(
      backgroundColor: BleyaTheme.background,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const LiquidGlassBackground(),
          Column(
            children: [
              GlassHeader(
                title: 'Thread',
              ),
              Expanded(
                child: threadState.when(
                  data: (data) {
                    final parentMessage = data.parentMessage;
                    final replies = withoutBlockedAuthors(
                      data.replies,
                      ref.watch(sessionBlockedUserIdsProvider),
                    );
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
                  loading: _buildThreadLoadingSkeleton,
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
                          AppButton(
                            onPressed: () {
                              ref.invalidate(threadMessagesProvider(
                                  widget.parentMessage.id));
                            },
                            variant: AppButtonVariant.filled,
                            color: BleyaTheme.primary,
                            borderRadius: BorderRadius.circular(
                              BleyaTheme.radiusSmall,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (isDirectMessagingBlocked)
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.fromLTRB(
                    BleyaTheme.contentPadding,
                    BleyaTheme.spacingSM,
                    BleyaTheme.contentPadding,
                    MediaQuery.of(context).padding.bottom +
                        BleyaTheme.footerBottomPadding,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: BleyaTheme.spacingMD,
                    vertical: BleyaTheme.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    color: BleyaTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
                    border: Border.all(
                      color: BleyaTheme.error.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    blockedByMe
                        ? 'You blocked this user. Unblock to send replies.'
                        : 'Messaging is unavailable in this chat.',
                    style: BleyaTheme.bodySmall.copyWith(
                      color: BleyaTheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (!isDirectMessagingBlocked)
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
