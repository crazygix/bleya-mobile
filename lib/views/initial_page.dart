import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/authorisation_manager.dart';
import 'home_page.dart';
import 'authorisation_page.dart';

class InitialScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthorisationManager>(
      builder: (context, authorisationManager, child) {
        return FutureBuilder(
          future: authorisationManager.isLoggedIn(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else {
              if (snapshot.hasData && snapshot.data == true) {
                return HomePage();
              } else {
                return AuthorisationPage();
              }
            }
          },
        );
      },
    );
  }
}
