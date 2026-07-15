import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme/app_colors.dart';

class CreateWorkspaceScreen extends StatefulWidget {
  const CreateWorkspaceScreen({super.key});

  @override
  State<CreateWorkspaceScreen> createState() =>
      _CreateWorkspaceScreenState();
}

class _CreateWorkspaceScreenState
    extends State<CreateWorkspaceScreen> {
  final workspaceController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  void dispose() {
    workspaceController.dispose();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> createWorkspace() async {
    if (loading) return;

    final workspaceName =
        workspaceController.text.trim();

    final fullName =
        nameController.text.trim();

    final email =
        emailController.text.trim().toLowerCase();

    final password =
        passwordController.text;

    final confirmPassword =
        confirmPasswordController.text;

    if (workspaceName.isEmpty ||
        fullName.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      showMessage(
        'Please complete all fields.',
        isError: true,
      );
      return;
    }

    if (!isValidEmail(email)) {
      showMessage(
        'Please enter a valid email address.',
        isError: true,
      );
      return;
    }

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

    setState(() {
      loading = true;
    });

    try {
      final response = await supabase.functions.invoke(
        'create-workspace-owner',
        body: {
          'workspace_name': workspaceName,
          'full_name': fullName,
          'email': email,
          'password': password,
        },
      );

      final data = response.data;

      if (data is Map && data['error'] != null) {
        throw Exception(
          data['error'].toString(),
        );
      }

      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.of(context).pop();
    } on AuthException catch (error) {
      showMessage(
        error.message,
        isError: true,
      );
    } catch (error) {
      debugPrint(
        'Create workspace error: $error',
      );

      showMessage(
        cleanError(error),
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

  bool isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  String cleanError(Object error) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring(
        'Exception: '.length,
      );
    }

    return value;
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
          backgroundColor: isError
              ? AppColors.danger
              : AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: AppColors.primary,
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surface,
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
          width: 1.7,
        ),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Create Workspace',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius:
                    BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.border,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Start with FloraTime',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create your company workspace. You will automatically become its administrator.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller:
                        workspaceController,
                    enabled: !loading,
                    textInputAction:
                        TextInputAction.next,
                    decoration: inputDecoration(
                      label:
                          'Company or Workspace Name',
                      icon:
                          Icons.business_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    enabled: !loading,
                    textInputAction:
                        TextInputAction.next,
                    decoration: inputDecoration(
                      label: 'Your Full Name',
                      icon:
                          Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    enabled: !loading,
                    keyboardType:
                        TextInputType.emailAddress,
                    textInputAction:
                        TextInputAction.next,
                    autocorrect: false,
                    decoration: inputDecoration(
                      label: 'Email Address',
                      icon:
                          Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        passwordController,
                    enabled: !loading,
                    obscureText: hidePassword,
                    textInputAction:
                        TextInputAction.next,
                    decoration: inputDecoration(
                      label: 'Password',
                      icon:
                          Icons.lock_outline,
                      suffixIcon: IconButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  hidePassword =
                                      !hidePassword;
                                });
                              },
                        icon: Icon(
                          hidePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller:
                        confirmPasswordController,
                    enabled: !loading,
                    obscureText:
                        hideConfirmPassword,
                    textInputAction:
                        TextInputAction.done,
                    onSubmitted: (_) {
                      createWorkspace();
                    },
                    decoration: inputDecoration(
                      label: 'Confirm Password',
                      icon:
                          Icons.lock_reset_outlined,
                      suffixIcon: IconButton(
                        onPressed: loading
                            ? null
                            : () {
                                setState(() {
                                  hideConfirmPassword =
                                      !hideConfirmPassword;
                                });
                              },
                        icon: Icon(
                          hideConfirmPassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      style:
                          FilledButton.styleFrom(
                        backgroundColor:
                            AppColors.primary,
                        foregroundColor:
                            Colors.white,
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            14,
                          ),
                        ),
                      ),
                      onPressed: loading
                          ? null
                          : createWorkspace,
                      icon: loading
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .rocket_launch_outlined,
                            ),
                      label: Text(
                        loading
                            ? 'Creating workspace...'
                            : 'Create Workspace',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'By creating a workspace, you become its owner and administrator.',
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
      ),
    );
  }
}