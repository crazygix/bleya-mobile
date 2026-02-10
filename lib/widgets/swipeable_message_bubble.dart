import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/theme.dart';
import '../domain/entities/message.dart';
import 'message_bubble.dart';

class SwipeableMessageBubble extends StatefulWidget {
  final Message message;
  final bool isCurrentUser;
  final VoidCallback? onTap;
  final VoidCallback? onUsernameTap;
  final bool showReplyBadge;

  const SwipeableMessageBubble({
    super.key,
    required this.message,
    required this.isCurrentUser,
    this.onTap,
    this.onUsernameTap,
    this.showReplyBadge = true,
  });

  @override
  State<SwipeableMessageBubble> createState() => _SwipeableMessageBubbleState();
}

class _SwipeableMessageBubbleState extends State<SwipeableMessageBubble>
    with SingleTickerProviderStateMixin {
  static const double _maxDragDistance = 72.0;

  late final AnimationController _controller;
  Animation<double>? _animation;
  double _dragOffsetX = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.delta.dx;
    double nextOffset = _dragOffsetX + delta;

    if (widget.isCurrentUser) {
      // Swipe left to reveal time
      nextOffset = nextOffset.clamp(-_maxDragDistance, 0);
    } else {
      // Swipe right to reveal time
      nextOffset = nextOffset.clamp(0, _maxDragDistance);
    }

    if (nextOffset != _dragOffsetX) {
      setState(() {
        _dragOffsetX = nextOffset;
      });
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _animation?.removeListener(_animationListener);
    _animation = Tween<double>(
      begin: _dragOffsetX,
      end: 0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    )..addListener(_animationListener);

    _controller
      ..reset()
      ..forward();
  }

  void _animationListener() {
    setState(() {
      _dragOffsetX = _animation!.value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final use24Hour = MediaQuery.of(context).alwaysUse24HourFormat;

    final dateFormat =
        use24Hour ? DateFormat.Hm(locale) : DateFormat.jm(locale);
    final timeLabel = dateFormat.format(widget.message.createdAt);
    final revealProgress =
        (_dragOffsetX.abs() / _maxDragDistance).clamp(0.0, 1.0);

    return Stack(
      alignment:
          widget.isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            bottom: BleyaTheme.spacingSM,
          ),
          child: Align(
            alignment: widget.isCurrentUser
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: widget.isCurrentUser ? 0 : BleyaTheme.spacingLG,
                right: widget.isCurrentUser ? BleyaTheme.spacingLG : 0,
              ),
              child: Opacity(
                opacity: revealProgress,
                child: Text(
                  timeLabel,
                  style: BleyaTheme.bodySmall.copyWith(
                    fontSize: 12,
                    color: BleyaTheme.mutedForeground.withValues(
                      alpha: BleyaTheme.glassBorderOpacity + 0.7,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        GestureDetector(
          onHorizontalDragUpdate: _handleDragUpdate,
          onHorizontalDragEnd: _handleDragEnd,
          child: Transform.translate(
            offset: Offset(_dragOffsetX, 0),
            child: MessageBubble(
              messageText: widget.message.text,
              isCurrentUser: widget.isCurrentUser,
              username: widget.message.username,
              replyCount: widget.showReplyBadge ? widget.message.replyCount : 0,
              onTap: widget.onTap,
              onUsernameTap: widget.onUsernameTap,
            ),
          ),
        ),
      ],
    );
  }
}
