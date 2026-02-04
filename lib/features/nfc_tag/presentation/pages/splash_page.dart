// lib/features/nfc_tag/presentation/pages/splash_page.dart

import 'dart:async';
import 'package:cards/firebase/auth_services.dart';
import 'package:cards/features/onboarding/data/onboarding_service.dart';
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

      // Verify current session is still eligible (planStatus == active)
      final active = await AuthService().isCurrentSessionActive();

      if (!mounted) return;

      if (!active) {
        // No activation: sign out and go to auth
        await _auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/auth');
        return;
      }

      // Check if onboarding is complete
      final onboardingComplete = await OnboardingService().isOnboardingComplete();

      if (!mounted) return;

      if (onboardingComplete) {
        // Onboarding done: go to main dashboard
        Navigator.pushReplacementNamed(context, '/main');
      } else {
        // First time: show onboarding
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Image(
              image: AssetImage('assets/logo_1.png'),
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF5A31F4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
