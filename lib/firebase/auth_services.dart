// lib/firebase/auth_services.dart

import 'package:cards/features/nfc_tag/presentation/pages/auth/auth_page.dart';
import 'package:cards/features/nfc_tag/presentation/pages/home_page.dart';
import 'package:cards/features/nfc_tag/presentation/widgets/alert_bar.dart';
import 'package:cards/firebase/firestore_services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart'; // LEGACY ONLY (must NOT be used for client email/password flow)
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  static const String _log = '[AuthService]';
  static const String _shopifyLog = '[ShopifyEmailLogin]';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cloud Functions region
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(region: 'us-central1');

  // Website (purchase CTA)
  static const String _reviewsEverywhereWebsite = 'https://www.reviewseverywhere.com/';
  static const String _reviewsEverywhereWebsiteDisplay = 'www.reviewseverywhere.com';

  // Shopify account URL (for “My Account”)
  // Client forbids Shopify-hosted auth pages. Do NOT open /account from the app.
  static const String _shopifyMyAccountUrl = 'https://www.reviewseverywhere.com/account';

  // Callable function names (must match functions/index.js exports)
  static const String _fnLookupAccountByEmail = 'lookupAccountByEmail';
  static const String _fnLinkAuthToAccount = 'linkAuthToAccount';

  // ✅ Client-required email/password flow (Shopify Storefront via backend)
  static const String _fnShopifyCustomerRecover = 'shopifyCustomerRecover';
  static const String _fnShopifyCustomerResetPassword = 'shopifyCustomerResetPassword';
  static const String _fnShopifyCustomerLogin = 'shopifyCustomerLogin';

  /* ------------------------------------------------------------------------ */
  /* LEGACY (DO NOT USE FOR CLIENT EMAIL/PASSWORD)                             */
  /* ------------------------------------------------------------------------ */

  // Exchange code -> customToken (Shopify email login fallback) - LEGACY
  static const String _fnExchangeShopifyEmailLoginCode = 'exchangeShopifyEmailLoginCode';

  // Shopify Email login START endpoint (HTTP Cloud Function) - LEGACY
  static const String _shopifyEmailLoginStartEndpoint =
      'https://us-central1-reviewseverywhere-b3eb5.cloudfunctions.net/shopifyEmailLoginStart';

  // Deep link shape (backend redirects here at the end) - LEGACY
  static const String _shopifyEmailDeepLinkScheme = 'reviewseverywhere';
  static const String _shopifyEmailDeepLinkHost = 'shopify-email-login';

  // ✅ Client-required Set Password deep link (must open MainActivity, not Shopify pages)
  // reviewseverywhere://set-password?token=...&email=...
  static const String _setPasswordDeepLinkScheme = 'reviewseverywhere';
  static const String _setPasswordDeepLinkHost = 'set-password';

  // Optional: iOS clientId initialization for Google Sign-In
  static const String _googleClientId =
      "996925096071-aqeps8s6uh93pedl3bklkq955ljlj671.apps.googleusercontent.com";

  String _normalizeEmail(String? v) => (v ?? '').trim().toLowerCase();
  bool _looksLikeEmail(String v) => v.contains('@') && v.contains('.');
  void _p(String msg) => debugPrint('$_log $msg');
  void _sp(String msg) => debugPrint('$_shopifyLog $msg');

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  /* ------------------------------------------------------------------------ */
  /* Navigation helpers                                                        */
  /* ------------------------------------------------------------------------ */

  void _goHome(BuildContext context) {
    _sp('_goHome called. mounted=${context.mounted}');
    if (!context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sp('_goHome postFrame. mounted=${context.mounted}');
      if (!context.mounted) return;

      try {
        _sp('_goHome pushNamedAndRemoveUntil -> ${HomePage.routeName}');
        Navigator.of(context).pushNamedAndRemoveUntil(
          HomePage.routeName,
              (route) => false,
        );
      } catch (e, st) {
        _sp('_goHome NAV ERROR: $e');
        _sp('STACK: $st');
      }
    });
  }

  void _goAuth(BuildContext context) {
    _sp('_goAuth called. mounted=${context.mounted}');
    if (!context.mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sp('_goAuth postFrame. mounted=${context.mounted}');
      if (!context.mounted) return;

      try {
        _sp('_goAuth pushNamedAndRemoveUntil -> ${AuthPage.routeName}');
        Navigator.of(context).pushNamedAndRemoveUntil(
          AuthPage.routeName,
              (route) => false,
        );
      } catch (e, st) {
        _sp('_goAuth NAV ERROR: $e');
        _sp('STACK: $st');
      }
    });
  }

  /* ------------------------------------------------------------------------ */
  /* Public helpers                                                            */
  /* ------------------------------------------------------------------------ */

  Future<void> openWebsite(BuildContext context) async {
    final uri = Uri.parse(_reviewsEverywhereWebsite);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      if (!ok && context.mounted) {
        ShowAlertBar().alertDialog(
          context,
          "Unable to open the website. Please open it manually: $_reviewsEverywhereWebsiteDisplay",
          Colors.red,
        );
      }
    } catch (e) {
      _p('openWebsite error: $e');
      if (context.mounted) {
        ShowAlertBar().alertDialog(
          context,
          "Unable to open the website. Please open it manually: $_reviewsEverywhereWebsiteDisplay",
          Colors.red,
        );
      }
    }
  }

  /// Client constraint: NEVER send users to Shopify-hosted auth pages.
  /// Opening /account can redirect to /account/login which is forbidden.
  /// Therefore this always opens the main website.
  Future<void> openPurchaseOrMyAccount(
      BuildContext context, {
        String? typedEmail,
      }) async {
    await openWebsite(context);
  }

  /// For the client-required identity flow, do not block the user from
  /// initiating password set/reset. We only require that a purchase/account exists.
  Future<bool> verifyPurchaseEmail(
      BuildContext context, {
        required String typedEmail,
      }) async {
    final emailLower = _normalizeEmail(typedEmail);
    if (emailLower.isEmpty || !_looksLikeEmail(emailLower)) {
      await _showEnterEmail(context);
      return false;
    }
    return _ensureAccountExists(context, emailLower);
  }

  /* ------------------------------------------------------------------------ */
  /* Deep link helpers                                                         */
  /* ------------------------------------------------------------------------ */

  /// ✅ Client-required: reviewseverywhere://set-password?token=...&email=...
  /// IMPORTANT: Your backend currently expects `token` to be a FULL reset URL/path
  /// (usually URL-encoded) so it can call `customerResetByUrl` or extract id/token.
  bool isSetPasswordDeepLink(Uri uri) {
    final token = (uri.queryParameters['token'] ?? '').trim();
    final ok = uri.scheme == _setPasswordDeepLinkScheme &&
        uri.host == _setPasswordDeepLinkHost &&
        token.isNotEmpty;

    _sp('isSetPasswordDeepLink? $ok uri=$uri');
    return ok;
  }

  /// Call this from your app-level deep link listener.
  /// It only returns parsed values; UI should route to SetPassword screen.
  Map<String, String?> parseSetPasswordDeepLink(Uri uri) {
    if (!isSetPasswordDeepLink(uri)) return <String, String?>{};
    return <String, String?>{
      'token': (uri.queryParameters['token'] ?? '').trim(),
      'email': (uri.queryParameters['email'] ?? '').trim(),
    };
  }

  /* ------------------------------------------------------------------------ */
  /* Social sign-in (provider email only)                                      */
  /* ------------------------------------------------------------------------ */

  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    _p('signInWithGoogle start');

    try {
      final dynamic gs = GoogleSignIn.instance;
      try {
        await gs.initialize(clientId: _googleClientId);
      } catch (_) {}

      GoogleSignInAccount? googleUser;
      try {
        final dynamic res = await gs.authenticate();
        googleUser = res as GoogleSignInAccount?;
      } catch (_) {
        try {
          final dynamic res = await gs.signIn();
          googleUser = res as GoogleSignInAccount?;
        } catch (_) {}
      }

      if (googleUser == null) {
        _p('signInWithGoogle cancelled/no user');
        return null;
      }

      final providerEmail = _normalizeEmail(googleUser.email);
      _p('signInWithGoogle provider email="$providerEmail"');

      if (providerEmail.isEmpty || !_looksLikeEmail(providerEmail)) {
        await _safeGoogleLogout();
        await _showSimpleDialog(
          context,
          title: "Google sign-in failed",
          message: "Google did not return a valid email for this account.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      // Social remains entitlement-gated (active plan).
      final ok = await _ensureAccountIsActive(context, providerEmail);
      _p('signInWithGoogle entitlement ok=$ok for providerEmail="$providerEmail"');
      if (!ok) {
        await _safeGoogleLogout();
        return null;
      }

      final GoogleSignInAuthentication auth = await googleUser.authentication;
      final idToken = auth.idToken;

      if (idToken == null || idToken.isEmpty) {
        await _safeGoogleLogout();
        await _showSimpleDialog(
          context,
          title: "Google sign-in failed",
          message: "Missing Google idToken.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final linked = await _linkAuthToAccountSocial(
        provider: 'google',
        tokenKey: 'idToken',
        token: idToken,
      );

      final customToken = (linked?['customToken'] ?? '').toString().trim();
      _p('signInWithGoogle linkAuthToAccount returned customTokenLen=${customToken.length}');

      if (customToken.isEmpty) {
        await _safeGoogleLogout();
        await _showSimpleDialog(
          context,
          title: "Login failed",
          message: "Missing custom token from server.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final userCredential = await _auth.signInWithCustomToken(customToken);
      _p('signInWithGoogle Firebase signInWithCustomToken uid=${userCredential.user?.uid}');

      await UserDatabaseService().createOrUpdateUser();
      _p('signInWithGoogle createOrUpdateUser done');

      _goHome(context);
      return userCredential;
    } on FirebaseFunctionsException catch (eFn) {
      _p('signInWithGoogle FirebaseFunctionsException code=${eFn.code} message=${eFn.message}');
      if (eFn.code == 'not-found') {
        await _showPurchaseRequired(context);
        await _safeGoogleLogout();
        return null;
      }
      if (eFn.code == 'failed-precondition') {
        final msg = (eFn.message ?? '').toLowerCase();
        if (msg.contains('not active') || msg.contains('planstatus')) {
          await _showPlanNotActive(context);
          await _safeGoogleLogout();
          return null;
        }
      }
      await _showFunctionError(context, "Google login failed", eFn);
      await _safeGoogleLogout();
      return null;
    } catch (e) {
      _p('signInWithGoogle error: $e');
      await _showSimpleDialog(
        context,
        title: "Google sign-in failed",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      await _safeGoogleLogout();
      return null;
    }
  }

  Future<UserCredential?> signInWithFacebook(BuildContext context) async {
    _p('signInWithFacebook start');

    try {
      final LoginResult loginResult =
      await FacebookAuth.i.login(permissions: ['email', 'public_profile']);

      if (loginResult.status == LoginStatus.cancelled) {
        _p('signInWithFacebook cancelled');
        return null;
      }

      if (loginResult.status != LoginStatus.success) {
        await _showSimpleDialog(
          context,
          title: "Facebook sign-in failed",
          message: loginResult.message ?? "Unable to sign in with Facebook.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final data = await FacebookAuth.i.getUserData(fields: "email,name");
      final providerEmail = _normalizeEmail((data['email'] ?? '').toString());
      _p('signInWithFacebook provider email="$providerEmail"');

      if (providerEmail.isEmpty || !_looksLikeEmail(providerEmail)) {
        await FacebookAuth.i.logOut();
        await _showSimpleDialog(
          context,
          title: "Facebook sign-in failed",
          message:
          "Facebook did not provide an email for this account. Please use a Facebook account that has an email, or use Google sign-in.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      // Social remains entitlement-gated (active plan).
      final ok = await _ensureAccountIsActive(context, providerEmail);
      _p('signInWithFacebook entitlement ok=$ok for providerEmail="$providerEmail"');
      if (!ok) {
        await FacebookAuth.i.logOut();
        return null;
      }

      final accessToken = loginResult.accessToken?.tokenString ?? '';
      if (accessToken.isEmpty) {
        await FacebookAuth.i.logOut();
        await _showSimpleDialog(
          context,
          title: "Facebook sign-in failed",
          message: "Missing Facebook access token.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final linked = await _linkAuthToAccountSocial(
        provider: 'facebook',
        tokenKey: 'accessToken',
        token: accessToken,
      );

      final customToken = (linked?['customToken'] ?? '').toString().trim();
      _p('signInWithFacebook linkAuthToAccount returned customTokenLen=${customToken.length}');

      if (customToken.isEmpty) {
        await FacebookAuth.i.logOut();
        await _showSimpleDialog(
          context,
          title: "Login failed",
          message: "Missing custom token from server.",
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final userCredential = await _auth.signInWithCustomToken(customToken);
      _p('signInWithFacebook Firebase signInWithCustomToken uid=${userCredential.user?.uid}');

      await UserDatabaseService().createOrUpdateUser();
      _p('signInWithFacebook createOrUpdateUser done');

      _goHome(context);
      return userCredential;
    } on FirebaseFunctionsException catch (eFn) {
      _p('signInWithFacebook FirebaseFunctionsException code=${eFn.code} message=${eFn.message}');
      if (eFn.code == 'not-found') {
        await _showPurchaseRequired(context);
        try {
          await FacebookAuth.i.logOut();
        } catch (_) {}
        return null;
      }
      if (eFn.code == 'failed-precondition') {
        final msg = (eFn.message ?? '').toLowerCase();
        if (msg.contains('not active') || msg.contains('planstatus')) {
          await _showPlanNotActive(context);
          try {
            await FacebookAuth.i.logOut();
          } catch (_) {}
          return null;
        }
      }
      await _showFunctionError(context, "Facebook login failed", eFn);
      try {
        await FacebookAuth.i.logOut();
      } catch (_) {}
      return null;
    } catch (e) {
      _p('signInWithFacebook error: $e');
      await _showSimpleDialog(
        context,
        title: "Facebook sign-in failed",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      try {
        await FacebookAuth.i.logOut();
      } catch (_) {}
      return null;
    }
  }

  /* ------------------------------------------------------------------------ */
  /* ✅ CLIENT REQUIRED: EMAIL + PASSWORD (IN-APP ONLY)                        */
  /* ------------------------------------------------------------------------ */

  Future<void> sendShopifySetPasswordEmail(
      BuildContext context, {
        required String typedEmail,
      }) async {
    final emailLower = _normalizeEmail(typedEmail);

    if (emailLower.isEmpty || !_looksLikeEmail(emailLower)) {
      await _showEnterEmail(context);
      return;
    }

    try {
      // ✅ 1) Lookup account FIRST
      final lookup = await _lookupAccountByEmail(emailLower);
      final found = lookup?['found'] == true;

      if (!found) {
        await _showPurchaseRequired(context);
        return;
      }

      // ✅ accounts docId is the Shopify Customer ID
      final shopifyCustomerId =
      (lookup?['accountId'] ?? '').toString().trim();

      // ✅ 2) Call recover and include shopifyCustomerId
      final res = await _callable(_fnShopifyCustomerRecover).call(<String, dynamic>{
        'email': emailLower,
        'shopifyCustomerId': shopifyCustomerId,
      });

      final map = _asMap(res.data);

      final bool apiOk = map['ok'] == true;
      final bool sent = map['sent'] == true;
      final bool throttled = map['throttled'] == true;

      if (apiOk && sent) {
        await _showSimpleDialog(
          context,
          title: "Email sent",
          message: "We sent an email to $emailLower. Open it and tap the button to continue inside the app.",
          accent: Colors.green,
          icon: Icons.mark_email_read_outlined,
          showWebsiteActions: false,
        );
        return;
      }

      if (apiOk && throttled) {
        await _showSimpleDialog(
          context,
          title: "Please wait",
          message: "A reset email was already sent recently. Please wait a minute and try again.",
          accent: Colors.orange,
          icon: Icons.hourglass_bottom,
          showWebsiteActions: false,
        );
        return;
      }

      await _showSimpleDialog(
        context,
        title: "Check your inbox",
        message: "If this email is linked to a purchase, you will receive a password email shortly.",
        accent: Colors.green,
        icon: Icons.mark_email_read_outlined,
        showWebsiteActions: false,
      );
    } on FirebaseFunctionsException catch (eFn) {
      await _showFunctionError(context, "Unable to send email", eFn);
    } catch (e) {
      _p('sendShopifySetPasswordEmail error: $e');
      await _showSimpleDialog(
        context,
        title: "Unable to send email",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
    }
  }



  /// Step 6 (client): Login with Shopify email+password via backend,
  /// then sign into Firebase using the returned custom token.
  ///
  /// NOTE: Backend enforces entitlement (planStatus must be active).
  Future<UserCredential?> loginWithShopifyEmailPassword(
      BuildContext context, {
        required String email,
        required String password,
      }) async {
    final emailLower = _normalizeEmail(email);
    final pw = password.trim();

    if (emailLower.isEmpty || !_looksLikeEmail(emailLower)) {
      await _showEnterEmail(context);
      return null;
    }
    if (pw.isEmpty) {
      await _showSimpleDialog(
        context,
        title: "Enter password",
        message: "If you haven't set a password yet, tap “Send Set-Password Email” to create it inside the app.",
        accent: Colors.orange,
        icon: Icons.lock_outline,
        showWebsiteActions: false,
      );
      return null;
    }

    // Existence-only: account must exist (purchase happened).
    final ok = await _ensureAccountExists(context, emailLower);
    if (!ok) return null;

    try {
      final res = await _callable(_fnShopifyCustomerLogin).call(<String, dynamic>{
        'email': emailLower,
        'password': pw,
      });

      final map = _asMap(res.data);
      final customToken = (map['firebaseToken'] ?? map['customToken'] ?? '').toString().trim();

      if (customToken.isEmpty) {
        await _showSimpleDialog(
          context,
          title: "Login failed",
          message: (map['message'] ?? "Login failed.").toString(),
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      final userCredential = await _auth.signInWithCustomToken(customToken);
      await UserDatabaseService().createOrUpdateUser();
      _goHome(context);
      return userCredential;
    } on FirebaseFunctionsException catch (eFn) {
      final msg = (eFn.message ?? '').toLowerCase();

      if (eFn.code == 'unauthenticated') {
        await _showSimpleDialog(
          context,
          title: "Invalid credentials",
          message: "Invalid email or password.",
          accent: Colors.red,
          icon: Icons.lock_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      if (eFn.code == 'permission-denied' ||
          (eFn.code == 'failed-precondition' &&
              (msg.contains('not active') || msg.contains('planstatus')))) {
        await _showPlanNotActive(context);
        return null;
      }

      if (eFn.code == 'failed-precondition' && msg.contains('not found yet')) {
        await _showSimpleDialog(
          context,
          title: "Sync pending",
          message: "Your account is not synced yet. If you purchased recently, wait a moment and try again.",
          accent: Colors.orange,
          icon: Icons.hourglass_bottom,
          showWebsiteActions: false,
        );
        return null;
      }

      if (eFn.code == 'not-found') {
        await _showPurchaseRequired(context);
        return null;
      }

      await _showFunctionError(context, "Login failed", eFn);
      return null;
    } catch (e) {
      _p('loginWithShopifyEmailPassword error: $e');
      await _showSimpleDialog(
        context,
        title: "Login failed",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      return null;
    }
  }

  /// Step 5 (client): Set password inside app using token from email deep link.
  /// Backend performs customerReset(token,newPassword) then we do Step 6 login.
  ///
  /// IMPORTANT:
  /// - Backend contract is: { token, newPassword } (token ONLY).
  /// - Your backend currently expects token to be a FULL Shopify reset URL/path
  ///   (often URL-encoded) so it can call customerResetByUrl or extract parts.
  ///
  /// Email is REQUIRED here because we must login after reset.
  Future<UserCredential?> setShopifyPasswordAndLogin(
      BuildContext context, {
        required String resetUrlOrToken,
        required String email,
        required String newPassword,
      }) async {
    final tokenOrUrl = resetUrlOrToken.trim();
    final emailLower = _normalizeEmail(email);
    final pw = newPassword.trim();

    if (tokenOrUrl.isEmpty) {
      await _showSimpleDialog(
        context,
        title: "Invalid link",
        message: "Missing token. Please request a new email and try again.",
        accent: Colors.red,
        icon: Icons.link_off,
        showWebsiteActions: false,
      );
      return null;
    }

    if (emailLower.isEmpty || !_looksLikeEmail(emailLower)) {
      await _showSimpleDialog(
        context,
        title: "Enter email",
        message: "Please enter the same email you used on Shopify.",
        accent: Colors.orange,
        icon: Icons.mail_outline,
        showWebsiteActions: false,
      );
      return null;
    }

    if (pw.length < 8) {
      await _showSimpleDialog(
        context,
        title: "Password too short",
        message: "Password must be at least 8 characters.",
        accent: Colors.orange,
        icon: Icons.lock_outline,
        showWebsiteActions: false,
      );
      return null;
    }

    // Existence-only: purchase/account must exist.
    final ok = await _ensureAccountExists(context, emailLower);
    if (!ok) return null;

    try {
      final res = await _callable(_fnShopifyCustomerResetPassword).call(<String, dynamic>{
        // ✅ Backend expects ONE ONLY: token
        'token': tokenOrUrl,
        'newPassword': pw,
      });

      final map = _asMap(res.data);

      if (map['ok'] != true) {
        await _showSimpleDialog(
          context,
          title: "Set password failed",
          message: (map['message'] ?? "Please request a new email and try again.").toString(),
          accent: Colors.red,
          icon: Icons.error_outline,
          showWebsiteActions: false,
        );
        return null;
      }

      // Step 6 login (backend enforces entitlement/active plan).
      return await loginWithShopifyEmailPassword(
        context,
        email: emailLower,
        password: pw,
      );
    } on FirebaseFunctionsException catch (eFn) {
      final msg = (eFn.message ?? '').toLowerCase();

      if (eFn.code == 'failed-precondition' &&
          (msg.contains('invalid reset token') || msg.contains('reset token') || msg.contains('expired'))) {
        await _showSimpleDialog(
          context,
          title: "Link expired",
          message: "This password link is invalid or expired. Please request a new email and try again.",
          accent: Colors.red,
          icon: Icons.link_off,
          showWebsiteActions: false,
        );
        return null;
      }

      await _showFunctionError(context, "Set password failed", eFn);
      return null;
    } catch (e) {
      _p('setShopifyPasswordAndLogin error: $e');
      await _showSimpleDialog(
        context,
        title: "Set password failed",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      return null;
    }
  }

  /* ------------------------------------------------------------------------ */
  /* LEGACY Shopify email login (DO NOT USE for client email/password)        */
  /* ------------------------------------------------------------------------ */

  @Deprecated(
      'Client email/password must use sendShopifySetPasswordEmail + setShopifyPasswordAndLogin + loginWithShopifyEmailPassword.')
  Future<UserCredential?> signInWithShopifyEmail(
      BuildContext context, {
        required String typedEmail,
      }) async {
    final e = _normalizeEmail(typedEmail);

    if (e.isEmpty || !_looksLikeEmail(e)) {
      await _showEnterEmail(context);
      return null;
    }

    _sp('LEGACY Start: typedEmail="$typedEmail" normalized="$e"');

    final ok = await _ensureAccountIsActive(context, e);
    _sp('LEGACY Entitlement check result: ok=$ok for email="$e"');
    if (!ok) return null;

    try {
      final startUri = Uri.parse(_shopifyEmailLoginStartEndpoint).replace(
        queryParameters: <String, String>{
          'return_to': '$_shopifyEmailDeepLinkScheme://$_shopifyEmailDeepLinkHost',
          'email': e,
        },
      );

      _sp('LEGACY Opening FlutterWebAuth2. startUri=$startUri');

      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: startUri.toString(),
        callbackUrlScheme: _shopifyEmailDeepLinkScheme,
      );

      _sp('LEGACY FlutterWebAuth2 returned callbackUrl=$callbackUrl');

      final uri = Uri.parse(callbackUrl);
      return await _finishShopifyEmailLoginFromDeepLink(context, uri);
    } on FirebaseFunctionsException catch (eFn) {
      await _showFunctionError(context, "Email (Shopify) login failed", eFn);
      return null;
    } catch (err) {
      _sp('LEGACY ERROR in signInWithShopifyEmail: $err');
      await _showSimpleDialog(
        context,
        title: "Email (Shopify) login failed",
        message: "Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      return null;
    }
  }

  bool isShopifyEmailLoginDeepLink(Uri uri) {
    final token = (uri.queryParameters['firebaseToken'] ?? '').trim();
    final code = (uri.queryParameters['code'] ?? '').trim();

    final ok = uri.scheme == _shopifyEmailDeepLinkScheme &&
        uri.host == _shopifyEmailDeepLinkHost &&
        (token.isNotEmpty || code.isNotEmpty);

    _sp('LEGACY isShopifyEmailLoginDeepLink? $ok uri=$uri');
    return ok;
  }

  Future<void> handleShopifyEmailLoginDeepLink(BuildContext context, Uri uri) async {
    _sp('LEGACY handleShopifyEmailLoginDeepLink called with uri=$uri');
    if (!isShopifyEmailLoginDeepLink(uri)) return;
    await _finishShopifyEmailLoginFromDeepLink(context, uri);
  }

  Future<UserCredential?> _finishShopifyEmailLoginFromDeepLink(
      BuildContext context,
      Uri uri,
      ) async {
    _sp('LEGACY Finish: received uri=$uri');

    try {
      final firebaseToken = (uri.queryParameters['firebaseToken'] ?? '').trim();
      if (firebaseToken.isNotEmpty) {
        final userCredential = await _auth.signInWithCustomToken(firebaseToken);
        await UserDatabaseService().createOrUpdateUser();
        _goHome(context);
        return userCredential;
      }

      final code = (uri.queryParameters['code'] ?? '').trim();
      final shop = (uri.queryParameters['shop'] ?? '').trim();
      final state = (uri.queryParameters['state'] ?? '').trim();

      if (code.isNotEmpty) {
        final payload = <String, dynamic>{
          'code': code,
          if (shop.isNotEmpty) 'shop': shop,
          if (state.isNotEmpty) 'state': state,
        };

        final res = await _callable(_fnExchangeShopifyEmailLoginCode).call(payload);
        final map = _asMap(res.data);

        final customToken = (map['customToken'] ?? '').toString().trim();
        if (customToken.isEmpty) {
          await _showSimpleDialog(
            context,
            title: "Email (Shopify) login failed",
            message: "Missing session token from server.",
            accent: Colors.red,
            icon: Icons.error_outline,
            showWebsiteActions: false,
          );
          return null;
        }

        final userCredential = await _auth.signInWithCustomToken(customToken);
        await UserDatabaseService().createOrUpdateUser();
        _goHome(context);
        return userCredential;
      }

      await _showSimpleDialog(
        context,
        title: "Email (Shopify) login failed",
        message: "Unexpected callback received. Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      return null;
    } catch (err) {
      _sp('LEGACY ERROR in _finishShopifyEmailLoginFromDeepLink: $err');
      await _showSimpleDialog(
        context,
        title: "Email (Shopify) login failed",
        message: "An unexpected error occurred. Please try again.",
        accent: Colors.red,
        icon: Icons.error_outline,
        showWebsiteActions: false,
      );
      return null;
    }
  }

  /* ------------------------------------------------------------------------ */
  /* deleteAccount                                                             */
  /* ------------------------------------------------------------------------ */

  Future<void> deleteAccount(BuildContext context) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await UserDatabaseService().deleteUserAccount();
        await user.delete();
        _goAuth(context);
        if (context.mounted) {
          ShowAlertBar().alertDialog(context, "Account deleted.", Colors.lightBlue);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ShowAlertBar().alertDialog(context, "Failed to delete account: ${e.message}", Colors.red);
      }
    } catch (_) {
      if (context.mounted) {
        ShowAlertBar().alertDialog(context, "Something went wrong.", Colors.red);
      }
    }
  }

  /* ------------------------------------------------------------------------ */
  /* Splash session check                                                      */
  /* ------------------------------------------------------------------------ */

  Future<bool> isCurrentSessionActive() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      String email = (user.email ?? '').trim();
      if (email.isEmpty) {
        for (final p in user.providerData) {
          final pe = (p.email ?? '').trim();
          if (pe.isNotEmpty) {
            email = pe;
            break;
          }
        }
      }

      if (email.isEmpty) return false;

      final lookup = await _lookupAccountByEmail(email);
      if (lookup == null || lookup['found'] != true) return false;

      final planStatus = (lookup['planStatus'] ?? 'inactive').toString();
      return planStatus == 'active';
    } catch (e) {
      _p('isCurrentSessionActive error: $e');
      return false;
    }
  }

  /* ------------------------------------------------------------------------ */
  /* Logout + basics                                                           */
  /* ------------------------------------------------------------------------ */

  Future<void> logout(BuildContext context) async {
    try {
      await _auth.signOut();
      await _safeGoogleLogout();
      try {
        await FacebookAuth.i.logOut();
      } catch (_) {}

      _goAuth(context);

      if (context.mounted) {
        ShowAlertBar().alertDialog(context, "Logged out successfully.", Colors.lightBlue);
      }
    } catch (e) {
      _p('logout error: $e');
      if (context.mounted) {
        ShowAlertBar().alertDialog(context, "Failed to log out.", Colors.red);
      }
    }
  }

  bool isLoggedIn(BuildContext context) => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /* ------------------------------------------------------------------------ */
  /* Cloud Functions helpers                                                   */
  /* ------------------------------------------------------------------------ */

  HttpsCallable _callable(String name) {
    _p('Creating callable: $name (region=us-central1)');
    return _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 25)),
    );
  }

  Future<Map<String, dynamic>?> _lookupAccountByEmail(String email) async {
    final emailLower = _normalizeEmail(email);
    if (emailLower.isEmpty || !_looksLikeEmail(emailLower)) return null;

    final res = await _callable(_fnLookupAccountByEmail).call(<String, dynamic>{
      'email': emailLower,
    });

    final map = _asMap(res.data);
    return map.isEmpty ? null : map;
  }

  Future<Map<String, dynamic>?> _linkAuthToAccountSocial({
    required String provider,
    required String tokenKey,
    required String token,
  }) async {
    final res = await _callable(_fnLinkAuthToAccount).call(<String, dynamic>{
      'provider': provider,
      tokenKey: token,
    });

    final map = _asMap(res.data);
    return map.isEmpty ? null : map;
  }

  /// ✅ Existence-only check: purchase/account exists (found == true).
  /// Used for the client-required Shopify set-password/reset/login flow.
  Future<bool> _ensureAccountExists(BuildContext context, String emailLower) async {
    try {
      final lookup = await _lookupAccountByEmail(emailLower);
      final found = (lookup?['found'] == true);

      if (!found) {
        await _showPurchaseRequired(context);
        return false;
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        await _showPurchaseRequired(context);
        return false;
      }
      await _showFunctionError(context, "Account check failed", e);
      return false;
    } catch (_) {
      if (context.mounted) {
        ShowAlertBar().alertDialog(
          context,
          "Account check failed. Please try again.",
          Colors.red,
        );
      }
      return false;
    }
  }

  /// Entitlement check (active plan) — keep for gated product access if required.
  Future<bool> _ensureAccountIsActive(BuildContext context, String emailLower) async {
    try {
      final lookup = await _lookupAccountByEmail(emailLower);

      final found = (lookup?['found'] == true);
      final planStatus = (lookup?['planStatus'] ?? 'inactive').toString();

      if (!found) {
        await _showPurchaseRequired(context);
        return false;
      }

      if (planStatus != 'active') {
        await _showPlanNotActive(context);
        return false;
      }

      return true;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found') {
        await _showPurchaseRequired(context);
        return false;
      }

      if (e.code == 'failed-precondition') {
        final msg = (e.message ?? '').toLowerCase();
        if (msg.contains('not active') || msg.contains('planstatus')) {
          await _showPlanNotActive(context);
          return false;
        }
      }

      await _showFunctionError(context, "Account check failed", e);
      return false;
    } catch (_) {
      if (context.mounted) {
        ShowAlertBar().alertDialog(
          context,
          "Account check failed. Please try again.",
          Colors.red,
        );
      }
      return false;
    }
  }

  /* ------------------------------------------------------------------------ */
  /* Dialogs                                                                   */
  /* ------------------------------------------------------------------------ */

  Future<void> _showSimpleDialog(
      BuildContext context, {
        required String title,
        required String message,
        required Color accent,
        required IconData icon,
        required bool showWebsiteActions,
      }) async {
    if (!context.mounted) return;

    final uri = Uri.parse(_reviewsEverywhereWebsite);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14.5, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Close"),
          ),
          if (showWebsiteActions)
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text("Open Website"),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                try {
                  final ok = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (!ok && context.mounted) {
                    ShowAlertBar().alertDialog(
                      context,
                      "Unable to open the website. Please open it manually: $_reviewsEverywhereWebsiteDisplay",
                      Colors.red,
                    );
                  }
                } catch (_) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ShowAlertBar().alertDialog(
                      context,
                      "Unable to open the website. Please open it manually: $_reviewsEverywhereWebsiteDisplay",
                      Colors.red,
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showEnterEmail(BuildContext context) async {
    await _showSimpleDialog(
      context,
      title: "Enter your purchase email",
      message: "Please enter the email you used to purchase the wristband on $_reviewsEverywhereWebsiteDisplay.",
      accent: Colors.orange,
      icon: Icons.mail_outline,
      showWebsiteActions: false,
    );
  }

  Future<void> _showPurchaseRequired(BuildContext context) async {
    await _showSimpleDialog(
      context,
      title: "Purchase required",
      message: "No wristband plan was found for this email. Please purchase from $_reviewsEverywhereWebsiteDisplay.",
      accent: Colors.red,
      icon: Icons.shopping_cart_outlined,
      showWebsiteActions: true,
    );
  }

  Future<void> _showPlanNotActive(BuildContext context) async {
    await _showSimpleDialog(
      context,
      title: "Plan not active",
      message:
      "Your plan is not active yet. If you purchased recently, wait a few minutes for sync. Otherwise purchase from $_reviewsEverywhereWebsiteDisplay.",
      accent: Colors.orange,
      icon: Icons.hourglass_bottom,
      showWebsiteActions: true,
    );
  }

  Future<void> _showFunctionError(
      BuildContext context,
      String title,
      FirebaseFunctionsException e,
      ) async {
    await _showSimpleDialog(
      context,
      title: title,
      message: "${e.code}: ${e.message ?? 'Unknown error'}",
      accent: Colors.red,
      icon: Icons.error_outline,
      showWebsiteActions: false,
    );
  }

  /* ------------------------------------------------------------------------ */
  /* Safe provider sign-outs                                                   */
  /* ------------------------------------------------------------------------ */

  Future<void> _safeGoogleLogout() async {
    try {
      final dynamic gs = GoogleSignIn.instance;
      await gs.signOut();
    } catch (_) {}
  }
}
