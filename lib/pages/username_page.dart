import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_providers.dart';
import '../utils/app_errors.dart';

class UsernamePage extends ConsumerStatefulWidget {
  const UsernamePage({super.key});

  @override
  UsernamePageState createState() => UsernamePageState();
}

class UsernamePageState extends ConsumerState<UsernamePage> {
  final TextEditingController _usernameController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  bool _validateUsername(String username) {
    // Client-side validation: 3-30 characters, lowercase letters, numbers, and underscores only
    if (username.length < 3 || username.length > 30) {
      return false;
    }
    return RegExp(r'^[a-z0-9_]+$').hasMatch(username);
  }

  Future<void> _setUsername() async {
    final username = _usernameController.text.trim().toLowerCase();

    if (username.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username');
      return;
    }

    if (!_validateUsername(username)) {
      setState(() => _errorMessage =
          'Username must be 3-30 characters and contain only lowercase letters, numbers, and underscores');
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });

      final authService = ref.read(authServiceProvider);
      await authService.setUsername(username: username);

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        if (e is AppError) {
          setState(() => _errorMessage = e.getUserMessage());
        } else {
          setState(() => _errorMessage =
              'An unexpected error occurred. Please try again.');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () async {
            // Logout and go back to initial/auth page
            final authManager = ref.read(authManagerProvider);
            await authManager.logout();
          },
          child: Icon(CupertinoIcons.arrow_left),
        ),
        middle: Text('Choose Username'),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Please choose a username to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: CupertinoColors.systemGrey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: CupertinoTextField(
                  controller: _usernameController,
                  placeholder: 'Enter username',
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  enabled: !_isLoading,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                '3-30 characters, lowercase letters, numbers, and underscores only',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.secondaryLabel,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: CupertinoColors.systemRed),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: _isLoading ? null : _setUsername,
              child: _isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CupertinoActivityIndicator(),
                    )
                  : Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
