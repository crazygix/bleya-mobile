import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../services/socket_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_field.dart';
import 'user_details_page.dart';
import 'room_details_page.dart';
import 'thread_view_page.dart';

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

  @override
  Widget build(BuildContext context) {
    ref.watch(chatRoomControllerProvider(widget.room));

    final messages = ref.watch(roomMessagesProvider(widget.room.id));
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?['id'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.room.name),
        actions: [
          if (widget.room.isPrivate && widget.room.otherUserId != null)
            IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => UserDetailsPage(
                      userId: widget.room.otherUserId!,
                    ),
                  ),
                );
              },
              tooltip: 'View profile',
            )
          else
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => RoomDetailsPage(
                      roomId: widget.room.id,
                      roomName: widget.room.name,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(child: Text('No messages yet'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isCurrentUser = currentUserId != null &&
                          message.userId == currentUserId;

                      return MessageBubble(
                        messageText: message.text,
                        isCurrentUser: isCurrentUser,
                        username: message.username,
                        replyCount: message.replyCount,
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
            hintText: 'Type a message...',
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
