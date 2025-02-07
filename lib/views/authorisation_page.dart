import 'package:flutter/material.dart';

class AuthorisationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login/Signup'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Login or Signup'),
            // Add your login/signup form here
          ],
        ),
      ),
    );
  }
}
