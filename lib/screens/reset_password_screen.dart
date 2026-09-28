import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool saving = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  Future<void> updatePassword() async {
    if (saving) return;

    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage(
        'Please enter and confirm your new password.',
        isError: true,
      );
      return;
    }

    if (password.length < 8) {
      _showMessage(
        'Your password must contain at least 8 characters.',
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        'The passwords do not match.',
        isError: true,
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: password,
        ),
      );

      await supabase.auth.signOut();

      if (!mounted) return;

      _showMessage(
        'Your password was changed successfully. Please log in.',
      );

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      _showMessage(
        _friendlyError(error.message),
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Unable to change your password. Please request a new reset link.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  String _friendlyError(String message) {
    final value = message.toLowerCase();

    if (value.contains('same password')) {
      return 'Please choose a password different from your current password.';
    }

    if (value.contains('weak') ||
        value.contains('least') ||
        value.contains('characters')) {
      return 'Please choose a stronger password with at least 8 characters.';
    }

    if (value.contains('expired') ||
        value.contains('invalid') ||
        value.contains('session')) {
      return 'This reset link has expired. Please request another reset email.';
    }

    return 'Unable to change your password. Please try again.';
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? Colors.red : const Color(0xFF2E7D32),
        ),
      );
  }

  @override
  void dispose() {
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3FAF4),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 430,
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 72,
                  color: Color(0xFF7BC47F),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Create New Password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F4F2F),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Enter a new password for your Time Tracker account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: passwordController,
                  enabled: !saving,
                  obscureText: hidePassword,
                  textInputAction: TextInputAction.next,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                      icon: Icon(
                        hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  enabled: !saving,
                  obscureText: hideConfirmPassword,
                  textInputAction: TextInputAction.done,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          hideConfirmPassword =
                              !hideConfirmPassword;
                        });
                      },
                      icon: Icon(
                        hideConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onSubmitted: (_) {
                    updatePassword();
                  },
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: saving ? null : updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7BC47F),
                      foregroundColor: Colors.white,
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save New Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}