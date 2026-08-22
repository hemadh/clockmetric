import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import 'create_workspace_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController forgotEmailController =
      TextEditingController();

  bool isLoading = false;
  bool hidePassword = true;

  Future<void> login() async {
    if (isLoading) return;

    final email =
        emailController.text.trim().toLowerCase();

    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMessage(
        'Please enter your email and password.',
        isError: true,
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService().login(
        email: email,
        password: password,
      );

      // AuthGate in main.dart handles navigation.
    } on AuthException catch (error) {
      if (!mounted) return;

      _showMessage(
        _friendlyLoginError(error.message),
        isError: true,
      );
    } catch (error, stackTrace) {
  debugPrint('LOGIN ERROR: $error');
  debugPrintStack(stackTrace: stackTrace);

  if (!mounted) return;

  _showMessage(
    error.toString(),
    isError: true,
  );
} finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _friendlyLoginError(String message) {
    final value = message.toLowerCase();

    if (value.contains(
      'invalid login credentials',
    )) {
      return 'The email or password is incorrect.';
    }

    if (value.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }

    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    if (value.contains('too many requests') ||
        value.contains('rate limit')) {
      return 'Too many attempts. Please wait and try again.';
    }

    if (value.contains('account') &&
        value.contains('disabled')) {
      return 'This account has been disabled. Please contact an administrator.';
    }

    return 'Unable to log in. Please check your details and try again.';
  }

  Future<void> showForgotPasswordDialog() async {
    forgotEmailController.text =
        emailController.text.trim().toLowerCase();

    bool sending = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> sendResetEmail() async {
              if (sending) return;

              final email = forgotEmailController.text
                  .trim()
                  .toLowerCase();

              if (email.isEmpty) {
                _showMessage(
                  'Please enter your email address.',
                  isError: true,
                );
                return;
              }

              if (!_isValidEmail(email)) {
                _showMessage(
                  'Please enter a valid email address.',
                  isError: true,
                );
                return;
              }

              setDialogState(() {
                sending = true;
              });

              try {
                await supabase.auth.resetPasswordForEmail(
                  email,
                  redirectTo:
                      'timetracker://reset-password',
                );

                if (!mounted ||
                    !dialogContext.mounted) {
                  return;
                }

                Navigator.of(dialogContext).pop();

                forgotEmailController.clear();

                _showMessage(
                  'Password reset email sent. Please check your inbox.',
                );
              } on AuthException catch (error) {
                if (!mounted) return;

                _showMessage(
                  _friendlyResetError(
                    error.message,
                  ),
                  isError: true,
                );
              } catch (error) {
                debugPrint(
                  'Password reset error: $error',
                );

                if (!mounted) return;

                _showMessage(
                  'Unable to send the reset email. Please try again.',
                  isError: true,
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    sending = false;
                  });
                }
              }
            }

            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        AppColors.primaryLight,
                    child: Icon(
                      Icons.lock_reset_outlined,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Reset Password',
                      style: TextStyle(
                        color:
                            AppColors.textPrimary,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter your account email. We will send you a secure password-reset link.',
                      style: TextStyle(
                        color:
                            AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller:
                          forgotEmailController,
                      enabled: !sending,
                      autofocus: true,
                      keyboardType:
                          TextInputType.emailAddress,
                      textInputAction:
                          TextInputAction.done,
                      decoration: _inputDecoration(
                        label: 'Email Address',
                        icon:
                            Icons.email_outlined,
                      ),
                      onSubmitted: (_) {
                        sendResetEmail();
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending
                      ? null
                      : () {
                          forgotEmailController
                              .clear();

                          Navigator.of(
                            dialogContext,
                          ).pop();
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color:
                          AppColors.textSecondary,
                    ),
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        AppColors.primary,
                    foregroundColor:
                        Colors.white,
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                  ),
                  onPressed:
                      sending ? null : sendResetEmail,
                  icon: sending
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_outlined,
                        ),
                  label: Text(
                    sending
                        ? 'Sending...'
                        : 'Send Reset Email',
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _friendlyResetError(String message) {
    final value = message.toLowerCase();

    if (value.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (value.contains('too many requests') ||
        value.contains('rate limit')) {
      return 'Too many reset requests. Please wait before trying again.';
    }

    if (value.contains('network') ||
        value.contains('socket') ||
        value.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    return 'Unable to send the reset email. Please try again.';
  }

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
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
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    forgotEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wideScreen =
              constraints.maxWidth >= 950;

          if (wideScreen) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildBrandPanel(),
                ),
                Expanded(
                  flex: 4,
                  child: _buildLoginArea(),
                ),
              ],
            );
          }

          return _buildLoginArea(
            showCompactBranding: true,
          );
        },
      ),
    );
  }

  Widget _buildBrandPanel() {
    return Container(
      height: double.infinity,
      color: AppColors.primary,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 52,
                vertical: 36,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      constraints.maxHeight - 72,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 260,
                        height: 112,
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(
                            18,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color:
                                  Color(0x1A000000),
                              blurRadius: 18,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/clockmetric_logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 42),
                      const Text(
                        'Track time.\nImprove productivity.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          height: 1.15,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'A secure workspace for time tracking, employee management, screenshots and weekly reporting.',
                        style: TextStyle(
                          color: Colors.white
                              .withValues(
                            alpha: 0.86,
                          ),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 30),
                      _featureRow(
                        icon:
                            Icons.timer_outlined,
                        text:
                            'Simple project-based time tracking',
                      ),
                      const SizedBox(height: 14),
                      _featureRow(
                        icon: Icons
                            .photo_camera_outlined,
                        text:
                            'Private and protected screenshots',
                      ),
                      const SizedBox(height: 14),
                      _featureRow(
                        icon: Icons
                            .admin_panel_settings_outlined,
                        text:
                            'Secure employee and admin access',
                      ),
                      const Spacer(),
                      const SizedBox(height: 28),
                      Text(
                        'ClockMetric • Version $appVersion',
                        style: TextStyle(
                          color: Colors.white
                              .withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _featureRow({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(
              alpha: 0.15,
            ),
            borderRadius:
                BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
    Widget _buildLoginArea({
    bool showCompactBranding = false,
  }) {
    return Container(
      color: AppColors.background,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showCompactBranding) ...[
                  Container(
                    width: 250,
                    height: 105,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Image.asset(
                      'assets/images/clockmetric_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(34),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.border,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 29,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Sign in to continue to your workspace.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        decoration: _inputDecoration(
                          label: 'Email Address',
                          icon: Icons.email_outlined,
                        ),
                      ),
                      const SizedBox(height: 17),
                      TextField(
                        controller: passwordController,
                        enabled: !isLoading,
                        obscureText: hidePassword,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: _inputDecoration(
                          label: 'Password',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            tooltip: hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: isLoading
                                ? null
                                : () {
                                    setState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                            icon: Icon(
                              hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        onSubmitted: (_) {
                          login();
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: isLoading
                              ? null
                              : showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.border,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isLoading ? null : login,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            isLoading
                                ? 'Signing in...'
                                : 'Sign In',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.admin_panel_settings_outlined,
                              size: 34,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Need an account?',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Please contact your workspace administrator to receive an invitation email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                height: 1.45,
                              ),
                            ),
                            const SizedBox(height: 20),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const CreateWorkspaceScreen(),
        ),
      );
    },
    icon: const Icon(Icons.business),
    label: const Text('Create Workspace'),
  ),
),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Secure access powered by Supabase Authentication',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.6,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.border,
        ),
      ),
    );
  }
}