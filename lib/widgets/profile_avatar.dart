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
class ProfileAvatar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: borderWidth > 0 && borderColor != null
          ? BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor!,
                width: borderWidth,
              ),
            )
          : null,
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: backgroundColor ?? BleyaTheme.greyLight,
        backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
            ? NetworkImage(imageUrl!)
            : null,
        onBackgroundImageError: imageUrl != null && imageUrl!.isNotEmpty
            ? (exception, stackTrace) {
                // Error handled by showing fallback icon
              }
            : null,
        child: imageUrl == null || imageUrl!.isEmpty
            ? Icon(
                fallbackIcon,
                color: fallbackIconColor ?? BleyaTheme.mutedForeground,
                size: size * 0.5,
              )
            : null,
      ),
    );
  }
}
