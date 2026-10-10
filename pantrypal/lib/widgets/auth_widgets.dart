import 'package:flutter/material.dart';
import '../core/theme.dart';

const _avatarPurple = Color(0xFF4B3A8C);

/// Shared page layout for the Login and Sign Up screens:
/// brown "PantryPal" bar, avatar, big title, then the form [children].
class AuthScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const AuthScaffold({super.key, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.peach,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.brown,
            child: const SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AppLogo(),
                    SizedBox(width: 10),
                    Text(
                      'PantryPal',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.peach,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline,
                        size: 74,
                        color: _avatarPurple,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.brown,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The PantryPal logo shown next to the app name.
/// Put your logo at assets/images/logo.png. If the file is missing,
/// a simple icon is shown instead so the app never crashes.
class _AppLogo extends StatelessWidget {
  const _AppLogo();

  static const double size = 38;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.shopping_basket_outlined,
        size: size,
        color: AppColors.peach,
      ),
    );
  }
}

/// Rounded pill text field with centred hint text.
class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboard;
  final TextInputAction action;

  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboard,
    this.action = TextInputAction.next,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboard,
        textInputAction: action,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, color: AppColors.brown),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 16,
            color: AppColors.brown.withOpacity(0.5),
          ),
          filled: true,
          fillColor: AppColors.cream,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Full-width dark brown pill button.
class AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const AuthButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.brown,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.cream,
          ),
        ),
      ),
    );
  }
}

/// "Some text. Underlined orange link." line.
class AuthLink extends StatelessWidget {
  final String? prefix;
  final String link;
  final VoidCallback onTap;

  const AuthLink({
    super.key,
    this.prefix,
    required this.link,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        if (prefix != null)
          Text(
            prefix!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.brown.withOpacity(0.75),
            ),
          ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            link,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.navActive,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.navActive,
            ),
          ),
        ),
      ],
    );
  }
}\