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
import '../widgets/pressable.dart';
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

  /// Whether [message] is the user's own, still on its way to the server.
  final bool isPending;

  const _ChatListItem.date(this.date)
      : type = _ChatItemType.dateSeparator,
        message = null,
        isPending = false;

  const _ChatListItem.message(this.message, {this.isPending = false})
      : type = _ChatItemType.message,
        date = null;
}

/// The chat's rows, newest first, and where each message's row is.
class _ChatItems {
  _ChatItems(this.items, this.indexByMessageId);

  final List<_ChatListItem> items;
  final Map<String, int> indexByMessageId;
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
  // Starts at the newest message: below the list's anchor there is only the
  // bottom padding (see _buildMessageList).
  final ScrollController _scrollController =
      ScrollController(initialScrollOffset: -BleyaTheme.spacingLG);
  ProviderSubscription<List<Message>>? _messagesSubscription;
  ProviderSubscription<ChatRoomState>? _chatStateSubscription;
  late final SocketService _socketService;
  // This screen's hold on the room: the socket stays in it while this is
  // the newest chat screen.
  late final RoomClaim _claim;
  StreamSubscription<String>? _errorSubscription;
  bool _isLoadingMoreTriggered = false;

  // While the user reads older messages, the ones that arrive go below this
  // message, into a part of the list that grows downwards, so what's on
  // screen doesn't move. Null while the newest message is in view.
  String? _splitMessageId;
  DateTime? _splitTime;
  final Key _olderMessagesKey = UniqueKey();
  // New messages arrived below while the user reads older ones.
  bool _showNewMessagesButton = false;

  // How close to the newest message still counts as reading it, so new ones
  // are followed.
  static const double _followSlack = 48;

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
        _onMessagesChanged,
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

  /// New messages: followed while the newest message is in view; otherwise
  /// they go below the one the list ends at now, and a button offers them.
  void _onMessagesChanged(List<Message>? previous, List<Message> next) {
    if (!mounted || previous == null || previous.isEmpty || next.isEmpty) {
      return;
    }
    final newest = next.last;
    if (previous.any((message) => message.id == newest.id)) return;

    if (_isAtBottom(slack: _followSlack)) {
      if (!_isScrolling) _scrollToBottom();
      return;
    }
    setState(() {
      if (_splitMessageId == null) {
        _splitMessageId = previous.last.id;
        _splitTime = previous.last.createdAt;
      }
      _showNewMessagesButton = true;
    });
  }

  /// Whether the newest message is in view, within [slack].
  bool _isAtBottom({double slack = 1}) {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels <= position.minScrollExtent + slack;
  }

