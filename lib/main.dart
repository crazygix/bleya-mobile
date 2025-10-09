import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/initial_page.dart';
import 'pages/home_page.dart';
import 'config/environment.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set environment based on build configuration
  // In debug mode, use development environment
  // In release mode, use production environment
  EnvironmentConfig.setEnvironment(
    kDebugMode ? Environment.dev : Environment.prod,
  );

  runApp(ProviderScope(
    child: MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
