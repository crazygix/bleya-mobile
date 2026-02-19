import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'error_state.dart';

/// Shared centered error state for list screens that recover via pull-to-refresh.
class PullToRefreshErrorState extends StatelessWidget {
  final String title;
  final String description;
  final Future<void> Function() onRefresh;

  const PullToRefreshErrorState({
    super.key,
    required this.title,
    required this.description,
    required this.onRefresh,
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
                retryText: null,
                icon: CupertinoIcons.exclamationmark_triangle,
              ),
            ),
          ),
        );
      },
    );
  }
}
