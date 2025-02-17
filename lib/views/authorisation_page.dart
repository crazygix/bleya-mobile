import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../managers/authorisation_manager.dart';

class AuthorisationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthorisationManager(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Authorisation'),
        ),
        body: Center(
          child: Consumer<AuthorisationManager>(
            builder: (context, manager, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Authorisation'),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: manager.phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => manager.verifyPhoneNumber(),
                    child: Text('Verify Phone Number'),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: manager.codeController,
                      decoration: InputDecoration(
                        labelText: 'Verification Code',
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => manager.signInWithPhoneNumber(context),
                    child: Text('Sign In'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
