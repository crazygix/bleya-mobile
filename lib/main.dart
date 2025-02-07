import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'view_models/app_viewmodel.dart';
import 'views/initial_page.dart';

void main() {
  runApp(App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppViewModel(),
      child: MaterialApp(
        title: 'Bleya',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
        ),
        home: InitialScreen(),
      ),
    );
  }
}
