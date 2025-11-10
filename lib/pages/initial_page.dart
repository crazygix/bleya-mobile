import 'package:bleya/pages/authorisation_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

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
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bootstrapAsync = ref.watch(bootstrapProvider);
    
    return bootstrapAsync.when(
      data: (isAuthenticated) {
        // If authenticated, show loading while navigating (navigation happens in _checkAuthAndNavigate)
        // If not authenticated, show authorization page
        return isAuthenticated 
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : AuthorisationPage();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AuthorisationPage(),
    );
  }
}
