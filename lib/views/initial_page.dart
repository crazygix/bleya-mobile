import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/authorisation_manager.dart';
import 'home_page.dart';
import 'authorisation_page.dart';

class InitialPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final authManager =
        Provider.of<AuthorisationManager>(context, listen: false);

    return FutureBuilder<bool>(
      future: authManager.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (snapshot.hasData && snapshot.data == true) {
          return HomePage();
        } else {
          return AuthorisationPage();
        }
      },
    );
  }
}
