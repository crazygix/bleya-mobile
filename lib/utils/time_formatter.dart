String formatRelativeTime(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inSeconds < 60) {
    return 'now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h';
  } else if (difference.inDays == 1) {
    return 'Yesterday';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d';
  } else {
    final weeks = (difference.inDays / 7).floor();
    if (weeks < 4) {
      return '${weeks}w';
    } else {
      final months = (difference.inDays / 30).floor();
      return '${months}mo';
    }
  }
}
