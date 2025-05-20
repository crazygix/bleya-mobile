import 'package:flutter/cupertino.dart';
import '../services/api_service.dart';

class AuthorisationPage extends StatefulWidget {
  @override
  AuthorisationPageState createState() => AuthorisationPageState();
}

class AuthorisationPageState extends State<AuthorisationPage> {
  final TextEditingController _phoneController = TextEditingController();
  final ApiService _apiService = ApiService();
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    try {
      setState(() => _errorMessage = null);
      await _apiService.requestCode(phone: _phoneController.text);
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
