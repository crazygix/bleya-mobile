import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';

class VerificationCodePage extends ConsumerStatefulWidget {
  @override
  VerificationCodePageState createState() => VerificationCodePageState();
}

class VerificationCodePageState extends ConsumerState<VerificationCodePage> {
  final TextEditingController _codeController = TextEditingController();
  String? _errorMessage;
  late String _phoneNumber;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _phoneNumber = ModalRoute.of(context)!.settings.arguments as String;
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter the verification code');
      return;
    }

    try {
      setState(() => _errorMessage = null);
      final authService = ref.read(authServiceProvider);
      await authService.verifyCode(
        phone: _phoneNumber,
        code: _codeController.text,
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Verify Code'),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Enter the verification code sent to $_phoneNumber',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: CupertinoTextField(
                controller: _codeController,
                placeholder: 'Enter verification code',
                keyboardType: TextInputType.number,
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
            CupertinoButton.filled(
              onPressed: _verifyCode,
              child: Text('Verify'),
            ),
            SizedBox(height: 12),
            CupertinoButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Change Phone Number'),
            ),
          ],
        ),
      ),
    );
  }
}
