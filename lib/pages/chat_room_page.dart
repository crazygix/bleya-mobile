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
  bool _didSetInitialPosition = false;
  bool _didMarkRoomAsRead = false;
  bool _isInitialPositionScheduled = false;
  bool _isForcingInitialScroll = false;
  bool _isForcingKeyboardScroll = false;
  double _lastKeyboardInset = 0;

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

      // Clear any old messages for this room to ensure fresh data
      ref.read(roomMessagesProvider(widget.room.id).notifier).state = [];

      // Initialize controller - it will automatically set up socket listeners and join room
      ref.read(chatRoomControllerProvider(widget.room).notifier);

      _messagesSubscription = ref.listenManual<List<Message>>(
        roomMessagesProvider(widget.room.id),
        (previous, next) {
          final previousList = previous ?? const <Message>[];
          final nextList = next;

          if (!_didSetInitialPosition) {
            _scheduleInitialPositioning();
          }

          // Only react when a new message is appended (not when loading older history).
          final addedNewMessage =
              previousList.isNotEmpty && nextList.length > previousList.length;

          if (!addedNewMessage) {
            return;
          }

          if (!_scrollController.hasClients) {
            return;
          }

          final position = _scrollController.position;
          const threshold = 80.0;
          final isNearBottom =
              position.pixels >= (position.maxScrollExtent - threshold);

          // Auto-scroll only if user was already near the bottom.
          if (isNearBottom) {
            _scrollToBottom(animated: true);
          }
        },
      );

      _chatStateSubscription = ref.listenManual<ChatRoomState>(
        chatRoomControllerProvider(widget.room),
        (previous, next) {
          if (!_didSetInitialPosition && !next.isInitialLoading) {
            _scheduleInitialPositioning();
          }
        },
      );

      final currentMessages = ref.read(roomMessagesProvider(widget.room.id));
      if (!_didSetInitialPosition && currentMessages.isNotEmpty) {
        _scheduleInitialPositioning();
      }

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

  void _onScroll() async {
    if (!_scrollController.hasClients) return;
    if (!_didSetInitialPosition) return;

    final position = _scrollController.position;
    // Trigger loading older messages when user scrolls near the top.
    const thresholdPixels = 400.0;
    if (position.pixels > thresholdPixels || _isLoadingMoreTriggered) {
      return;
    }

    final state = ref.read(chatRoomControllerProvider(widget.room));
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }

    _isLoadingMoreTriggered = true;

    // Capture current scroll metrics before loading older messages so we can
    // preserve the visible position after prepending.
    final oldMaxExtent = position.maxScrollExtent;
    final oldPixels = position.pixels;
    final distanceFromBottom = oldMaxExtent - oldPixels;

    final controller =
        ref.read(chatRoomControllerProvider(widget.room).notifier);

    await controller.loadOlderMessages();

    if (!mounted || !_scrollController.hasClients) {
      _isLoadingMoreTriggered = false;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        _isLoadingMoreTriggered = false;
        return;
      }

      final newPosition = _scrollController.position;
      final newMaxExtent = newPosition.maxScrollExtent;
      final targetOffset =
          (newMaxExtent - distanceFromBottom).clamp(0.0, newMaxExtent);

      _scrollController.jumpTo(targetOffset);
      _isLoadingMoreTriggered = false;
    });
  }

  GlobalKey _messageKey(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  Message? _findFirstUnreadMessage({
    required List<Message> messages,
    required DateTime? lastReadAt,
  }) {
    if (messages.isEmpty) return null;
    if (lastReadAt == null) return messages.first;

    final lastReadMs = lastReadAt.millisecondsSinceEpoch;
    for (final message in messages) {
      if (message.createdAt.millisecondsSinceEpoch > lastReadMs) {
        return message;
      }
    }

    return null;
  }

  void _markRoomAsReadOnce() {
    if (_didMarkRoomAsRead) return;
    _didMarkRoomAsRead = true;
    ref.read(roomsListProvider.notifier).markRoomAsRead(widget.room.id);
  }

  void _scheduleInitialPositioning() {
    if (!mounted || _didSetInitialPosition || _isInitialPositionScheduled) {
      return;
    }

    _isInitialPositionScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isInitialPositionScheduled = false;

      if (!mounted || _didSetInitialPosition) return;

      final chatState = ref.read(chatRoomControllerProvider(widget.room));
      final messages = ref.read(roomMessagesProvider(widget.room.id));

      if (chatState.isInitialLoading) {
        _scheduleInitialPositioning();
        return;
      }

      if (messages.isEmpty) {
        _didSetInitialPosition = true;
        _markRoomAsReadOnce();
        return;
      }

      final firstUnreadMessage = _findFirstUnreadMessage(
        messages: messages,
        lastReadAt: chatState.lastReadAt,
      );

      if (firstUnreadMessage == null) {
        _forceInitialScrollToBottom(onComplete: _markRoomAsReadOnce);
        return;
      }

      if (!_scrollController.hasClients) {
        _scheduleInitialPositioning();
        return;
      }

      final chatItems = _buildChatItems(messages);
      final targetItemIndex = chatItems.indexWhere(
        (item) =>
            item.type == _ChatItemType.message &&
            item.message?.id == firstUnreadMessage.id,
      );

      if (targetItemIndex == -1) {
        _scheduleInitialPositioning();
        return;
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      if (maxExtent > 0 && chatItems.length > 1) {
        final ratio = targetItemIndex / (chatItems.length - 1);
        final roughOffset = (maxExtent * ratio).clamp(0.0, maxExtent);
        _scrollController.jumpTo(roughOffset);
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didSetInitialPosition) return;

        final targetContext = _messageKey(firstUnreadMessage.id).currentContext;
        if (targetContext == null) {
          _scheduleInitialPositioning();
          return;
        }

        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          alignment: 0.12,
        ).whenComplete(() {
          if (!mounted) return;
          _didSetInitialPosition = true;
          _markRoomAsReadOnce();
        });
      });
    });
  }

  void _forceInitialScrollToBottom({VoidCallback? onComplete}) {
    if (!mounted || _didSetInitialPosition || _isForcingInitialScroll) return;

    _isForcingInitialScroll = true;
    Future(() async {
      var performedJump = false;
      // Retry for a short period so late layout/padding changes don't leave us
      // above the latest message on first open.
      for (var attempt = 0; attempt < 40; attempt++) {
        if (!mounted) return;

        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!_scrollController.hasClients) {
          continue;
        }

        performedJump = true;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      if (!mounted) return;
      _isForcingInitialScroll = false;
      if (!performedJump) {
        Future<void>.delayed(
          const Duration(milliseconds: 100),
          () => _forceInitialScrollToBottom(onComplete: onComplete),
        );
        return;
      }

      _didSetInitialPosition = true;
      onComplete?.call();
    });
  }

  void _forceScrollToBottomForKeyboard() {
    if (!mounted || _isForcingKeyboardScroll) return;

    _isForcingKeyboardScroll = true;
    Future(() async {
      // Keep jumping while keyboard and input field finish animating.
      for (var attempt = 0; attempt < 35; attempt++) {
        if (!mounted) return;

        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!_scrollController.hasClients) {
          continue;
        }

        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      if (!mounted) return;
      _isForcingKeyboardScroll = false;
    });
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
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
    final items = <_ChatListItem>[];
    DateTime? lastDate;

    for (final message in messages) {
      final createdAt = message.createdAt;
      final currentDate =
          DateTime(createdAt.year, createdAt.month, createdAt.day);

      if (lastDate == null ||
          currentDate.year != lastDate.year ||
          currentDate.month != lastDate.month ||
          currentDate.day != lastDate.day) {
        items.add(_ChatListItem.date(currentDate));
        lastDate = currentDate;
      }

      items.add(_ChatListItem.message(message));
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
    if (keyboardInset != _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (keyboardInset > 0) {
          _forceScrollToBottomForKeyboard();
        }
      });
    }

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
