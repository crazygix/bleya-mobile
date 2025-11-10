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

    final materialApp = MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Bleya',
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme:
            ColorScheme.fromSeed(seedColor: CupertinoColors.systemBlue),
        scaffoldBackgroundColor: CupertinoColors.systemBackground,
      ),
      debugShowCheckedModeBanner: false, // Disable default banner
      routes: {
        '/': (context) => InitialPage(),
        '/home': (context) => HomePage(),
      },
    );

    // Show custom banner only in debug mode
    if (kDebugMode) {
      final bannerText = EnvironmentConfig.isProduction ? 'Prod' : 'Dev';
      final bannerColor =
          EnvironmentConfig.isProduction ? Colors.red : Colors.green;

      return Directionality(
        textDirection: TextDirection.ltr,
        child: Banner(
          message: bannerText,
          location: BannerLocation.topEnd,
          color: bannerColor,
          textStyle: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
          child: materialApp,
        ),
      );
    }

    return materialApp;
  }
}
