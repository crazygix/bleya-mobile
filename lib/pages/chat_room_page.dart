import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../services/socket_service.dart';

class ChatRoomPage extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const ChatRoomPage({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  ConsumerState<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  SocketService? _socketService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupSocketListeners();
      _joinRoom();
    });
  }

  void _setupSocketListeners() {
    _socketService = ref.read(socketServiceProvider);
    final socketService = _socketService!;
    
    socketService.onRoomJoined((data) {
      if (!mounted) return;
      final messages = (data['messages'] as List)
          .map((m) => Message.fromJson(m))
          .toList();
      ref.read(roomMessagesProvider(widget.roomId).notifier).state = messages;
      _scrollToBottom();
    });

    socketService.onNewMessage((data) {
      if (!mounted) return;
      final message = Message.fromJson(data);
      if (message.roomId == widget.roomId) {
        ref.read(roomMessagesProvider(widget.roomId).notifier).state = [
          ...ref.read(roomMessagesProvider(widget.roomId)),
          message,
        ];
        _scrollToBottom();
      }
    });

    socketService.onError((data) {
      if (!mounted) return;
      final errorMsg = data['message'] ?? 'An error occurred';
      print('Socket error: $errorMsg');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
      
      // If "Not in a room" error, try to rejoin
      if (errorMsg.contains('Not in a room')) {
        print('Attempting to rejoin room...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _joinRoom();
          }
        });
      }
    });
  }

  void _joinRoom() {
    if (!mounted) return;
    _socketService ??= ref.read(socketServiceProvider);
    final socket = _socketService!.socket;
    
    if (socket == null || !socket.connected) {
      print('Socket not ready, waiting for connection...');
      // Wait for socket to connect
      socket?.once('connect', (_) {
        if (!mounted) return;
        print('Socket connected, joining room now');
        _socketService!.joinRoom(widget.roomId);
      });
    } else {
      _socketService!.joinRoom(widget.roomId);
    }
  }

  void _sendMessage() {
    if (!mounted) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _socketService ??= ref.read(socketServiceProvider);
    final socket = _socketService!.socket;
    
    if (socket == null || !socket.connected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not connected. Please wait...')),
      );
      return;
    }
    
    _socketService!.sendMessage(text);
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
    // Use stored reference instead of ref.read to avoid disposed widget error
    _socketService?.off('room_joined');
    _socketService?.off('new_message');
    _socketService?.off('error');
    _socketService?.leaveRoom();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(roomMessagesProvider(widget.roomId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
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
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message.phoneNumber,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(message.text),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

