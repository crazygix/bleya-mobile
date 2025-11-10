import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/initial_page.dart';
import 'pages/home_page.dart';
import 'config/environment.dart';
import 'providers/auth_providers.dart';
import 'utils/navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set environment based on build configuration or environment variable
  // Check for explicit environment variable first, then fall back to build mode
  const envOverride = String.fromEnvironment('FLUTTER_ENV', defaultValue: '');
  final environment = envOverride == 'prod' 
      ? Environment.prod
      : (kDebugMode ? Environment.dev : Environment.prod);
  
  EnvironmentConfig.setEnvironment(environment);

  runApp(ProviderScope(
    child: MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize token from secure storage
    ref.watch(tokenInitializerProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Bleya',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme:
            ColorScheme.fromSeed(seedColor: CupertinoColors.systemBlue),
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      debugShowCheckedModeBanner: kDebugMode, // Show banner only in debug mode
      routes: {
        '/': (context) => InitialPage(),
        '/home': (context) => HomePage(),
      },
    );
  }
}
