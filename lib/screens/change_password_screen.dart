import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState
    extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _currentPasswordController =
      TextEditingController();

  final TextEditingController _newPasswordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final user = supabase.auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      _showMessage(
        'Your login session is no longer valid. Please log in again.',
        isError: true,
      );
      return;
    }

    final currentPassword =
        _currentPasswordController.text.trim();

    final newPassword =
        _newPasswordController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      // Verify that the current password is correct.
      await supabase.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );

      // Update the account with the new password.
      await supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );

      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      _showMessage(
        'Password changed successfully.',
        isError: false,
      );
    } on AuthException catch (error) {
      if (!mounted) return;

      String message = error.message;

      final lowercaseMessage = message.toLowerCase();

      if (lowercaseMessage.contains('invalid login') ||
          lowercaseMessage.contains('invalid credentials')) {
        message = 'Your current password is incorrect.';
      } else if (lowercaseMessage.contains('same password')) {
        message =
            'Your new password must be different from your current password.';
      } else if (lowercaseMessage.contains('weak password')) {
        message =
            'Your new password is too weak. Please use a stronger password.';
      }

      _showMessage(
        message,
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        'Unable to change your password. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
  automaticallyImplyLeading: false,
  backgroundColor: const Color(0xFFF97316),
  foregroundColor: Colors.white,
  centerTitle: true,
  elevation: 0,
  title: const Text(
    'Change Password',
    style: TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  ),
),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: Card(
              elevation: 0,
              color: isDark
                  ? const Color(0xFF1E293B)
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
                side: BorderSide(
                  color: isDark
                      ? Colors.white12
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.lock_reset_rounded,
                        size: 64,
                        color: Color(0xFFF97316),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Update your password',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your current password and choose a strong new password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 30),

                      TextFormField(
                        controller:
                            _currentPasswordController,
                        obscureText:
                            _hideCurrentPassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          prefixIcon:
                              const Icon(Icons.lock_outline),
                          border:
                              const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hideCurrentPassword =
                                    !_hideCurrentPassword;
                              });
                            },
                            icon: Icon(
                              _hideCurrentPassword
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Enter your current password.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller:
                            _newPasswordController,
                        obscureText: _hideNewPassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon:
                              const Icon(Icons.key_rounded),
                          border:
                              const OutlineInputBorder(),
                          helperText:
                              'Use at least 8 characters.',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hideNewPassword =
                                    !_hideNewPassword;
                              });
                            },
                            icon: Icon(
                              _hideNewPassword
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password =
                              value?.trim() ?? '';

                          if (password.isEmpty) {
                            return 'Enter a new password.';
                          }

                          if (password.length < 8) {
                            return 'Password must contain at least 8 characters.';
                          }

                          if (password ==
                              _currentPasswordController
                                  .text
                                  .trim()) {
                            return 'The new password must be different.';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(height: 18),

                      TextFormField(
                        controller:
                            _confirmPasswordController,
                        obscureText:
                            _hideConfirmPassword,
                        enabled: !_isLoading,
                        decoration: InputDecoration(
                          labelText:
                              'Confirm new password',
                          prefixIcon: const Icon(
                            Icons.verified_user_outlined,
                          ),
                          border:
                              const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() {
                                _hideConfirmPassword =
                                    !_hideConfirmPassword;
                              });
                            },
                            icon: Icon(
                              _hideConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons
                                      .visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return 'Confirm your new password.';
                          }

                          if (value.trim() !=
                              _newPasswordController
                                  .text
                                  .trim()) {
                            return 'The passwords do not match.';
                          }

                          return null;
                        },
                        onFieldSubmitted: (_) {
                          if (!_isLoading) {
                            _changePassword();
                          }
                        },
                      ),

                      const SizedBox(height: 28),

                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _changePassword,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                const Color(0xFFF97316),
                            foregroundColor:
                                Colors.white,
                          ),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 21,
                                  height: 21,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.save_outlined,
                                ),
                          label: Text(
                            _isLoading
                                ? 'Changing password...'
                                : 'Change Password',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}