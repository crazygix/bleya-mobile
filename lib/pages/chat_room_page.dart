import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../services/socket_service.dart';
import '../constants/theme.dart';
import '../utils/time_formatter.dart';
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
  SocketService? _socketService;
  bool _isLoadingMoreTriggered = false;
  bool _didScrollToInitialBottom = false;

  @override
  void initState() {
    super.initState();
    // Capture socket service reference immediately for dispose
    _socketService = ref.read(socketServiceProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clear any old messages for this room to ensure fresh data
      ref.read(roomMessagesProvider(widget.room.id).notifier).state = [];

      // Initialize controller - it will automatically set up socket listeners and join room
      ref.read(chatRoomControllerProvider(widget.room).notifier);

      // Keep subscription in case we need future side effects; currently unused.
      _messagesSubscription = ref.listenManual<List<Message>>(
        roomMessagesProvider(widget.room.id),
        (previous, next) {
          // No-op for now.
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
  }

  @override
  void dispose() {
    _socketService?.leaveRoom(widget.room.id);
    _messagesSubscription?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() async {
    if (!_scrollController.hasClients) return;

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

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatRoomControllerProvider(widget.room));
    final messages = ref.watch(roomMessagesProvider(widget.room.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final chatItems = _buildChatItems(messages);

    // After initial messages load, jump once to the bottom (no animation).
    if (!_didScrollToInitialBottom &&
        !chatState.isInitialLoading &&
        messages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      });
      _didScrollToInitialBottom = true;
    }

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
                    ? const Center(
                        child: CupertinoActivityIndicator(),
                      )
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
                        : Stack(
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: BleyaTheme.contentPadding,
                                  vertical: BleyaTheme.spacingLG,
                                ),
                                itemCount: chatItems.length,
                                itemBuilder: (context, index) {
                                  final item = chatItems[index];

                                  if (item.type == _ChatItemType.dateSeparator) {
                                    final locale =
                                        Localizations.localeOf(context)
                                            .toLanguageTag();
                                    final label = formatMessageDateLabel(
                                      item.date!,
                                      locale: locale,
                                    );
                                    return _DateSeparatorLabel(label: label);
                                  }

                                  final message = item.message!;
                                  final isCurrentUser = currentUserId != null &&
                                      message.userId == currentUserId;

                                  return SwipeableMessageBubble(
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
                                          builder: (context) =>
                                              UserDetailsPage(
                                            userId: message.userId,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
              ),
              MessageInputField(
                controller: _messageController,
                onSend: _sendMessage,
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
