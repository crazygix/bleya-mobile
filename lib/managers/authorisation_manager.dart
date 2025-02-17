import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthorisationManager extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  String? _verificationId;

  Future<void> verifyPhoneNumber(BuildContext context) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneController.text,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        notifyListeners();
      },
      verificationFailed: (FirebaseAuthException e) {
        print('Verification failed: ${e.message}');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        notifyListeners();
        Navigator.pushNamed(context, '/verification_code_page');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> signInWithPhoneNumber(BuildContext context) async {
    final code = codeController.text.trim();
    if (_verificationId == null) {
      print('Verification ID is null');
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: code,
    );

    try {
      await _auth.signInWithCredential(credential);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print('Failed to sign in: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    return _auth.currentUser != null;
  }
}
