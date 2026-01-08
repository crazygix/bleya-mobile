import 'package:bleya/pages/authorisation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import 'username_page.dart';
import 'intro_page.dart';

class InitialPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends ConsumerState<InitialPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthAndNavigate();
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final bootstrap = ref.read(bootstrapProvider.future);
    final isAuthenticated = await bootstrap;

    if (!mounted) return;

    if (isAuthenticated) {
      // Double-check we have a token before making API calls
      final token = ref.read(tokenProvider);
      if (token == null || token.isEmpty) {
        // Token was cleared during bootstrap, navigate to login
        if (mounted) {
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => AuthorisationPage()),
          );
        }
        return;
      }

      // Check if user has username
      try {
        final userService = ref.read(userServiceProvider);
        final profile = await userService.getProfile();
        final username = profile['username'] as String?;
        final hasUsername = username != null && username.trim().isNotEmpty;

        if (!mounted) return;

        if (!hasUsername) {
          // Navigate to username page if username is missing
          Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => UsernamePage()),
          );
        } else {
          // Navigate to home if username is set
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } catch (e) {
        // If profile fetch fails, still try to navigate to home
        // The error will be handled by the interceptor
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(bootstrapProvider);

    return bootstrapAsync.when(
      data: (isAuthenticated) {
        // If authenticated, show loading while navigating (navigation happens in _checkAuthAndNavigate)
        // If not authenticated, show intro page
        return isAuthenticated
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : IntroPage();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => IntroPage(),
    );
  }
}
