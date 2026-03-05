import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'pages/initial_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/username_page.dart';
import 'config/environment.dart';
import 'providers/auth_providers.dart';
import 'providers/connectivity_provider.dart';
import 'utils/navigation.dart';
import 'constants/theme.dart';
import 'platform/app_route.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set environment based on build configuration or environment variable
  // Check explicit environment first, then fall back to build mode defaults.
  const envOverride = String.fromEnvironment('FLUTTER_ENV', defaultValue: '');
  final normalizedEnv = envOverride.trim().toLowerCase();
  final environment = switch (normalizedEnv) {
    'prod' || 'production' => Environment.prod,
    'dev' || 'development' => Environment.dev,
    _ => kDebugMode ? Environment.dev : Environment.prod,
  };

  EnvironmentConfig.setEnvironment(environment);

  // Resolve cookie storage directory BEFORE any Dio requests can run, so we never
  // miss the Set-Cookie(refreshToken) coming from /auth/verify-code.
  final supportDir = await getApplicationSupportDirectory();
  final cookieStoragePath = '${supportDir.path}/bleya';

  runApp(ProviderScope(
    overrides: [
      cookieStoragePathProvider.overrideWithValue(cookieStoragePath),
    ],
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
        colorScheme: ColorScheme.fromSeed(seedColor: BleyaTheme.primary),
        scaffoldBackgroundColor: BleyaTheme.background,
      ),
      debugShowCheckedModeBanner: false, // Disable default banner
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ConnectivityBanner(child: child ?? const SizedBox.shrink()),
        );
      },
      routes: {
        '/': (context) => InitialPage(),
        '/home': (context) => DashboardPage(),
      },
      onGenerateRoute: (settings) {
        // Handle username page route if needed
        if (settings.name == '/username') {
          return AppRoute.build(
            builder: (context) => UsernamePage(),
          );
        }
        return null;
      },
    );

    // Show custom banner only in debug mode
    if (kDebugMode) {
      final bannerText = EnvironmentConfig.isProduction ? 'Prod' : 'Dev';
      final bannerColor =
          EnvironmentConfig.isProduction ? Colors.red : BleyaTheme.success;

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

/// Widget that shows a banner when there's no internet connection
class ConnectivityBanner extends ConsumerWidget {
  final Widget child;

  const ConnectivityBanner({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);

    return Stack(
      children: [
        child,
        if (!isOnline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.red,
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No internet connection',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
