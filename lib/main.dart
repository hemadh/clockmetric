import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/accept_invitation_screen.dart';
import 'screens/dashboard_v2_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'services/session_timeout_service.dart';
import 'screens/splash_screen.dart';

final supabase = Supabase.instance.client;

const String appVersion = '1.0.0';

String currentUserId = '';
String currentUserName = '';
String currentUserRole = '';
String currentWorkspaceId = '';
String currentWorkspaceName = '';

ValueNotifier<bool> isDarkMode = ValueNotifier(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://zakvowocgunowgxxslqm.supabase.co',
    anonKey:
        'sb_publishable_CPIzdsRFAy_8hPYucVkcTA_T-FJyGoA',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkMode,
      builder: (context, dark, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Time Tracker',
          themeMode:
              dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor:
                const Color(0xFFF8FAFC),
            primaryColor: const Color(0xFFF97316),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF97316),
              brightness: Brightness.light,
            ),
            fontFamily: 'Segoe UI',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            scaffoldBackgroundColor:
                const Color(0xFF0F172A),
            primaryColor: const Color(0xFFF97316),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFF97316),
              brightness: Brightness.dark,
            ),
            fontFamily: 'Segoe UI',
          ),
          home: const SplashScreen(
  nextScreen: AuthGate(),
),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  bool loggedIn = false;
  bool sessionExpired = false;
  bool resetScreenOpen = false;
  bool invitationScreenOpen = false;

  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();

    HardwareKeyboard.instance.addHandler(
      _handleKeyboardActivity,
    );

    authSubscription =
        supabase.auth.onAuthStateChange.listen(
      (authData) {
        final event = authData.event;

        if (event == AuthChangeEvent.passwordRecovery) {
          _openResetPasswordScreen();
          return;
        }

        final user = authData.session?.user;

        final metadata =
            user?.userMetadata ?? <String, dynamic>{};

        final invitationCompleted =
            metadata['invitation_completed'] == true;

        final hasWorkspaceInvitation =
            metadata['workspace_id'] != null;

        if (event == AuthChangeEvent.signedIn &&
            hasWorkspaceInvitation &&
            !invitationCompleted) {
          _openInvitationScreen();
          return;
        }

        if (event == AuthChangeEvent.signedIn ||
            event == AuthChangeEvent.tokenRefreshed ||
            event == AuthChangeEvent.userUpdated) {
          checkSession();
        }

        if (event == AuthChangeEvent.signedOut) {
          SessionTimeoutService.instance.stop();

          _clearCurrentUser();

          if (!mounted) return;

          setState(() {
            loggedIn = false;
            loading = false;
            resetScreenOpen = false;
            invitationScreenOpen = false;
          });
        }
      },
      onError: (
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint(
          'Authentication stream error: $error',
        );
      },
    );

    checkSession();
  }

  void _openResetPasswordScreen() {
    if (resetScreenOpen) return;

    resetScreenOpen = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) {
          resetScreenOpen = false;
          return;
        }

        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                const ResetPasswordScreen(),
          ),
        );

        resetScreenOpen = false;
      },
    );
  }

  void _openInvitationScreen() {
    if (invitationScreenOpen) return;

    invitationScreenOpen = true;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) {
          invitationScreenOpen = false;
          return;
        }

        final completed =
            await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) =>
                const AcceptInvitationScreen(),
          ),
        );

        invitationScreenOpen = false;

        if (completed == true && mounted) {
          try {
            await supabase.auth.refreshSession();
          } catch (error) {
            debugPrint(
              'Invitation session refresh error: $error',
            );
          }

          await checkSession();
        }
      },
    );
  }

  bool _handleKeyboardActivity(KeyEvent event) {
    if (loggedIn) {
      _resetSessionTimeout();
    }

    return false;
  }

  void _handlePointerActivity(
    PointerEvent event,
  ) {
    if (loggedIn) {
      _resetSessionTimeout();
    }
  }

  void _startSessionTimeout() {
    if (!loggedIn) return;

    SessionTimeoutService.instance.start(
      _handleSessionTimeout,
    );
  }

  void _resetSessionTimeout() {
    if (!loggedIn) return;

    SessionTimeoutService.instance.reset(
      _handleSessionTimeout,
    );
  }

  Future<void> _handleSessionTimeout() async {
    if (!loggedIn) return;

    SessionTimeoutService.instance.stop();

    sessionExpired = true;

    await supabase.auth.signOut();

    _clearCurrentUser();

    if (!mounted) return;

    setState(() {
      loggedIn = false;
      loading = false;
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (!mounted || !sessionExpired) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your session expired because of inactivity. '
              'Please log in again.',
            ),
            backgroundColor: Color(0xFFF97316),
            duration: Duration(seconds: 5),
          ),
        );

        sessionExpired = false;
      },
    );
  }

  void _clearCurrentUser() {
    currentUserId = '';
    currentUserName = '';
    currentUserRole = '';
    currentWorkspaceId = '';
    currentWorkspaceName = '';
  }

  Future<void> checkSession() async {
    final user = supabase.auth.currentUser;

    if (user == null || user.email == null) {
      SessionTimeoutService.instance.stop();

      _clearCurrentUser();

      if (!mounted) return;

      setState(() {
        loggedIn = false;
        loading = false;
      });

      return;
    }

    final metadata =
        user.userMetadata ?? <String, dynamic>{};

    final invitationCompleted =
        metadata['invitation_completed'] == true;

    final hasWorkspaceInvitation =
        metadata['workspace_id'] != null;

    if (hasWorkspaceInvitation &&
        !invitationCompleted) {
      if (!mounted) return;

      setState(() {
        loading = false;
        loggedIn = false;
      });

      _openInvitationScreen();

      return;
    }

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final email = user.email!.toLowerCase();

      final profile = await supabase
          .from('profiles')
          .select(
            'full_name, email, role, workspace_id, '
            'approval_status, is_active',
          )
          .eq('id', user.id)
          .single();

      final approvalStatus = profile['approval_status']
              ?.toString()
              .toLowerCase() ??
          '';

      final isActive =
          profile['is_active'] == true;

      if (approvalStatus != 'approved' ||
          !isActive) {
        await supabase.auth.signOut();

        _clearCurrentUser();

        if (!mounted) return;

        setState(() {
          loggedIn = false;
          loading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  !isActive
                      ? 'Your account has been disabled. '
                          'Please contact an administrator.'
                      : 'Your account has not been approved '
                          'by an administrator.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          },
        );

        return;
      }

      currentUserId = user.id;

      final profileName =
          profile['full_name']?.toString().trim();

      currentUserName =
          profileName != null && profileName.isNotEmpty
              ? profileName
              : email;

      final profileRole =
          profile['role']?.toString().trim();

      currentUserRole =
          profileRole != null && profileRole.isNotEmpty
              ? profileRole
              : 'employee';

      currentWorkspaceId =
          profile['workspace_id']?.toString() ?? '';

      if (currentWorkspaceId.isEmpty) {
        throw Exception(
          'User does not have a workspace.',
        );
      }

      final workspace = await supabase
          .from('workspaces')
          .select('workspace_name')
          .eq('id', currentWorkspaceId)
          .single();

      currentWorkspaceName =
          workspace['workspace_name']?.toString() ??
              '';

      if (!mounted) return;

      setState(() {
        loggedIn = true;
        loading = false;
      });

      _startSessionTimeout();
    } catch (error) {
      debugPrint(
        'Unable to load account: $error',
      );

      SessionTimeoutService.instance.stop();

      _clearCurrentUser();

      await supabase.auth.signOut();

      if (!mounted) return;

      setState(() {
        loggedIn = false;
        loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to load your account. '
                'Please log in again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        },
      );
    }
  }

  @override
  void dispose() {
    SessionTimeoutService.instance.stop();

    authSubscription?.cancel();

    HardwareKeyboard.instance.removeHandler(
      _handleKeyboardActivity,
    );

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget screen;

    if (loading) {
      screen = const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFFF97316),
          ),
        ),
      );
    } else if (loggedIn) {
      screen = const DashboardV2Screen();
    } else {
      screen = const LoginScreen();
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerActivity,
      onPointerMove: _handlePointerActivity,
      onPointerSignal: _handlePointerActivity,
      child: MouseRegion(
        onHover: (_) {
          if (loggedIn) {
            _resetSessionTimeout();
          }
        },
        child: screen,
      ),
    );
  }
}