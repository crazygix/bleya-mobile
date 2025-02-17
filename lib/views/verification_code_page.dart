import 'package:bleya/managers/authorisation_manager.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class VerificationCodePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Verification Code'),
      ),
      body: Center(
        child: Consumer<AuthorisationManager>(
          builder: (context, manager, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Enter the verification code'),
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
    );
  }
}
