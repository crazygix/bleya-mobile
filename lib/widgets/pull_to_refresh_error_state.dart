import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'error_state.dart';

/// Shared centered error state for list screens that recover via retry or pull-to-refresh.
class PullToRefreshErrorState extends StatelessWidget {
  final String title;
  final String description;
  final Future<void> Function() onRefresh;
  final String retryText;

  const PullToRefreshErrorState({
    super.key,
    required this.title,
    required this.description,
    required this.onRefresh,
    this.retryText = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: ErrorState(
                title: title,
                description: description,
                retryText: retryText,
                onRetry: () {
                  onRefresh();
                },
                icon: CupertinoIcons.exclamationmark_triangle,
              ),
            ),
          ),
        );
      },
    );
  }
}
