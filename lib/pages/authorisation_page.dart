import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class AuthorisationPage extends ConsumerStatefulWidget {
  @override
  AuthorisationPageState createState() => AuthorisationPageState();
}

class AuthorisationPageState extends ConsumerState<AuthorisationPage> {
  final TextEditingController _phoneController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    try {
      setState(() => _errorMessage = null);
      final authService = ref.read(authServiceProvider);
      await authService.requestCode(phone: _phoneController.text);

      if (mounted) {
        Navigator.of(context).pushNamed(
          '/verification_code',
          arguments: _phoneController.text,
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Authorisation'),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: CupertinoTextField(
                controller: _phoneController,
                placeholder: 'Enter your phone number',
                keyboardType: TextInputType.phone,
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            SizedBox(height: 20),
            CupertinoButton(
              onPressed: _requestCode,
              child: Text('Request Code'),
            ),
          ],
        ),
      ),
    );
  }
}
