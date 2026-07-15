import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class AcceptInvitationScreen extends StatefulWidget {
  const AcceptInvitationScreen({super.key});

  @override
  State<AcceptInvitationScreen> createState() =>
      _AcceptInvitationScreenState();
}

class _AcceptInvitationScreenState
    extends State<AcceptInvitationScreen> {
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;
  bool acceptedTerms = false;

  String get invitedEmail {
    return supabase.auth.currentUser?.email ?? '';
  }

  String get invitedName {
    final metadata =
        supabase.auth.currentUser?.userMetadata ?? {};

    final name =
        metadata['full_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'New Employee' : name;
  }

  String get workspaceName {
    final metadata =
        supabase.auth.currentUser?.userMetadata ?? {};

    final name =
        metadata['workspace_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'your workspace' : name;
  }

  Future<void> completeInvitation() async {
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (password.length < 8) {
      showMessage(
        'Password must contain at least 8 characters.',
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      showMessage(
        'Passwords do not match.',
        isError: true,
      );
      return;
    }

    if (!acceptedTerms) {
      showMessage(
        'Please accept the Terms and Privacy Policy.',
        isError: true,
      );
      return;
    }

    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(
          password: password,
        ),
      );

      final response = await supabase.functions.invoke(
        'complete-workspace-invitation',
      );

      final data = response.data;

      if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      }

      if (!mounted) return;

      showMessage(
        'Your account has been created successfully.',
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint(
        'Complete invitation error: $error',
      );

      showMessage(
        'Unable to complete your invitation. Please request a new invitation.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(
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
              isError ? AppColors.danger : AppColors.success,
          behavior: SnackBarBehavior.floating,
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
    return PopScope(
      canPop: !loading,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'Accept Invitation',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Container(
              width: 560,
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 28,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Welcome, $invitedName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You have been invited to join $workspaceName.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.primaryLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            invitedEmail,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: passwordController,
                    obscureText: obscurePassword,
                    enabled: !loading,
                    decoration: InputDecoration(
                      labelText: 'Create Password',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: AppColors.primary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Use at least 8 characters.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirmPassword,
                    enabled: !loading,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      completeInvitation();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(
                        Icons.lock_reset_outlined,
                        color: AppColors.primary,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscureConfirmPassword =
                                !obscureConfirmPassword;
                          });
                        },
                        icon: Icon(
                          obscureConfirmPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: acceptedTerms,
                    activeColor: AppColors.primary,
                    controlAffinity:
                        ListTileControlAffinity.leading,
                    title: const Text(
                      'I accept the Terms of Service and Privacy Policy.',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    onChanged: loading
                        ? null
                        : (value) {
                            setState(() {
                              acceptedTerms = value ?? false;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed:
                          loading ? null : completeInvitation,
                      icon: loading
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline,
                            ),
                      label: Text(
                        loading
                            ? 'Creating Account...'
                            : 'Create Account',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}