import 'dart:async';

import 'dart:convert';

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

import 'services/update_service.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'screens/master_admin/master_admin_dashboard.dart';

final supabase = Supabase.instance.client;

Uri? startupDeepLink;

const String appVersion = '1.0.7';

String currentUserId = '';

String currentUserName = '';

String currentUserRole = '';

String currentWorkspaceId = '';

bool workspaceTrialExpired = false;

bool workspaceSubscriptionBlocked = false;

String currentWorkspaceName = '';

final ValueNotifier<String> currentWorkspaceNameNotifier =

    ValueNotifier<String>('');

ValueNotifier<bool> isDarkMode = ValueNotifier(false);

// Web is available for every approved/active ClockMetric role.

// Automatic screenshots and keyboard/activity monitoring remain desktop-only.

bool get desktopTrackingAvailable => !kIsWeb;

bool get clockMetricWeb => kIsWeb;

class _UpdateDownloadDialog extends StatefulWidget {

  final AppUpdateInfo update;

  final UpdateService updateService;

  const _UpdateDownloadDialog({

    required this.update,

    required this.updateService,

  });

  @override

  State<_UpdateDownloadDialog> createState() =>

      _UpdateDownloadDialogState();

}

class _UpdateDownloadDialogState

    extends State<_UpdateDownloadDialog> {

  double progress = 0;

  String? errorMessage;

  bool downloading = true;

  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      _startDownload();

    });

  }

  Future<void> _startDownload() async {

    if (!mounted) return;

    setState(() {

      downloading = true;

      progress = 0;

      errorMessage = null;

    });

    try {

      await widget.updateService.downloadAndInstallUpdate(

        widget.update,

        onProgress: (value) {

          if (!mounted) return;

          setState(() {

            progress = value;

          });

        },

      );

    } catch (error) {

      if (!mounted) return;

      setState(() {

        downloading = false;

        errorMessage = error.toString();

      });

    }

  }

  @override

  Widget build(BuildContext context) {

    return PopScope(

      canPop: !downloading,

      child: AlertDialog(

        title: Text(

          downloading

              ? 'Downloading Update'

              : 'Update Failed',

        ),

        content: errorMessage != null

            ? Text(errorMessage!)

            : Column(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  LinearProgressIndicator(

                    value: progress > 0 ? progress : null,

                  ),

                  const SizedBox(height: 16),

                  Text(

                    progress > 0

                        ? '${(progress * 100).toStringAsFixed(0)}%'

                        : 'Preparing download...',

                  ),

                  const SizedBox(height: 8),

                  const Text(

                    'ClockMetric will close and launch the installer when the download finishes.',

                  ),

                ],

              ),

        actions: [

          if (!downloading)

            TextButton(

              onPressed: () {

                Navigator.of(context).pop();

              },

              child: const Text('Close'),

            ),

          if (!downloading)

            ElevatedButton(

              onPressed: _startDownload,

              child: const Text('Retry'),

            ),

        ],

      ),

    );

  }

} 

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // ============================================================
  // CLOCKMETRIC DESKTOP DEEP LINK
  // ============================================================
  for (final argument in args) {
    final uri = Uri.tryParse(argument);

    if (uri != null && uri.scheme == 'timetracker') {
      startupDeepLink = uri;
      debugPrint('Startup argument deep link: $uri');
      break;
    }
  }

  // ============================================================
  // REPAIR A CORRUPTED SAVED SUPABASE SESSION BEFORE
  // Supabase.initialize() TRIES TO RESTORE IT.
  // ============================================================
  const String supabaseUrl =
      'https://kuvociuqxvgumcdbmupc.supabase.co';
  const String supabasePublishableKey =
      'sb_publishable_4Cin-x54MAazQpc67UUwqQ_rO4eK2gw';
  const String sessionKey =
      'sb-kuvociuqxvgumcdbmupc-auth-token';

  try {
    final prefs = await SharedPreferences.getInstance();
    final savedSession = prefs.getString(sessionKey);

    if (savedSession != null && savedSession.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedSession);

        if (decoded is! Map) {
          debugPrint(
            'ClockMetric: Invalid saved Supabase session structure detected. '
            'Removing only the local login session.',
          );
          await prefs.remove(sessionKey);
        }
      } on FormatException catch (error) {
        debugPrint(
          'ClockMetric: Corrupted saved Supabase session detected: $error',
        );
        await prefs.remove(sessionKey);
        debugPrint(
          'ClockMetric: Corrupted local session removed. '
          'The user will need to log in once.',
        );
      } catch (error) {
        debugPrint(
          'ClockMetric: Saved session validation failed: $error',
        );
        await prefs.remove(sessionKey);
      }
    }
  } catch (error) {
    debugPrint(
      'ClockMetric: Could not inspect local Supabase session: $error',
    );
  }

  // ============================================================
  // SUPABASE INITIALIZATION
  // ============================================================
  try {
    debugPrint('ClockMetric: Initializing Supabase...');

    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
    );

    debugPrint('ClockMetric: Supabase initialized successfully.');
  } catch (error, stackTrace) {
    debugPrint('ClockMetric Supabase initialization error: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }

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

          title: 'Clock Metric',

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

  bool invitationLinkActive = false;

  StreamSubscription<AuthState>? authSubscription;

  late final AppLinks appLinks;

  StreamSubscription<Uri>? appLinksSubscription;

  final UpdateService _updateService = UpdateService();

  bool _checkingForUpdate = false;

  static const String _lastOpenedKey =

    'clockmetric_last_opened_at';

static const Duration _maxNotOpenedDuration =

    Duration(days: 30);

  Map<String, String> _authParametersFromUri(Uri uri) {

    final parameters = <String, String>{};

    parameters.addAll(uri.queryParameters);

    final fragment = uri.fragment.trim();

    if (fragment.isNotEmpty) {

      try {

        final cleanFragment =

            fragment.startsWith('?')

                ? fragment.substring(1)

                : fragment;

        parameters.addAll(

          Uri.splitQueryString(cleanFragment),

        );

      } catch (error) {

        debugPrint(

          'Unable to parse authentication fragment: $error',

        );

      }

    }

    return parameters;

  }

  bool _isInvitationUri(Uri uri) {

    final parameters =

        _authParametersFromUri(uri);

    final type =

        parameters['type']

                ?.trim()

                .toLowerCase() ??

            '';

    final routeText =

        '${uri.host}${uri.path}'

            .toLowerCase();

    return type == 'invite' ||

        type == 'signup' ||

        routeText.contains('invite');

  }

  Future<void> _processAuthenticationUri(

    Uri uri,

  ) async {

    if (_isInvitationUri(uri)) {

      invitationLinkActive = true;

    }

    try {

      await supabase.auth.getSessionFromUrl(

        uri,

      );

      if (supabase.auth.currentUser != null) {

        debugPrint(

          'Authentication link session restored.',

        );

        return;

      }

    } catch (error) {

      debugPrint(

        'Session URL processing result: $error',

      );

    }

    final parameters =

        _authParametersFromUri(uri);

    final refreshToken =

        parameters['refresh_token']

                ?.trim() ??

            '';

    if (refreshToken.isEmpty) {

      return;

    }

    try {

      await supabase.auth.setSession(

        refreshToken,

      );

      debugPrint(

        'Authentication session restored '

        'from refresh token.',

      );

    } catch (error) {

      debugPrint(

        'Refresh-token session restore '

        'failed: $error',

      );

    }

  }

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

      await _processAuthenticationUri(

        initialUri,

      );

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

          await _processAuthenticationUri(

            uri,

          );

          if (!mounted) return;

          await checkSession();

        } catch (error) {

          debugPrint(

            'Deep-link authentication error: $error',

          );

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

            invitationLinkActive = false;

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

          invitationLinkActive = false;

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

  // Inactivity logout is disabled.

}

void _resetSessionTimeout() {

  // Inactivity logout is disabled.

}

Future<void> _handleSessionTimeout() async {

  // Automatic inactivity logout is disabled.

  SessionTimeoutService.instance.stop();

  return;

}

Future<bool> _checkThirtyDayLoginRule() async {

  // This rule is for the installed desktop app.

  if (kIsWeb) {

    return true;

  }

  final prefs = await SharedPreferences.getInstance();

  final now = DateTime.now();

  final lastOpenedText = prefs.getString(_lastOpenedKey);

  final currentSessionUser = supabase.auth.currentUser;

  if (lastOpenedText != null) {

    final lastOpened = DateTime.tryParse(lastOpenedText);

    if (lastOpened != null &&

        currentSessionUser != null &&

        now.difference(lastOpened) >= _maxNotOpenedDuration) {

      // ClockMetric has not been opened for 30 days.

      await prefs.setString(

        _lastOpenedKey,

        now.toIso8601String(),

      );

      await supabase.auth.signOut();

      return false;

    }

  }

  // Opening ClockMetric resets the 30-day period.

  await prefs.setString(

    _lastOpenedKey,

    now.toIso8601String(),

  );

  return true;

}

  void _clearCurrentUser() {

  currentUserId = '';

  currentUserName = '';

  currentUserRole = '';

  currentWorkspaceId = '';

  currentWorkspaceName = '';

  currentWorkspaceNameNotifier.value = '';

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

    if (invitationLinkActive) {

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

    final sessionStillValid =

    await _checkThirtyDayLoginRule();

if (!sessionStillValid) {

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

      final metadata = user.userMetadata ?? <String, dynamic>{};

      final invitationCompleted =

          metadata['invitation_completed'] == true;

      final invitationWorkspaceId =

          metadata['workspace_id']?.toString().trim() ?? '';

      final metadataRole =

          metadata['role']?.toString().trim().toLowerCase() ?? '';

      final hasWorkspaceInvitation =

          invitationWorkspaceId.isNotEmpty &&

          metadataRole == 'employee' &&

          !invitationCompleted;

      /*

       * IMPORTANT:

       * An invited employee may not have a row in public.profiles yet.

       * Also, RLS may prevent reading profiles before the invitation is

       * completed. Therefore, route invited employees to the acceptance

       * screen BEFORE querying the profiles table.

       */

      if (hasWorkspaceInvitation) {

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

      if (profile == null) {

        throw Exception(

          'No profile exists for this account.',

        );

      }

      final profileRole =

          profile['role']?.toString().trim().toLowerCase() ?? '';

      final resolvedRole =

          profileRole.isNotEmpty ? profileRole : 'employee';

      // ======================================================

      // WEB ACCESS

      // Employee, admin and master_admin can all use ClockMetric Web.

      // Screenshot capture and keyboard/activity tracking should remain

      // desktop-only and be guarded in the relevant tracking services/screens

      // with `desktopTrackingAvailable`.

      // ======================================================

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

      // Master Admin manages the whole ClockMetric platform and does not

      // belong to a single workspace.

      if (resolvedRole == 'master_admin') {

        currentWorkspaceId = '';

        currentWorkspaceName = '';

        currentWorkspaceNameNotifier.value = '';

        workspaceTrialExpired = false;

        workspaceSubscriptionBlocked = false;

        if (!mounted) return;

        setState(() {

          loggedIn = true;

          loading = false;

        });

        _startSessionTimeout();

        // Do not run the Windows app updater on web.

        if (!kIsWeb) {

          _checkForAppUpdate();

        }

        return;

      }

      currentWorkspaceId =

          profile['workspace_id']?.toString().trim() ?? '';

      if (currentWorkspaceId.isEmpty) {

        throw Exception(

          'User does not have a workspace.',

        );

      }

      final workspace = await supabase

          .from('workspaces')

          .select(

  'workspace_name, subscription_status, trial_ends_at, '

  'current_period_end, is_active',

)

          .eq('id', currentWorkspaceId)

          .maybeSingle();

      if (workspace == null) {

        throw Exception(

          'The user workspace could not be found.',

        );

      }

      final workspaceIsActive =

    workspace['is_active'] != false;

if (!workspaceIsActive) {

  try {

    await supabase.auth.signOut();

  } catch (error) {

    debugPrint(

      'Disabled workspace sign-out error: $error',

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

        const SnackBar(

          content: Text(

            'This workspace has been disabled. '

            'Please contact ClockMetric support.',

          ),

          backgroundColor: Colors.red,

        ),

      );

    },

  );

  return;

}

      final workspaceStatus =

    workspace['subscription_status']

        ?.toString()

        .trim()

        .toLowerCase() ??

    '';

final trialEndText =

    workspace['trial_ends_at']?.toString();

final trialEnd =

    trialEndText == null

        ? null

        : DateTime.tryParse(trialEndText);

workspaceTrialExpired =

    workspaceStatus == 'trialing' &&

    trialEnd != null &&

    DateTime.now().isAfter(trialEnd);

    final currentPeriodEndText =

    workspace['current_period_end']?.toString();

final currentPeriodEnd =

    currentPeriodEndText == null

        ? null

        : DateTime.tryParse(currentPeriodEndText);

workspaceSubscriptionBlocked =

    workspaceTrialExpired ||

    (workspaceStatus == 'cancelled' &&

        currentPeriodEnd != null &&

        DateTime.now().isAfter(currentPeriodEnd));

      currentWorkspaceName =

    workspace['workspace_name']?.toString().trim() ?? '';

currentWorkspaceNameNotifier.value = currentWorkspaceName;

if (!mounted) return;

setState(() {

  loggedIn = true;

  loading = false;

});

_startSessionTimeout();

// Do not run the Windows app updater on web.

if (!kIsWeb) {

  _checkForAppUpdate();

}

    } catch (error) {

      debugPrint(

        'Unable to load account temporarily: $error',

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

      // Keep the authenticated session during temporary network,

      // profile, workspace, or token-refresh errors.

      final stillAuthenticated =

          supabase.auth.currentUser != null;

      if (!mounted) return;

      setState(() {

        loggedIn = stillAuthenticated;

        loading = false;

      });

      if (stillAuthenticated) {

        WidgetsBinding.instance.addPostFrameCallback(

          (_) {

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(

              const SnackBar(

                content: Text(

                  'Connection issue detected. '

                  'Your login session has been kept active.',

                ),

                backgroundColor: Color(0xFFF97316),

              ),

            );

          },

        );

      }

    }

  }

  Future<void> _checkForAppUpdate() async {

  if (_checkingForUpdate || !mounted) {

    return;

  }

  _checkingForUpdate = true;

  try {

    final update = await _updateService.checkForUpdate();

    if (!mounted || update == null) {

      return;

    }

    await showDialog<void>(

      context: context,

      barrierDismissible: !update.forceUpdate,

      builder: (dialogContext) {

        return PopScope(

          canPop: !update.forceUpdate,

          child: AlertDialog(

            title: const Text('Update Available'),

            content: Text(

              'A new version (${update.version}) of ClockMetric is available.'

              '${update.releaseNotes == null ||

                      update.releaseNotes!.trim().isEmpty

                  ? ''

                  : '\n\n${update.releaseNotes!.trim()}'}',

            ),

            actions: [

              if (!update.forceUpdate)

                TextButton(

                  onPressed: () {

                    Navigator.of(dialogContext).pop();

                  },

                  child: const Text('Later'),

                ),

              ElevatedButton(

                onPressed: () async {

                  Navigator.of(dialogContext).pop();

                  await _showUpdateDownloadDialog(update);

                },

                child: const Text('Update'),

              ),

            ],

          ),

        );

      },

    );

  } catch (error) {

    debugPrint('Update error: $error');

  } finally {

    _checkingForUpdate = false;

  }

}

Future<void> _showUpdateDownloadDialog(

  AppUpdateInfo update,

) async {

  await showDialog<void>(

    context: context,

    barrierDismissible: false,

    builder: (_) {

      return _UpdateDownloadDialog(

        update: update,

        updateService: _updateService,

      );

    },

  );

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

  if (workspaceSubscriptionBlocked &&

      currentUserRole != 'admin' &&

      currentUserRole != 'master_admin') {

  screen = Scaffold(

    backgroundColor: const Color(0xFFF8FAFC),

    body: Center(

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          const Icon(

            Icons.lock_clock_rounded,

            size: 54,

            color: Color(0xFFF97316),

          ),

          const SizedBox(height: 18),

          const Text(

            'Your workspace trial has ended.',

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: 20,

              fontWeight: FontWeight.bold,

              color: Color(0xFF1F2937),

            ),

          ),

          const SizedBox(height: 8),

          const Text(

            'Please contact your administrator.',

            textAlign: TextAlign.center,

            style: TextStyle(

              fontSize: 14,

              color: Color(0xFF6B7280),

            ),

          ),

          const SizedBox(height: 24),

          SizedBox(

            width: 160,

            height: 42,

            child: ElevatedButton.icon(

              onPressed: () async {

                await supabase.auth.signOut();

              },

              icon: const Icon(Icons.logout_rounded),

              label: const Text('Logout'),

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xFFF97316),

                foregroundColor: Colors.white,

              ),

            ),

          ),

        ],

      ),

    ),

  );

} else {

    if (currentUserRole == 'master_admin') {

  screen = const MasterAdminDashboard();

} else {

  screen = const DashboardV2Screen();

}

  }

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