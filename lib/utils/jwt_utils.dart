import 'dart:convert';

/// Utility class for JWT token operations
class JwtUtils {
  /// Decodes a JWT token without verification (for checking expiry only)
  /// Returns null if token is invalid
  static Map<String, dynamic>? decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Decode the payload (second part)
      final payload = parts[1];
      // Convert base64url to base64 and add padding if needed
      final normalizedPayload = _normalizeBase64(payload);
      final decodedBytes = base64Decode(normalizedPayload);
      final decodedString = utf8.decode(decodedBytes);
      return jsonDecode(decodedString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Normalizes base64url string by converting to base64 and adding padding if needed
  static String _normalizeBase64(String base64url) {
    // Convert base64url to base64: replace '-' with '+' and '_' with '/'
    final base64 = base64url.replaceAll('-', '+').replaceAll('_', '/');
    // Add padding if needed
    final padding = 4 - (base64.length % 4);
    if (padding != 4) {
      return base64 + ('=' * padding);
    }
    return base64;
  }

  /// Checks if a JWT token is expired or will expire soon
  /// Returns true if token is expired or will expire within [bufferMinutes]
  static bool isTokenExpiredOrExpiringSoon(String token,
      {int bufferMinutes = 5}) {
    final decoded = decodeToken(token);
    if (decoded == null) return true;

    final exp = decoded['exp'];
    if (exp == null) return true;

    // exp is in seconds since epoch
    final expiryTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final now = DateTime.now();
    final bufferTime = Duration(minutes: bufferMinutes);

    return now.add(bufferTime).isAfter(expiryTime);
  }

  /// Gets the expiry time of a JWT token
  static DateTime? getTokenExpiry(String token) {
    final decoded = decodeToken(token);
    if (decoded == null) return null;

    final exp = decoded['exp'];
    if (exp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }
}
