// lib/app.dart
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cards/features/nfc_tag/presentation/di/injection.dart';
import 'package:cards/features/nfc_tag/presentation/viewmodels/home_view_model.dart';
import 'package:cards/features/nfc_tag/presentation/pages/splash_page.dart';
import 'package:cards/features/nfc_tag/presentation/pages/home_page.dart';
import 'package:cards/features/nfc_tag/presentation/pages/auth/auth_page.dart';
import 'package:cards/features/nfc_tag/presentation/pages/auth/set_password_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  // De-dupe deep link processing
  String _lastSetPasswordToken = '';

  // Queue deep link until Navigator is ready (cold start safe)
  Uri? _pendingUri;

  @override
  void initState() {
    super.initState();

    _listenDeepLinks();

    // Handle cold start deep link after first frame (Navigator ready)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _handleInitialLink();
      _drainPendingIfAny();
    });
  }

  void _listenDeepLinks() {
    _sub = _appLinks.uriLinkStream.listen(
          (uri) {
        _handleIncomingUri(uri);
      },
      onError: (err) => debugPrint('[DeepLink] stream error: $err'),
    );
  }

  Future<void> _handleInitialLink() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handleIncomingUri(initial);
      }
    } catch (e) {
      debugPrint('[DeepLink] initialLink error: $e');
    }
  }

  bool _isSetPasswordDeepLink(Uri uri) {
    // Client-required link:
    // reviewseverywhere://set-password?token=...
    if (uri.scheme != 'reviewseverywhere') return false;

    // With custom scheme, host is usually "set-password"
    if (uri.host == 'set-password') return true;

    // Some clients may deliver as: reviewseverywhere:/set-password?token=...
    if (uri.path == '/set-password' || uri.path == 'set-password') return true;

    // Or path segments
    final segs = uri.pathSegments;
    if (segs.isNotEmpty && segs.first == 'set-password') return true;

    return false;
  }

  void _handleIncomingUri(Uri uri) {
    // If Navigator is not ready yet, queue and drain later.
    if (_navKey.currentState == null) {
      _pendingUri = uri;
      return;
    }

    if (!_isSetPasswordDeepLink(uri)) return;

    final token = (uri.queryParameters['token'] ?? '').trim();

    if (token.isEmpty) {
      debugPrint('[DeepLink] set-password missing token: $uri');
      return;
    }

    // De-dupe
    if (token == _lastSetPasswordToken) return;
    _lastSetPasswordToken = token;

    debugPrint('[DeepLink] set-password tokenLen=${token.length}');

    // NOTE: email is not required by the client flow. Keep empty for backwards compatibility
    // in case SetPasswordArgs currently expects it.
    final args = SetPasswordArgs(token: token, email: '');

    _navKey.currentState?.pushNamed(
      SetPasswordPage.routeName,
      arguments: args,
    );
  }

  void _drainPendingIfAny() {
    final navReady = _navKey.currentState != null;
    if (!navReady) return;

    final uri = _pendingUri;
    if (uri == null) return;

    _pendingUri = null;
    _handleIncomingUri(uri);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    super.dispose();
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    if (settings.name == SetPasswordPage.routeName) {
      final args = settings.arguments;

      if (args is SetPasswordArgs) {
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => SetPasswordPage(args: args),
        );
      }

      return MaterialPageRoute(
        builder: (_) => const Scaffold(
          body: SafeArea(
            child: Center(
              child: Text('Invalid password link. Please request a new email.'),
            ),
          ),
        ),
      );
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    // If a deep link arrived before build finished, process after this frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainPendingIfAny());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => sl<HomeViewModel>()),
      ],
      child: MaterialApp(
        navigatorKey: _navKey,
        title: 'Reviews Everywhere',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: false),
        initialRoute: SplashPage.routeName,
        onGenerateRoute: _onGenerateRoute,
        routes: {
          SplashPage.routeName: (_) => const SplashPage(),
          AuthPage.routeName: (_) => const AuthPage(),
          HomePage.routeName: (_) => const HomePage(),
          // DO NOT put SetPasswordPage here (it requires args)
        },
      ),
    );
  }
}
