// lib/features/nfc_tag/presentation/pages/auth/auth_page.dart
//
// Client-required flow (NO Shopify-hosted UI):
// - User enters purchase email + password inside the app.
// - If user has no password yet, user taps "Forgot password?" inside the app.
// - App triggers Shopify recovery email; the email link deep-links back into the app.
// - User sets password inside the app (NOT on a Shopify reset page).
// - From then on: normal email+password login (no OTP, no redirects).
//
// Uses AuthService:
// - loginWithShopifyEmailPassword(...)
// - sendShopifySetPasswordEmail(...)
// - signInWithGoogle(...)
// - signInWithFacebook(...)

import 'package:cards/firebase/auth_services.dart';
import 'package:flutter/material.dart';

enum _AuthProvider { shopifyLogin, shopifyForgot, google, facebook }

class AuthPage extends StatefulWidget {
  static const routeName = '/auth';
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const _bg = Color(0xFFF6F7FB);
  static const _blue = Color(0xFF0066CC);
  static const _fbBlue = Color(0xFF1877F2);
  static const _green = Color(0xFF0B7A3C);
  static const _shopifyPurple = Color(0xFF5A31F4);

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();

  _AuthProvider? _loadingProvider;
  bool _obscurePassword = true;
  bool _showOtherOptions = false;

  bool get _busy => _loadingProvider != null;

