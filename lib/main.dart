import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'managers/authorisation_manager.dart';
import 'view_models/app_viewmodel.dart';
import 'views/initial_page.dart';
import 'views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthorisationManager()),
        ChangeNotifierProvider(create: (_) => AppViewModel()),
      ],
      child: MaterialApp(
        title: 'Bleya',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
        home: InitialPage(),
        routes: {
          '/home': (context) => HomePage(),
        },
      ),
    );
  }
}
