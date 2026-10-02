import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Loads the photo at [url] for an avatar [size] points across, decoded at
/// no more than twice the pixels it shows on screen instead of at full size.
///
/// Twice keeps the circle sharp for photos up to 2:1, which the avatar crops
/// to cover. Smaller photos are never scaled up.
ImageProvider avatarImageProvider(
  String url, {
  required double size,
  required double devicePixelRatio,
}) {
  final pixels = (size * devicePixelRatio * 2).ceil();
  return ResizeImage(
    NetworkImage(url),
    width: pixels,
    height: pixels,
    policy: ResizeImagePolicy.fit,
  );
}

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
    this.fallbackIcon = CupertinoIcons.person,
    this.fallbackIconColor,
  });

  @override
  State<ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<ProfileAvatar> {
  bool _imageLoadFailed = false;

  bool _isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
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
        backgroundColor: widget.backgroundColor ?? BleyaTheme.primaryLight,
        backgroundImage: hasValidUrl && !_imageLoadFailed
            ? avatarImageProvider(
                widget.imageUrl!,
                size: widget.size,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
              )
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
                color: widget.fallbackIconColor ?? BleyaTheme.primaryDark,
                size: widget.size * 0.5,
              )
            : null,
      ),
    );
  }
}
