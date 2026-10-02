import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/chat_providers.dart';
import '../providers/auth_providers.dart';
import '../platform/app_button.dart';
import '../platform/app_icon.dart';
import '../platform/app_route.dart';
import '../utils/app_toast.dart';
import '../utils/navigation.dart';
import '../widgets/report_actions.dart';
import '../services/socket_service.dart';
import '../constants/theme.dart';
import '../utils/time_formatter.dart';
import '../widgets/app_skeleton.dart';
import '../widgets/error_state.dart';
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

class _ChatRoomPageState extends ConsumerState<ChatRoomPage> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  ProviderSubscription<List<Message>>? _messagesSubscription;
  ProviderSubscription<ChatRoomState>? _chatStateSubscription;
  late final SocketService _socketService;
  // This screen's hold on the room: the socket stays in it while this is
  // the newest chat screen.
  late final RoomClaim _claim;
  StreamSubscription<String>? _errorSubscription;
  final Map<String, GlobalKey> _messageKeys = {};
  bool _isLoadingMoreTriggered = false;

  @override
  void initState() {
    super.initState();
    // Capture socket service reference immediately for dispose
    _socketService = ref.read(socketServiceProvider);
    // Claim in push order, so the screen on top decides the room.
    _claim = _socketService.claimRoom(widget.room);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // The controller keeps the room's messages live. Another screen for
      // this room may already be in it, so make sure this one loads.
      ref.read(chatRoomControllerProvider(widget.room).notifier).ensureLoaded();

      // Surface user-facing socket errors (e.g. a content-filter rejection of a
      // message the user just sent).
      _errorSubscription = ref
          .read(chatRoomControllerProvider(widget.room).notifier)
          .errorMessages
          .listen((message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      });

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

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    // Clear right away as usual; the text comes back if the server doesn't
    // store the message.
    _messageController.clear();

    // Ensure we stay at the bottom when sending a message.
    _scrollToBottom(animated: true);

    final controller =
        ref.read(chatRoomControllerProvider(widget.room).notifier);
    final result = await controller.sendMessage(text);
    if (!mounted) return;

    final error = result.error;
    if (error != null) {
      restoreUnsentDraft(_messageController, text);
      AppToast.showError(context, error.message);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  // The screen above started closing: this room is on top again.
  @override
  void didPopNext() => _socketService.activateClaim(_claim);

  // Closing: hand the socket to the screen below as the pop starts.
  @override
  void didPop() => _socketService.releaseClaim(_claim);

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    // Also covers screens removed without a pop (removeRoute,
    // pushNamedAndRemoveUntil); releasing twice does nothing.
    _socketService.releaseClaim(_claim);
    _errorSubscription?.cancel();
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

  String _displayRoomTitle(String roomName) {
    final parts = roomName
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return roomName;
    return parts.first;
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

  // Shown while the room has no messages on screen: the skeleton while it
  // opens, or what went wrong with Try again.
  Widget _buildChatPlaceholder(ChatRoomState chatState) {
    final joinError = chatState.joinError;
    if (joinError == null) {
      return _buildChatLoadingSkeleton();
    }
    // Scrolls when the keyboard leaves little room above the input.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: ErrorState(
            title: "Couldn't open this chat",
            description: joinError,
            onRetry: ref
                .read(chatRoomControllerProvider(widget.room).notifier)
                .retryJoin,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatRoomControllerProvider(widget.room));
    final messages = withoutBlockedAuthors(
      ref.watch(roomMessagesProvider(widget.room.id)),
      ref.watch(sessionBlockedUserIdsProvider),
    );
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
    final roomDisplayTitle = _displayRoomTitle(widget.room.name);
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
                title: roomDisplayTitle,
                rightAction: AppButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(
                    BleyaTheme.iconContainerSize,
                    BleyaTheme.iconContainerSize,
                  ),
                  onPressed: () {
                    if (widget.room.isPrivate &&
                        widget.room.otherUserId != null) {
                      Navigator.of(context).push(
                        AppRoute.build(
                          builder: (context) => UserDetailsPage(
                            userId: widget.room.otherUserId!,
                            showSayHeyButton: false,
                            directRoomId: widget.room.id,
                          ),
                        ),
                      );
                    } else {
                      Navigator.of(context).push(
                        AppRoute.build(
                          builder: (context) => RoomDetailsPage(
                            roomId: widget.room.id,
                            roomName: widget.room.name,
                            imageUrl: widget.room.imageUrl,
                          ),
                        ),
                      );
                    }
                  },
                  child: Icon(
                    AppIcon.info(context),
                    size: 22,
                    color: BleyaTheme.primary,
                  ),
                ),
              ),
              Expanded(
                child: messages.isEmpty &&
                        (chatState.isInitialLoading ||
                            chatState.joinError != null)
                    ? _buildChatPlaceholder(chatState)
                    : messages.isEmpty
                        ? const _EmptyRoomState()
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
                                      AppRoute.build(
                                        builder: (context) => ThreadViewPage(
                                          parentMessage: message,
                                          room: widget.room,
                                        ),
                                      ),
                                    );
                                  },
                                  onUsernameTap: () {
                                    Navigator.of(context).push(
                                      AppRoute.build(
                                        builder: (context) => UserDetailsPage(
                                          userId: message.userId,
                                          showSayHeyButton:
                                              !widget.room.isPrivate,
                                          directRoomId: widget.room.isPrivate
                                              ? widget.room.id
                                              : null,
                                        ),
                                      ),
                                    );
                                  },
                                  // The page's context: the row's goes
                                  // away if the list empties.
                                  onLongPress: isCurrentUser
                                      ? null
                                      : () => showMessageActions(
                                            context: this.context,
                                            ref: ref,
                                            message: message,
                                          ),
                                ),
                              );
                            },
                          ),
              ),
              if (isDirectMessagingBlocked)
                _BlockedDirectChatNotice(blockedByMe: blockedByMe),
              if (!isDirectMessagingBlocked)
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

class _BlockedDirectChatNotice extends StatelessWidget {
  final bool blockedByMe;

  const _BlockedDirectChatNotice({required this.blockedByMe});

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        BleyaTheme.contentPadding,
        BleyaTheme.spacingSM,
        BleyaTheme.contentPadding,
        bottomSafeArea + BleyaTheme.footerBottomPadding,
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
            ? 'You blocked this user. Unblock to send messages.'
            : 'Messaging is unavailable in this chat.',
        style: BleyaTheme.bodySmall.copyWith(
          color: BleyaTheme.error,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _EmptyRoomState extends StatelessWidget {
  const _EmptyRoomState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: BleyaTheme.spacing3XL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 64,
              color: BleyaTheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: BleyaTheme.spacingXL),
            Text(
              'No messages yet',
              style: BleyaTheme.headingMedium.copyWith(
                fontSize: 24,
                color: BleyaTheme.foreground.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: BleyaTheme.spacingSM),
            Text(
              'Be the first to say hello and start the conversation!',
              style: BleyaTheme.bodyMedium.copyWith(
                fontSize: 16,
                height: 1.4,
                color: BleyaTheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
