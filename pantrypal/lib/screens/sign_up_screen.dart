import 'package:flutter/material.dart';
import '../core/session.dart';
import '../widgets/auth_widgets.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _register() {
    if (_username.text.trim().isEmpty ||
        _email.text.trim().isEmpty ||
        _password.text.isEmpty ||
        _confirm.text.isEmpty) {
      _snack('Please fill in every field');
      return;
    }
    if (!_email.text.contains('@') || !_email.text.contains('.')) {
      _snack('Enter a valid email address');
      return;
    }
    if (_password.text.length < 6) {
      _snack('Password must be at least 6 characters');
      return;
    }
    if (_password.text != _confirm.text) {
      _snack('Passwords do not match');
      return;
    }
    // TODO: create the account with your backend here.
    Session.username.value = _username.text.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'SIGN UP',
      children: [
        AuthField(controller: _username, hint: 'Username'),
        AuthField(
          controller: _email,
          hint: 'Email',
          keyboard: TextInputType.emailAddress,
        ),
        AuthField(controller: _password, hint: 'Password', obscure: true),
        AuthField(
          controller: _confirm,
          hint: 'Confirm Password',
          obscure: true,
          action: TextInputAction.done,
        ),
        const SizedBox(height: 4),
        AuthButton(label: 'Register', onTap: _register),
        const SizedBox(height: 22),
        AuthLink(
          prefix: 'Already have an account?',
          link: 'Log in here.',
          onTap: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          ),
        ),
      ],
    );
  }
}