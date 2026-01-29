import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Profile Avatar Component
///
/// A reusable avatar component with profile image, error handling, and fallback icon.
///
/// Features:
/// - Displays profile image from URL
/// - Error handling with fallback icon
/// - Customizable size
/// - Optional border and background color
/// - Uses design system colors
class ProfileAvatar extends StatefulWidget {
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final IconData fallbackIcon;
  final Color? fallbackIconColor;

  const ProfileAvatar({
    super.key,
    this.imageUrl,
    this.size = 40.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.0,
    this.fallbackIcon = CupertinoIcons.person_fill,
    this.fallbackIconColor,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageLoadFailed = false;

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('https://');
  }

  @override
  void didUpdateWidget(ProfileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      setState(() {
        _imageLoadFailed = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValidUrl = _isValidImageUrl(widget.imageUrl);
    final shouldShowFallback = !hasValidUrl || _imageLoadFailed;

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: widget.borderWidth > 0 && widget.borderColor != null
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: widget.borderColor!,
                width: widget.borderWidth,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: widget.size / 2,
        backgroundColor: widget.backgroundColor ?? BleyaTheme.greyLight,
        backgroundImage: hasValidUrl && !_imageLoadFailed
            ? NetworkImage(widget.imageUrl!)
            : null,
        onBackgroundImageError: hasValidUrl && !_imageLoadFailed
            ? (exception, stackTrace) {
                setState(() {
                  _imageLoadFailed = true;
                });
              }
            : null,
        child: shouldShowFallback
            ? Icon(
                widget.fallbackIcon,
                color: widget.fallbackIconColor ?? BleyaTheme.mutedForeground,
                size: widget.size * 0.5,
              )
            : null,
      ),
    );
  }
}
