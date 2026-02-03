// lib/features/nfc_tag/presentation/pages/splash_page.dart

import 'dart:async';
import 'package:cards/firebase/auth_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SplashPage extends StatefulWidget {
  static const routeName = '/';
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () async {
      final user = _auth.currentUser;

      if (!mounted) return;

      if (user == null) {
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      // ✅ Verify current session is still eligible (planStatus == active)
      final active = await AuthService().isCurrentSessionActive();

      if (!mounted) return;

      if (active) {
        Navigator.pushReplacementNamed(context, '/home');
      } else {
        // ✅ Phase-1: No activation page. Shopify is source of truth.
        await _auth.signOut();
        if (!mounted) return;

        Navigator.pushReplacementNamed(context, '/auth');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/logo_1.png'),
          width: 200,
          height: 200,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
