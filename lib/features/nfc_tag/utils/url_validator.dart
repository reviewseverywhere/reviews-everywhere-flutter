// lib/features/nfc_tag/utils/url_validator.dart

class UrlValidator {
  /// Returns true if [rawUrl]:
  ///   • starts with “http://” or “https://”
  ///   • is no more than 2000 chars
  ///   • does not contain HTML tags
  ///   • does not use “javascript:” or other unsupported schemes
  static bool isValidFormat(String rawUrl) {
    // 1) Length check
    if (rawUrl.length > 2000) return false;

    final lower = rawUrl.toLowerCase();

    // 2) Must begin with http:// or https://
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }

    // 3) No javascript pseudo-URLs
    if (lower.startsWith('javascript:')) {
      return false;
    }

    // 4) No HTML tags
    if (RegExp(r'<[^>]+>').hasMatch(rawUrl)) {
      return false;
    }

    return true;
  }
}
