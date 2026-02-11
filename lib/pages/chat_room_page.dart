import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../services/socket_service.dart';
import '../constants/theme.dart';
import '../utils/time_formatter.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/swipeable_message_bubble.dart';
import '../widgets/message_input_field.dart';
import '../widgets/glass_header.dart';
import '../widgets/liquid_glass_background.dart';
import 'user_details_page.dart';
import 'room_details_page.dart';
import 'thread_view_page.dart';

enum _ChatItemType { dateSeparator, message }

class _ChatListItem {
  final _ChatItemType type;
  final DateTime? date;
  final Message? message;

  const _ChatListItem.date(this.date)
      : type = _ChatItemType.dateSeparator,
        message = null;

  const _ChatListItem.message(this.message)
      : type = _ChatItemType.message,
        date = null;
}

class ChatRoomPage extends ConsumerStatefulWidget {
  final Room room;

  const ChatRoomPage({
    super.key,
    required this.room,
  });

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<List<Message>>? _messagesSubscription;
  ProviderSubscription<ChatRoomState>? _chatStateSubscription;
  StateController<String?>? _openRoomIdController;
  SocketService? _socketService;
  final Map<String, GlobalKey> _messageKeys = {};
  bool _isLoadingMoreTriggered = false;

  @override
  void initState() {
    super.initState();
    // Capture socket service reference immediately for dispose
    _socketService = ref.read(socketServiceProvider);
    _openRoomIdController = ref.read(currentOpenRoomIdProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Mark this room as currently open.
      _openRoomIdController?.state = widget.room.id;

      // Mark room as read locally and on backend
      ref.read(roomsListProvider.notifier).markRoomAsRead(widget.room.id);

      // Clear any old messages for this room to ensure fresh data
      ref.read(roomMessagesProvider(widget.room.id).notifier).state = [];

      // Initialize controller - it will automatically set up socket listeners and join room
      ref.read(chatRoomControllerProvider(widget.room).notifier);

      _messagesSubscription = ref.listenManual<List<Message>>(
        roomMessagesProvider(widget.room.id),
        (previous, next) {
          // With reverse: true, new messages (at the end of source list)
          // appear at the bottom (Index 0).
          // If the user is at the bottom (offset 0), they will see the new message immediately.
          // If they are scrolled up, they will stay at their offset.
        },
      );

      _scrollController.addListener(_onScroll);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final controller =
        ref.read(chatRoomControllerProvider(widget.room).notifier);
    controller.sendMessage(text);
    _messageController.clear();

    // Ensure we stay at the bottom when sending a message.
    _scrollToBottom(animated: true);
  }

  @override
  void dispose() {
    _socketService?.leaveRoom(widget.room.id);
    final openRoomIdController = _openRoomIdController;
    if (openRoomIdController?.state == widget.room.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (openRoomIdController?.state == widget.room.id) {
          openRoomIdController?.state = null;
        }
      });
    }
    _messagesSubscription?.close();
    _chatStateSubscription?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    // With reverse: true, pixels=0 is bottom, pixels=max is top.
    // We want to load more when user is scrolling up (increasing pixels) near the top.
    const threshold = 200.0;
    final distanceToTop = position.maxScrollExtent - position.pixels;

