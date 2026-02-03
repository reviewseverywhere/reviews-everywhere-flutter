// lib/features/nfc_tag/presentation/pages/auth/set_password_page.dart

import 'package:flutter/material.dart';
import 'package:cards/firebase/auth_services.dart';

class SetPasswordArgs {
  /// Deep link:
  /// reviewseverywhere://set-password?token=...
  ///
  /// token MUST be the URL-encoded Shopify reset password URL (or reset path),
  /// as provided by the Shopify email template.
  final String token;

  /// Email is OPTIONAL. Client flow already collects email inside the app,
  /// but some deep links may not include it.
  final String email;

  const SetPasswordArgs({required this.token, required this.email});
}

class SetPasswordPage extends StatefulWidget {
  static const routeName = '/set-password';
  final SetPasswordArgs args;

  const SetPasswordPage({super.key, required this.args});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _pw1 = TextEditingController();
  final _pw2 = TextEditingController();
  final _auth = AuthService();

  bool _busy = false;
  bool _showPw1 = false;
  bool _showPw2 = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.args.email.trim();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pw1.dispose();
    _pw2.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  bool _looksLikeEmail(String v) {
    final s = v.trim();
    return s.contains('@') && s.contains('.');
  }

  Future<void> _submit() async {
    if (_busy) return;

    final email = _emailCtrl.text.trim();
    final p1 = _pw1.text.trim();
    final p2 = _pw2.text.trim();

    if (!_looksLikeEmail(email)) {
      _snack('Please enter the same email you used on Shopify.');
      return;
    }

    if (p1.length < 8) {
      _snack('Password must be at least 8 characters.');
      return;
    }
    if (p1 != p2) {
      _snack('Passwords do not match.');
      return;
    }

    setState(() => _busy = true);

    try {
      // Client Step 5 + Step 6 (inside app):
      // - customerReset(token, newPassword) via backend callable
      // - then customerAccessTokenCreate(email, password) via backend callable
      //
      // NOTE: token here is the deep-link token ("token" query param),
      // which must be the URL-encoded Shopify reset URL/path.
      await _auth.setShopifyPasswordAndLogin(
        context,
        resetUrlOrToken: widget.args.token, // keep existing AuthService param name
        email: email,
        newPassword: p1,
      );

      // AuthService should navigate on success.
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_busy &&
        _emailCtrl.text.trim().isNotEmpty &&
        _pw1.text.trim().isNotEmpty &&
        _pw2.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Set Password'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: Colors.black.withOpacity(0.06)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create your password',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This will set your Shopify password inside the app. After this, you can log in normally with email + password.',
                    style: TextStyle(
                      fontSize: 13.3,
                      height: 1.25,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _emailCtrl,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email (same as Shopify purchase)',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _pw1,
                    obscureText: !_showPw1,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'New password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: _busy ? null : () => setState(() => _showPw1 = !_showPw1),
                        icon: Icon(_showPw1 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: _pw2,
                    obscureText: !_showPw2,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => canSubmit ? _submit() : null,
                    decoration: InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: _busy ? null : () => setState(() => _showPw2 = !_showPw2),
                        icon: Icon(_showPw2 ? Icons.visibility_off : Icons.visibility),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: canSubmit ? _submit : null,
                      child: _busy
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : const Text(
                        'Set Password',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
