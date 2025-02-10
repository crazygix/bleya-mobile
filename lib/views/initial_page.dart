import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/authorisation_manager.dart';
import 'home_page.dart';
import 'authorisation_page.dart';

class InitialScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // final authManager =
    // Provider.of<AuthorisationManager>(context, listen: false);

    // if (authManager.isLoggedIn()) {
    // return HomePage();
    // } else {
    return AuthorisationPage();
    // }
  }
}