  String get _email => _emailController.text.trim();
  String get _password => _passwordController.text.trim();

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.contains('@') && s.contains('.');
  }

  bool get _hasEmail => _email.isNotEmpty;
  bool get _hasPassword => _password.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onAnyChanged);
    _passwordController.addListener(_onAnyChanged);
  }

  @override
  void dispose() {
    _emailController.removeListener(_onAnyChanged);
    _passwordController.removeListener(_onAnyChanged);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onAnyChanged() {
    if (!mounted) return;
    setState(() {
      // Client rule: social options should not appear while user is typing email/password.
      if (_emailController.text.trim().isNotEmpty ||
          _passwordController.text.trim().isNotEmpty) {
        _showOtherOptions = false;
      }
    });
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  Future<void> _handleShopifyLogin() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    setState(() => _loadingProvider = _AuthProvider.shopifyLogin);
    try {
      await _auth.loginWithShopifyEmailPassword(
        context,
        email: _email,
        password: _password,
      );
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _handleForgotPassword() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    setState(() => _loadingProvider = _AuthProvider.shopifyForgot);
    try {
      // AuthService already shows success/error dialogs.
      await _auth.sendShopifySetPasswordEmail(context, typedEmail: _email);
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _handleGoogle() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    setState(() => _loadingProvider = _AuthProvider.google);
    try {
      await _auth.signInWithGoogle(context);
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  Future<void> _handleFacebook() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    setState(() => _loadingProvider = _AuthProvider.facebook);
    try {
      await _auth.signInWithFacebook(context);
    } finally {
      if (mounted) setState(() => _loadingProvider = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Client rule: social only when BOTH fields empty
    final canTapSocial = !_hasEmail && !_hasPassword && !_busy;

    // Primary login requirements
    final canTapLogin = _hasEmail && _hasPassword && !_busy;

    // Forgot password requires a valid email only
    final canTapForgot = _hasEmail && _looksLikeEmail(_email) && !_busy;

    final loadingLogin = _loadingProvider == _AuthProvider.shopifyLogin;
    final loadingForgot = _loadingProvider == _AuthProvider.shopifyForgot;

    final infoText = _busy
        ? "Working…"
        : (!_hasEmail && !_hasPassword)
        ? "Enter the email used for your Shopify purchase, then sign in with your password."
        : (_hasEmail && !_hasPassword)
        ? "No password yet? Tap “Forgot password?” to receive an email link that opens this app to set your password."
        : "Ready to sign in.";

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: size.height - 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 8),
                    const Image(
                      image: AssetImage('assets/logo_1.png'),
                      width: 190,
                      height: 190,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Sign in",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Everything happens inside the app. Use the same email as your Shopify purchase. "
                                  "If you do not have a password yet, tap “Forgot password?” to receive a secure email link "
                                  "that opens this app to set your password.",
                              style: TextStyle(
                                fontSize: 13.3,
                                height: 1.25,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Email
                            TextField(
                              controller: _emailController,
                              enabled: !_busy,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              enableSuggestions: false,
                              autofillHints: const [
                                AutofillHints.email,
                                AutofillHints.username,
                              ],
                              decoration: InputDecoration(
                                labelText: "Purchase email",
                                hintText: "name@example.com",
                                prefixIcon: const Icon(Icons.email_outlined),
                                filled: true,
                                fillColor: const Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _blue,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Password
                            TextField(
                              controller: _passwordController,
                              enabled: !_busy,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) =>
                              canTapLogin ? _handleShopifyLogin() : null,
                              decoration: InputDecoration(
                                labelText: "Password",
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword
                                      ? "Show password"
                                      : "Hide password",
                                  onPressed:
                                  _busy ? null : _togglePasswordVisibility,
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.black.withOpacity(0.08),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: _blue,
                                    width: 1.4,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Forgot password link (secondary)
                            Row(
                              children: [
                                TextButton(
                                  onPressed:
                                  canTapForgot ? _handleForgotPassword : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _shopifyPurple,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (loadingForgot)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      else
                                        const Icon(
                                          Icons.help_outline,
                                          size: 18,
                                        ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "Forgot password?",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                if ((_hasEmail || _hasPassword) && !_busy)
                                  Text(
                                    "Clear fields for social",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    infoText,
                                    style: TextStyle(
                                      fontSize: 12.6,
                                      height: 1.25,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            // Primary login button (single primary CTA)
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _shopifyPurple,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed:
                                canTapLogin ? _handleShopifyLogin : null,
                                child: loadingLogin
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Other options (collapsed)
                            InkWell(
                              onTap: _busy
                                  ? null
                                  : () => setState(() =>
                              _showOtherOptions = !_showOtherOptions),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding:
                                const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      _showOtherOptions
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.grey.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "Other sign-in options",
                                      style: TextStyle(
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ✅ Show social ONLY when both fields are empty (client rule)
                            if (_showOtherOptions && canTapSocial) ...[
                              const SizedBox(height: 6),
                              _FullWidthSocialButton(
                                enabled: canTapSocial,
                                loading:
                                _loadingProvider == _AuthProvider.google,
                                background: Colors.white,
                                borderColor: Colors.black.withOpacity(0.12),
                                textColor: Colors.black87,
                                label: "Continue with Google",
                                icon: Image.asset(
                                  "assets/google.png",
                                  height: 22,
                                  width: 22,
                                ),
                                onTap: _handleGoogle,
                              ),
                              const SizedBox(height: 12),
                              _FullWidthSocialButton(
                                enabled: canTapSocial,
                                loading:
                                _loadingProvider == _AuthProvider.facebook,
                                background: _fbBlue,
                                borderColor: Colors.transparent,
                                textColor: Colors.white,
                                label: "Continue with Facebook",
                                icon: Image.asset(
                                  "assets/facebook.png",
                                  height: 22,
                                  width: 22,
                                  color: Colors.white,
                                ),
                                onTap: _handleFacebook,
                              ),
                            ] else if (_showOtherOptions && !canTapSocial) ...[
                              const SizedBox(height: 6),
                              Text(
                                "To use social sign-in, clear the email and password fields.",
                                style: TextStyle(
                                  fontSize: 12.6,
                                  height: 1.25,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withOpacity(0.10),
                                    thickness: 1,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Haven’t purchased yet?",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Divider(
                                    color: Colors.black.withOpacity(0.10),
                                    thickness: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _auth.openPurchaseOrMyAccount(
                                  context,
                                  typedEmail: _email,
                                ),
                                child: const Text(
                                  "Purchase Wristband",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      "Everything happens inside the app. Shopify validates email + password and returns a customer access token for your session. Firebase is downstream only and is not used for password storage or validation.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.3,
                        height: 1.25,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullWidthSocialButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final Color background;
  final Color borderColor;
  final Color textColor;
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _FullWidthSocialButton({
    required this.enabled,
    required this.loading,
    required this.background,
    required this.borderColor,
    required this.textColor,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveEnabled = enabled && !loading;

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: effectiveEnabled ? onTap : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    background == const Color(0xFF1877F2)
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
              )
            else
              icon,
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