    if (distanceToTop < threshold && !_isLoadingMoreTriggered) {
      final state = ref.read(chatRoomControllerProvider(widget.room));
      if (state.hasMore && !state.isLoadingMore) {
        _isLoadingMoreTriggered = true;
        ref
            .read(chatRoomControllerProvider(widget.room).notifier)
            .loadOlderMessages()
            .then((_) {
          if (mounted) _isLoadingMoreTriggered = false;
        });
      }
    }
  }

  GlobalKey _messageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      const target = 0.0; // Bottom is 0 in reverse list
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  List<_ChatListItem> _buildChatItems(List<Message> messages) {
    if (messages.isEmpty) return const [];
    final items = <_ChatListItem>[];

    // Source messages are Oldest -> Newest.
    // We want the ListView(reverse: true) to have Index 0 = Bottom = Newest.
    // So we iterate backwards.
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      items.add(_ChatListItem.message(message));

      final isFirstMessage = i == 0;
      final createdAt = message.createdAt;
      final currentDate =
          DateTime(createdAt.year, createdAt.month, createdAt.day);

      if (isFirstMessage) {
        // This is the oldest message in the list (visually at the top).
        // Always show date above it.
        items.add(_ChatListItem.date(currentDate));
      } else {
        // Check if the previous (older) message has a different date.
        final prevMessage = messages[i - 1];
        final prevCreatedAt = prevMessage.createdAt;
        final prevDate = DateTime(
            prevCreatedAt.year, prevCreatedAt.month, prevCreatedAt.day);

        if (currentDate != prevDate) {
          items.add(_ChatListItem.date(currentDate));
        }
      }
    }

    return items;
  }

  Widget _buildChatLoadingSkeleton() {
    return ListView(
      padding: EdgeInsets.only(
        left: BleyaTheme.contentPadding,
        right: BleyaTheme.contentPadding,
        top: BleyaTheme.spacingLG,
        bottom: BleyaTheme.spacingLG,
      ),
      children: [
        Align(
          alignment: Alignment.center,
          child: AppSkeleton(
            width: 96,
            height: 28,
            borderRadius: BorderRadius.circular(BleyaTheme.radiusSmall),
          ),
        ),
        SizedBox(height: BleyaTheme.spacingLG),
        ...List.generate(
          7,
          (index) {
            final isCurrentUserBubble = index.isEven;
            return Padding(
              padding: const EdgeInsets.only(bottom: BleyaTheme.spacingMD),
              child: Align(
                alignment: isCurrentUserBubble
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCurrentUserBubble
                        ? BleyaTheme.primary.withValues(alpha: 0.08)
                        : BleyaTheme.glassSurface.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: BleyaTheme.border.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 90, height: 12),
                      SizedBox(height: 8),
                      AppSkeleton(height: 14),
                      SizedBox(height: 8),
                      AppSkeleton(width: 60, height: 11),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatRoomControllerProvider(widget.room));
    final messages = ref.watch(roomMessagesProvider(widget.room.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final chatItems = _buildChatItems(messages);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: BleyaTheme.background,
      resizeToAvoidBottomInset: false,
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
                title: widget.room.name,
                rightAction: GestureDetector(
                  onTap: () {
                    if (widget.room.isPrivate &&
                        widget.room.otherUserId != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => UserDetailsPage(
                            userId: widget.room.otherUserId!,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => RoomDetailsPage(
                            roomId: widget.room.id,
                            roomName: widget.room.name,
                          ),
                        ),
                      );
                    }
                  },
                  child: Icon(
                    CupertinoIcons.info,
                    size: 22,
                    color: BleyaTheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: messages.isEmpty && chatState.isInitialLoading
                    ? _buildChatLoadingSkeleton()
                    : messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages yet',
                              style: BleyaTheme.bodyMedium.copyWith(
                                fontSize: 16,
                                color: BleyaTheme.mutedForeground,
                              ),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            controller: _scrollController,
                            padding: EdgeInsets.only(
                              left: BleyaTheme.contentPadding,
                              right: BleyaTheme.contentPadding,
                              top: BleyaTheme.spacingLG,
                              bottom: BleyaTheme.spacingLG,
                            ),
                            itemCount: chatItems.length,
                            itemBuilder: (context, index) {
                              final item = chatItems[index];

                              if (item.type == _ChatItemType.dateSeparator) {
                                final locale = Localizations.localeOf(context)
                                    .toLanguageTag();
                                final label = formatMessageDateLabel(
                                  item.date!,
                                  locale: locale,
                                );
                                return _DateSeparatorLabel(
                                  label: label,
                                );
                              }

                              final message = item.message!;
                              final isCurrentUser = currentUserId != null &&
                                  message.userId == currentUserId;

                              return KeyedSubtree(
                                key: _messageKey(message.id),
                                child: SwipeableMessageBubble(
                                  message: message,
                                  isCurrentUser: isCurrentUser,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => ThreadViewPage(
                                          parentMessage: message,
                                          room: widget.room,
                                        ),
                                      ),
                                    );
                                  },
                                  onUsernameTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => UserDetailsPage(
                                          userId: message.userId,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: MessageInputField(
                  controller: _messageController,
                  onSend: _sendMessage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DateSeparatorLabel extends StatelessWidget {
  final String label;

  const _DateSeparatorLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: BleyaTheme.spacingLG,
            vertical: BleyaTheme.spacingSM,
          ),
          decoration: BoxDecoration(
            color: BleyaTheme.glassSurface.withValues(
              alpha: BleyaTheme.glassOpacity,
            ),
            borderRadius: BorderRadius.circular(
              BleyaTheme.radiusSmall,
            ),
            border: Border.all(
              color: BleyaTheme.border.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: BleyaTheme.glassShadow,
          ),
          child: Text(
            label,
            style: BleyaTheme.bodySmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: BleyaTheme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
