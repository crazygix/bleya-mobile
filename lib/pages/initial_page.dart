import 'package:bleya/pages/authorisation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class InitialPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends ConsumerState<InitialPage> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(secureStorageProvider);
    final existingToken = await storage.read(key: 'auth_token');
    if (!mounted) return;
    if (existingToken != null && existingToken.isNotEmpty) {
      ref.read(tokenProvider.notifier).state = existingToken;
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Attempt silent refresh using httpOnly cookie
      try {
        final authService = ref.read(authServiceProvider);
        final newToken = await authService.refresh();
        ref.read(tokenProvider.notifier).state = newToken;
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
        return;
      } catch (_) {
        // ignore and show auth page
      }
      setState(() {
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return AuthorisationPage();
  }
}
