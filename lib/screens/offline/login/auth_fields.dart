// Shared field chrome for the login, register and forgot-password screens.

import 'package:flutter/material.dart';

/// Filled, borderless rounded text-field decoration used by the auth screens.
InputDecoration authFieldDecoration({
  required String hint,
  required Color fillColor,
  required Color textSecondary,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.6)),
    filled: true,
    fillColor: fillColor,
    suffixIcon: suffixIcon,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

/// Bold label shown above an auth text field.
class AuthFieldLabel extends StatelessWidget {
  /// Label text.
  final String text;

  /// Text color.
  final Color color;

  /// Creates a [AuthFieldLabel].
  const AuthFieldLabel({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color),
    );
  }
}
