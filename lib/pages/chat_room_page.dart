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
  int _previousMessageCount = 0;
  ProviderSubscription<List<Message>>? _messagesSubscription;
  SocketService? _socketService;

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

      // Listen to messages to auto-scroll
      _messagesSubscription = ref.listenManual<List<Message>>(
        roomMessagesProvider(widget.room.id),
        (previous, next) {
          if (next.length > _previousMessageCount) {
            _scrollToBottom();
          }
          _previousMessageCount = next.length;
        },
      );
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

  @override
  void dispose() {
    _socketService?.leaveRoom(widget.room.id);
    _messagesSubscription?.close();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
    ref.watch(chatRoomControllerProvider(widget.room));

    final messages = ref.watch(roomMessagesProvider(widget.room.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;
    final chatItems = _buildChatItems(messages);

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
                child: messages.isEmpty
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: BleyaTheme.contentPadding,
                          vertical: BleyaTheme.spacingLG,
                        ),
                        itemCount: chatItems.length,
                        itemBuilder: (context, index) {
                          final item = chatItems[index];

                          if (item.type == _ChatItemType.dateSeparator) {
                            final locale =
                                Localizations.localeOf(context).toLanguageTag();
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
                                  builder: (context) => UserDetailsPage(
                                    userId: message.userId,
                                  ),
                                ),
                              );
                            },
                          );
                        },
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
