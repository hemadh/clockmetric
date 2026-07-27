import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'screens/accept_invitation_screen.dart';
import 'screens/dashboard_v2_screen.dart';
import 'screens/login_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/splash_screen.dart';
import 'services/session_timeout_service.dart';

final supabase = Supabase.instance.client;
Uri? startupDeepLink;

const String appVersion = '1.0.0';

String currentUserId = '';
String currentUserName = '';
String currentUserRole = '';
String currentWorkspaceId = '';
String currentWorkspaceName = '';

ValueNotifier<bool> isDarkMode = ValueNotifier(false);

Future<void> main(List<String> args) async {
  for (final argument in args) {
    final uri = Uri.tryParse(argument);

    if (uri != null && uri.scheme == 'timetracker') {
      startupDeepLink = uri;
      debugPrint('Startup argument deep link: $uri');
      break;
    }
  }

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
  url: 'https://zakvowocgunowgxxslqm.supabase.co',
  anonKey: 'sb_publishable_CPIzdsRFAy_8hPYucVkcTA_T-FJyGoA',
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.implicit,
  ),
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
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
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
            scaffoldBackgroundColor: const Color(0xFF0F172A),
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
  bool passwordRecoveryActive = false;

  StreamSubscription<AuthState>? authSubscription;
  late final AppLinks appLinks;
  StreamSubscription<Uri>? appLinksSubscription;

  @override
  void initState() {
    super.initState();

    appLinks = AppLinks();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
  try {
    Uri? initialUri;

    if (kIsWeb) {
      // Process Supabase invite/recovery authentication on Flutter Web.
      initialUri = Uri.base;
      debugPrint('Processing web authentication URL: $initialUri');
    } else {
      // Process desktop custom deep links such as timetracker://...
      initialUri = startupDeepLink ?? await appLinks.getInitialLink();
      startupDeepLink = null;

      if (initialUri != null && initialUri.scheme != 'timetracker') {
        initialUri = null;
      }
    }

    if (initialUri != null) {
      try {
        await supabase.auth.getSessionFromUrl(initialUri);
      } catch (error) {
        debugPrint('Session URL processing result: $error');
      }
    }

    if (!mounted) return;

    await checkSession();
  } catch (error) {
    debugPrint('Initial authentication link error: $error');
  }
});

    appLinksSubscription = appLinks.uriLinkStream.listen(
      (Uri uri) async {
        debugPrint('Incoming deep link: $uri');

        if (uri.scheme != 'timetracker') return;

        try {
          await supabase.auth.getSessionFromUrl(uri);

          if (!mounted) return;

          await checkSession();
        } catch (error) {
          debugPrint('Deep-link authentication error: $error');
        }
      },
      onError: (Object error) {
        debugPrint('Deep-link stream error: $error');
      },
    );

    HardwareKeyboard.instance.addHandler(
      _handleKeyboardActivity,
    );

    final currentUri = Uri.base;

    passwordRecoveryActive =
        currentUri.queryParameters['type'] == 'recovery' ||
        currentUri.fragment.contains('type=recovery');

    authSubscription = supabase.auth.onAuthStateChange.listen(
      (authData) async {
        final event = authData.event;

        if (event == AuthChangeEvent.passwordRecovery) {
          passwordRecoveryActive = true;

          if (mounted) {
            setState(() {
              loading = false;
              loggedIn = false;
            });
          }

          _openResetPasswordScreen();
          return;
        }

        if (event == AuthChangeEvent.initialSession ||
    event == AuthChangeEvent.signedIn ||
    event == AuthChangeEvent.tokenRefreshed ||
    event == AuthChangeEvent.userUpdated) {
          if (!passwordRecoveryActive) {
            await checkSession();
          }

          return;
        }

        if (event == AuthChangeEvent.signedOut) {
          passwordRecoveryActive = false;

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

    WidgetsBinding.instance.addPostFrameCallback(
      (_) async {
        if (!mounted) return;

        if (passwordRecoveryActive) {
          setState(() {
            loading = false;
            loggedIn = false;
          });

          _openResetPasswordScreen();
          return;
        }

        await checkSession();
      },
    );
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

        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const ResetPasswordScreen(),
          ),
        );

        resetScreenOpen = false;
        passwordRecoveryActive = false;

        if (!mounted) return;

        try {
          await supabase.auth.signOut();
        } catch (error) {
          debugPrint(
            'Password recovery sign-out error: $error',
          );
        }

        _clearCurrentUser();

        if (!mounted) return;

        setState(() {
          loggedIn = false;
          loading = false;
        });
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

        final completed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const AcceptInvitationScreen(),
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

    try {
      await supabase.auth.signOut();
    } catch (error) {
      debugPrint(
        'Session timeout sign-out error: $error',
      );
    }

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
    if (passwordRecoveryActive) {
      if (!mounted) return;

      setState(() {
        loggedIn = false;
        loading = false;
      });

      _openResetPasswordScreen();
      return;
    }

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

    if (mounted) {
      setState(() {
        loading = true;
      });
    }

    try {
      final email = user.email!.trim().toLowerCase();

      final metadata =
          user.userMetadata ?? <String, dynamic>{};

      final invitationCompleted =
          metadata['invitation_completed'] == true;

      final invitationWorkspaceId =
          metadata['workspace_id']?.toString().trim() ?? '';

      final hasWorkspaceInvitation =
          invitationWorkspaceId.isNotEmpty;

      final profile = await supabase
          .from('profiles')
          .select(
            'full_name, email, role, workspace_id, '
            'approval_status, is_active',
          )
          .eq('id', user.id)
          .maybeSingle();

      if (passwordRecoveryActive) {
        if (!mounted) return;

        setState(() {
          loggedIn = false;
          loading = false;
        });

        _openResetPasswordScreen();
        return;
      }

      if (profile == null &&
    hasWorkspaceInvitation &&
    !invitationCompleted) {
  SessionTimeoutService.instance.stop();
  _clearCurrentUser();

  if (!mounted) return;

  setState(() {
    loggedIn = false;
    loading = false;
  });

  _openInvitationScreen();
  return;
}

if (profile == null) {
  throw Exception(
    'No profile exists for this account.',
  );
}

      final profileRole =
          profile['role']?.toString().trim().toLowerCase() ?? '';

      final resolvedRole =
          profileRole.isNotEmpty ? profileRole : 'employee';

      /*
       * The invitation screen must only appear for employees.
       *
       * Admins with workspace metadata must always continue
       * through the normal account checks and dashboard flow.
       */
      final shouldOpenInvitation =
          resolvedRole == 'employee' &&
          hasWorkspaceInvitation &&
          !invitationCompleted;

      if (shouldOpenInvitation) {
        SessionTimeoutService.instance.stop();

        _clearCurrentUser();

        if (!mounted) return;

        setState(() {
          loggedIn = false;
          loading = false;
        });

        _openInvitationScreen();
        return;
      }

      final approvalStatus =
          profile['approval_status']
                  ?.toString()
                  .trim()
                  .toLowerCase() ??
              '';

      final isActive = profile['is_active'] == true;

      if (approvalStatus != 'approved' || !isActive) {
        try {
          await supabase.auth.signOut();
        } catch (error) {
          debugPrint(
            'Rejected account sign-out error: $error',
          );
        }

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

      currentUserRole = resolvedRole;

      currentWorkspaceId =
          profile['workspace_id']?.toString().trim() ?? '';

      if (currentWorkspaceId.isEmpty) {
        throw Exception(
          'User does not have a workspace.',
        );
      }

      final workspace = await supabase
          .from('workspaces')
          .select('workspace_name')
          .eq('id', currentWorkspaceId)
          .maybeSingle();

      if (workspace == null) {
        throw Exception(
          'The user workspace could not be found.',
        );
      }

      currentWorkspaceName =
          workspace['workspace_name']?.toString().trim() ?? '';

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

      if (passwordRecoveryActive) {
        if (!mounted) return;

        setState(() {
          loggedIn = false;
          loading = false;
        });

        _openResetPasswordScreen();
        return;
      }

      SessionTimeoutService.instance.stop();

      _clearCurrentUser();

      try {
        await supabase.auth.signOut();
      } catch (signOutError) {
        debugPrint(
          'Account load failure sign-out error: $signOutError',
        );
      }

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
    appLinksSubscription?.cancel();

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