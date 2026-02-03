import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ShopifyEmailLoginFlow {
  ShopifyEmailLoginFlow({
    FirebaseFunctions? functions,
    this.scheme = 'reviewseverywhere',
    this.host = 'shopify-email-login',
    this.exchangeCallableName = 'exchangeShopifyEmailLoginCode',
  }) : _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  final AppLinks _appLinks = AppLinks();
  final FirebaseFunctions _functions;

  final String scheme;
  final String host;
  final String exchangeCallableName;

  StreamSubscription<Uri>? _sub;
  Completer<_ShopifyCodePayload?>? _codeCompleter;

  /// Waits until the app receives:
  /// reviewseverywhere://shopify-email-login?code=...&shop=...
  Future<_ShopifyCodePayload?> waitForCode({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    _codeCompleter = Completer<_ShopifyCodePayload?>();

    // Cold start deep link
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      _tryCompleteFromUri(initial);
    }

    // Warm deep links
    _sub ??= _appLinks.uriLinkStream.listen(_tryCompleteFromUri);

    return _codeCompleter!.future.timeout(timeout, onTimeout: () => null);
  }

  /// Convenience: waits for the code deep link, then exchanges it for Firebase customToken.
  Future<String?> waitForFirebaseCustomToken({
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final payload = await waitForCode(timeout: timeout);
    if (payload == null) return null;

    final callable = _functions.httpsCallable(exchangeCallableName);

    final res = await callable.call(<String, dynamic>{
      'code': payload.code,
      if (payload.shop != null && payload.shop!.trim().isNotEmpty) 'shop': payload.shop,
    });

    final data = res.data;
    final map = (data is Map) ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    final customToken = (map['customToken'] ?? '').toString().trim();
    if (customToken.isEmpty) return null;

    return customToken;
  }

  void _tryCompleteFromUri(Uri uri) {
    if (_codeCompleter == null || _codeCompleter!.isCompleted) return;

    if (uri.scheme != scheme) return;
    if (uri.host != host) return;

    final code = (uri.queryParameters['code'] ?? '').trim();
    if (code.isEmpty) return;

    final shop = (uri.queryParameters['shop'] ?? '').trim();
    _codeCompleter!.complete(_ShopifyCodePayload(code: code, shop: shop.isEmpty ? null : shop));
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _codeCompleter = null;
  }
}

class _ShopifyCodePayload {
  const _ShopifyCodePayload({required this.code, this.shop});
  final String code;
  final String? shop;
}
