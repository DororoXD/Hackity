import 'package:flutter/material.dart';
import '../core/session.dart';
import '../widgets/auth_widgets.dart';
import 'home_shell.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _login() {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Enter your username and password');
      return;
    }
    // TODO: check the username and password with your backend here.
    Session.username.value = _username.text.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'LOGIN',
      children: [
        AuthField(controller: _username, hint: 'Username'),
        AuthField(
          controller: _password,
          hint: 'Password',
          obscure: true,
          action: TextInputAction.done,
        ),
        const SizedBox(height: 4),
        AuthButton(label: 'Login', onTap: _login),
        const SizedBox(height: 22),
        AuthLink(
          prefix: 'Don’t have an account yet?',
          link: 'Create it here.',
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SignUpScreen()),
          ),
        ),
        const SizedBox(height: 16),
        AuthLink(
          link: 'Forgot password?',
          onTap: () => _snack('Password reset is coming soon'),
        ),
      ],
    );
  }
}