  bool get _isScrolling =>
      _scrollController.hasClients &&
      _scrollController.position.isScrollingNotifier.value;

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification && notification.depth == 0) {
      // After the notification: the scroll position is still ending it.
      Future.microtask(_settleAtBottom);
    }
    return false;
  }

  /// Back at the newest message: the two parts of the list become one again.
  /// The view stays the same, since it shows the end of the list either way.
  void _settleAtBottom() {
    if (!mounted || _isScrolling || !_isAtBottom()) return;
    if (_splitMessageId == null) {
      if (_showNewMessagesButton) {
        setState(() => _showNewMessagesButton = false);
      }
      return;
    }
    _scrollController.jumpTo(-BleyaTheme.spacingLG);
    setState(() {
      _splitMessageId = null;
      _splitTime = null;
      _showNewMessagesButton = false;
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_showNewMessagesButton && _isAtBottom()) {
      setState(() => _showNewMessagesButton = false);
    }

    final position = _scrollController.position;
    // The list is reversed: the newest message is at minScrollExtent and the
    // oldest at maxScrollExtent. Load more when scrolling up near the top.
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

  /// Shows the newest message.
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (animated) {
        await position.animateTo(
          position.minScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        position.jumpTo(position.minScrollExtent);
      }
      // Rows below may only have been measured on the way; unless the user
      // took over, finish at the end.
      if (mounted &&
          _scrollController.hasClients &&
          !_isScrolling &&
          !_isAtBottom()) {
        _scrollController.jumpTo(_scrollController.position.minScrollExtent);
      }
      _settleAtBottom();
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

  /// The rows for [messages] (oldest first), the last [pendingCount] of
  /// them still on their way.
  _ChatItems _buildChatItems(List<Message> messages, {int pendingCount = 0}) {
    final items = <_ChatListItem>[];
    final indexByMessageId = <String, int>{};

    // Source messages are Oldest -> Newest.
    // We want the ListView(reverse: true) to have Index 0 = Bottom = Newest.
    // So we iterate backwards.
    for (int i = messages.length - 1; i >= 0; i--) {
      final message = messages[i];
      indexByMessageId[message.id] = items.length;
      items.add(_ChatListItem.message(
        message,
        isPending: i >= messages.length - pendingCount,
      ));

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

    return _ChatItems(items, indexByMessageId);
  }

  /// The messages, newest at the bottom, in two parts around an anchor.
  ///
  /// The older part starts at the anchor and grows upwards. Messages that
  /// arrive while the user reads older ones go into the newer part, which
  /// starts at the anchor and grows downwards, so the rows on screen don't
  /// move. Without a split everything is in the older part, and new messages
  /// push the list up from the bottom as usual.
  Widget _buildMessageList(
    List<Message> messages,
    _ChatItems chatItems,
    String? currentUserId,
  ) {
    final items = chatItems.items;
    // Rows [0, splitRow) are newer than the split, newest first.
    final splitRow = _splitRow(messages, chatItems);

    final list = CustomScrollView(
      reverse: true,
      controller: _scrollController,
      center: _olderMessagesKey,
      slivers: [
        SliverPadding(
          // Below the newest message.
          padding: const EdgeInsets.only(
            left: BleyaTheme.contentPadding,
            right: BleyaTheme.contentPadding,
            bottom: BleyaTheme.spacingLG,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              // Row 0 sits right below the anchor.
              (context, index) => _buildRow(
                  context, items[splitRow - 1 - index], currentUserId),
              childCount: splitRow,
              // Rows keep their state as the list changes.
              findChildIndexCallback: (key) {
                final row = key is ValueKey<String>
                    ? chatItems.indexByMessageId[key.value]
                    : null;
                return row != null && row < splitRow
                    ? splitRow - 1 - row
                    : null;
              },
            ),
          ),
        ),
        SliverPadding(
          key: _olderMessagesKey,
          // Above the oldest message.
          padding: const EdgeInsets.only(
            left: BleyaTheme.contentPadding,
            right: BleyaTheme.contentPadding,
            top: BleyaTheme.spacingLG,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  _buildRow(context, items[splitRow + index], currentUserId),
              childCount: items.length - splitRow,
              findChildIndexCallback: (key) {
                final row = key is ValueKey<String>
                    ? chatItems.indexByMessageId[key.value]
                    : null;
                return row != null && row >= splitRow ? row - splitRow : null;
              },
            ),
          ),
        ),
      ],
    );

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: list,
        ),
        if (_showNewMessagesButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: BleyaTheme.spacingSM,
            child: Center(
              child: _NewMessagesButton(onPressed: _scrollToBottom),
            ),
          ),
      ],
    );
  }

  /// The row of the split message in [chatItems], or 0 without a split. If
  /// that message is gone (removed, or its author blocked), the newest one
  /// sent before it takes its place.
  int _splitRow(List<Message> messages, _ChatItems chatItems) {
    final splitId = _splitMessageId;
    if (splitId == null) return 0;
    final row = chatItems.indexByMessageId[splitId];
    if (row != null) return row;
    final splitTime = _splitTime;
    if (splitTime == null) return 0;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (!messages[i].createdAt.isAfter(splitTime)) {
        return chatItems.indexByMessageId[messages[i].id] ?? 0;
      }
    }
    return 0;
  }

  Widget _buildRow(
    BuildContext context,
    _ChatListItem item,
    String? currentUserId,
  ) {
    if (item.type == _ChatItemType.dateSeparator) {
      final locale = Localizations.localeOf(context).toLanguageTag();
      final label = formatMessageDateLabel(
        item.date!,
        locale: locale,
      );
      return _DateSeparatorLabel(
        label: label,
      );
    }

    final message = item.message!;
    if (item.isPending) {
      return KeyedSubtree(
        key: ValueKey<String>(message.id),
        child: PendingMessageBubble(
          message: message,
        ),
      );
    }
    final isCurrentUser =
        currentUserId != null && message.userId == currentUserId;

    return KeyedSubtree(
      key: ValueKey<String>(message.id),
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
                showSayHeyButton: !widget.room.isPrivate,
                directRoomId: widget.room.isPrivate ? widget.room.id : null,
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
    final storedMessages = withoutBlockedAuthors(
      ref.watch(roomMessagesProvider(widget.room.id)),
      ref.watch(sessionBlockedUserIdsProvider),
    );
    // The user's own messages on their way show at once, after the rest.
    final pendingMessages = chatState.pendingMessages;
    final messages = pendingMessages.isEmpty
        ? storedMessages
        : [...storedMessages, ...pendingMessages];
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
    final chatItems = _buildChatItems(
      messages,
      pendingCount: pendingMessages.length,
    );
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
                        : _buildMessageList(
                            messages,
                            chatItems,
                            currentUserId,
                          ),
              ),
              if (isDirectMessagingBlocked)
                _BlockedDirectChatNotice(blockedByMe: blockedByMe),
              if (!isDirectMessagingBlocked)
                _AboveKeyboard(
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

/// Shown while the user reads older messages and new ones arrived below:
/// takes them to the newest.
class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      pressedScale: 0.95,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: BleyaTheme.spacingMD,
          vertical: BleyaTheme.spacingSM,
        ),
        decoration: BoxDecoration(
          color: BleyaTheme.primary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: BleyaTheme.glassShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New messages',
              style: BleyaTheme.bodySmall.copyWith(
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: BleyaTheme.spacingXS),
            const Icon(
              CupertinoIcons.arrow_down,
              size: 14,
              color: CupertinoColors.white,
            ),
          ],
        ),
      ),
    );
  }
}

/// Keeps [child] right above the keyboard as it moves. The system animates
/// the keyboard's height frame by frame, so following it directly keeps the
/// input in step with the keyboard; only this part of the screen rebuilds.
class _AboveKeyboard extends StatelessWidget {
  const _AboveKeyboard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
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
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

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
