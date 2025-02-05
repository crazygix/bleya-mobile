import 'package:flutter/material.dart';

/// The Widget that configures your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Initial Screen'),
        ),
        body: Center(
          child: Text('Welcome to the initial screen!'),
        ),
      ),
    );
  }
}
