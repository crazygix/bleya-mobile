import 'package:flutter/material.dart';
import '../constants/theme.dart';

class RoomHeroCard extends StatelessWidget {
  final String roomTitle;
  final String roomSubtitle;
  final String? imageUrl;

  const RoomHeroCard({
    super.key,
    required this.roomTitle,
    required this.roomSubtitle,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
        border: Border.all(
          color: BleyaTheme.border.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          ...BleyaTheme.glassShadow,
          BoxShadow(
            color: BleyaTheme.primary.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BleyaTheme.radiusLarge),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _RoomCoverImage(imageUrl: imageUrl),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    BleyaTheme.foreground.withValues(alpha: 0.12),
                    BleyaTheme.foreground.withValues(alpha: 0.78),
                  ],
                ),
              ),
            ),
            Positioned(
              left: BleyaTheme.spacingLG,
              right: BleyaTheme.spacingLG,
              bottom: BleyaTheme.spacingLG,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    roomTitle,
                    style: BleyaTheme.headingMedium.copyWith(
                      fontSize: 32,
                      color: Colors.white,
                      height: 1.0,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (roomSubtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: BleyaTheme.spacingXS),
                    Text(
                      roomSubtitle,
                      style: BleyaTheme.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCoverImage extends StatelessWidget {
  final String? imageUrl;

  const _RoomCoverImage({required this.imageUrl});

  bool _isValidUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  Widget _buildFallback() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            BleyaTheme.primary.withValues(alpha: 0.92),
            BleyaTheme.secondary.withValues(alpha: 0.75),
            BleyaTheme.accent.withValues(alpha: 0.7),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isValidUrl(imageUrl)) {
      return _buildFallback();
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _buildFallback();
      },
      errorBuilder: (_, __, ___) => _buildFallback(),
    );
  }
}
