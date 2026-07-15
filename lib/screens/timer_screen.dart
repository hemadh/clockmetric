import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../services/screenshot_scheduler_service.dart';
import '../services/time_entry_service.dart';
import '../theme/app_colors.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  Timer? timer;

  int seconds = 0;

  bool isRunning = false;
  bool isLoading = true;
  bool actionLoading = false;
  bool longTimerWarningShown = false;

  DateTime? startTime;
  String? selectedProjectId;
  String? runningEntryId;

  List<Map<String, dynamic>> projects = [];

  bool get isAdmin {
    return currentUserRole.toLowerCase() == 'admin';
  }

  @override
  void initState() {
    super.initState();
    initializeScreen();
  }

  Future<void> initializeScreen() async {
    try {
      await loadProjects();
      await loadRunningTimer();
    } catch (error) {
      debugPrint(
        'Timer screen initialization error: $error',
      );

      if (!mounted) return;

      _showMessage(
        'Unable to load the timer. Please try again.',
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

  Future<void> loadProjects() async {
    if (isAdmin) {
      await loadAdminProjects();
    } else {
      await loadEmployeeProjects();
    }
  }

  Future<void> loadAdminProjects() async {
    final response = await supabase
        .from('projects')
        .select(
          'id, project_name, is_active',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        )
        .eq(
          'is_active',
          true,
        )
        .order(
          'project_name',
          ascending: true,
        );

    if (!mounted) return;

    setState(() {
      projects = List<Map<String, dynamic>>.from(
        response,
      );
    });
  }

  Future<void> loadEmployeeProjects() async {
    if (currentUserId.isEmpty) {
      if (!mounted) return;

      setState(() {
        projects = [];
      });

      return;
    }

    final assignmentResponse = await supabase
        .from('project_members')
        .select(
          'project_id, projects!inner('
          'id, project_name, workspace_id, is_active'
          ')',
        )
        .eq(
          'workspace_id',
          currentWorkspaceId,
        )
        .eq(
          'employee_id',
          currentUserId,
        )
        .eq(
          'projects.workspace_id',
          currentWorkspaceId,
        )
        .eq(
          'projects.is_active',
          true,
        );

    final assignedProjects = <Map<String, dynamic>>[];
    final addedProjectIds = <String>{};

    for (final assignment in assignmentResponse) {
      final projectData = assignment['projects'];

      if (projectData is! Map) {
        continue;
      }

      final project = Map<String, dynamic>.from(
        projectData,
      );

      final projectId =
          project['id']?.toString().trim() ?? '';

      if (projectId.isEmpty ||
          addedProjectIds.contains(projectId)) {
        continue;
      }

      addedProjectIds.add(projectId);
      assignedProjects.add(project);
    }

    assignedProjects.sort((first, second) {
      final firstName =
          first['project_name']?.toString().toLowerCase() ??
              '';

      final secondName =
          second['project_name']?.toString().toLowerCase() ??
              '';

      return firstName.compareTo(secondName);
    });

    if (!mounted) return;

    setState(() {
      projects = assignedProjects;
    });
  }

  Future<void> loadRunningTimer() async {
    final running =
        await TimeEntryService().getRunningEntry();

    if (running == null) return;

    final parsedStartTime = DateTime.tryParse(
      running['start_time']?.toString() ?? '',
    );

    if (parsedStartTime == null) return;

    final runningProjectId =
        running['project_id']?.toString();

    startTime = parsedStartTime;
    selectedProjectId = runningProjectId;
    runningEntryId = running['id']?.toString();

    if (runningProjectId != null &&
        runningProjectId.isNotEmpty) {
      await ensureRunningProjectIsAvailable(
        runningProjectId,
      );
    }

    if (!mounted) return;

    setState(() {
      isRunning = true;

      seconds = DateTime.now()
          .difference(startTime!)
          .inSeconds;
    });

    startTicker();

    if (runningEntryId != null) {
      ScreenshotSchedulerService.instance.start(
        entryId: runningEntryId!,
        projectId: selectedProjectId,
      );
    }
  }

  Future<void> ensureRunningProjectIsAvailable(
    String projectId,
  ) async {
    final projectAlreadyLoaded = projects.any(
      (project) =>
          project['id']?.toString() == projectId,
    );

    if (projectAlreadyLoaded) return;

    try {
      final response = await supabase
          .from('projects')
          .select(
            'id, project_name, is_active',
          )
          .eq(
            'id',
            projectId,
          )
          .eq(
            'workspace_id',
            currentWorkspaceId,
          )
          .maybeSingle();

      if (response == null) return;

      if (!mounted) return;

      setState(() {
        projects = [
          ...projects,
          Map<String, dynamic>.from(response),
        ];
      });
    } catch (error) {
      debugPrint(
        'Running project loading error: $error',
      );
    }
  }

  void startTicker() {
    timer?.cancel();

    timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted || startTime == null) return;

        final elapsedSeconds = DateTime.now()
            .difference(startTime!)
            .inSeconds;

        setState(() {
          seconds = elapsedSeconds;
        });

        if (elapsedSeconds >= 8 * 60 * 60 &&
            !longTimerWarningShown) {
          longTimerWarningShown = true;

          _showMessage(
            'Your timer has been running for 8 hours. '
            'Please check whether you forgot to stop it.',
          );
        }
      },
    );
  }

  Future<void> startTimer() async {
    if (selectedProjectId == null) {
      _showMessage(
        projects.isEmpty && !isAdmin
            ? 'No project has been assigned to you. '
                'Please contact your admin.'
            : 'Please select a project.',
        isError: true,
      );

      return;
    }

    final selectedProjectExists = projects.any(
      (project) =>
          project['id']?.toString() ==
          selectedProjectId,
    );

    if (!selectedProjectExists) {
      _showMessage(
        'This project is no longer available.',
        isError: true,
      );

      return;
    }

    if (actionLoading) return;

    setState(() {
      actionLoading = true;
    });

    try {
      final existing =
          await TimeEntryService().getRunningEntry();

      if (existing != null) {
        _showMessage(
          'A timer is already running.',
          isError: true,
        );

        await loadRunningTimer();
        return;
      }

      final newStartTime = DateTime.now();

      final entryId =
          await TimeEntryService().startTimeEntry(
        projectId: selectedProjectId!,
      );

      if (!mounted) return;

      setState(() {
        startTime = newStartTime;
        runningEntryId = entryId;
        isRunning = true;
        seconds = 0;
        longTimerWarningShown = false;
      });

      startTicker();

      ScreenshotSchedulerService.instance.start(
        entryId: entryId,
        projectId: selectedProjectId,
      );

      _showMessage(
        'Timer started successfully.',
      );
    } catch (error) {
      debugPrint(
        'Start timer error: $error',
      );

      _showMessage(
        'Unable to start the timer.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> stopTimer() async {
    if (runningEntryId == null ||
        startTime == null ||
        actionLoading) {
      return;
    }

    final noteController =
        TextEditingController();

    final note = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(18),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.edit_note,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text(
                'Work Note',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText:
                    'What did you work on?',
                filled: true,
                fillColor:
                    AppColors.background,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(
                    color: AppColors.border,
                  ),
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(
                    color: AppColors.border,
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop('');
              },
              child: const Text(
                'Skip',
                style: TextStyle(
                  color:
                      AppColors.textSecondary,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor:
                    AppColors.primary,
                foregroundColor:
                    Colors.white,
              ),
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  noteController.text.trim(),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (!mounted) return;

    setState(() {
      actionLoading = true;
    });

    try {
      ScreenshotSchedulerService.instance.stop();

      await TimeEntryService().stopTimeEntry(
        entryId: runningEntryId!,
        startTime: startTime!,
        note: note ?? '',
      );

      timer?.cancel();

      if (!mounted) return;

      setState(() {
        isRunning = false;
        seconds = 0;
        startTime = null;
        runningEntryId = null;
        selectedProjectId = null;
        longTimerWarningShown = false;
      });

      await loadProjects();

      _showMessage(
        'Time entry saved successfully.',
      );
    } catch (error) {
      debugPrint(
        'Stop timer error: $error',
      );

      if (runningEntryId != null) {
        ScreenshotSchedulerService.instance.start(
          entryId: runningEntryId!,
          projectId: selectedProjectId,
        );
      }

      _showMessage(
        'Unable to stop the timer.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          actionLoading = false;
        });
      }
    }
  }

  Future<void> refreshProjects() async {
    if (isRunning || actionLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await loadProjects();

      final selectedProjectStillExists =
          projects.any(
        (project) =>
            project['id']?.toString() ==
            selectedProjectId,
      );

      if (!selectedProjectStillExists) {
        selectedProjectId = null;
      }
    } catch (error) {
      debugPrint(
        'Project refresh error: $error',
      );

      _showMessage(
        'Unable to refresh projects.',
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

  String formatTime() {
    final hours = seconds ~/ 3600;
    final minutes =
        (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  String selectedProjectName() {
    if (selectedProjectId == null) {
      return 'No project selected';
    }

    for (final project in projects) {
      if (project['id']?.toString() ==
          selectedProjectId) {
        return project['project_name']
                ?.toString() ??
            'Selected project';
      }
    }

    return 'Selected project';
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
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvailableProjects =
        projects.isNotEmpty;

    final validDropdownValue =
        selectedProjectId != null &&
                projects.any(
                  (project) =>
                      project['id']?.toString() ==
                      selectedProjectId,
                )
            ? selectedProjectId
            : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor:
            AppColors.primary,
        foregroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Time Tracker',
          style: TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh projects',
            onPressed:
                isRunning || actionLoading
                    ? null
                    : refreshProjects,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(
                color: AppColors.primary,
              ),
            )
          : Center(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.all(
                  28,
                ),
                child: Container(
                  width: 620,
                  padding:
                      const EdgeInsets.all(
                    34,
                  ),
                  decoration:
                      BoxDecoration(
                    color:
                        AppColors.surface,
                    borderRadius:
                        BorderRadius.circular(
                      24,
                    ),
                    border: Border.all(
                      color:
                          AppColors.border,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color:
                            Color(0x0D000000),
                        blurRadius: 24,
                        offset:
                            Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .primaryLight,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            24,
                          ),
                        ),
                        child: Icon(
                          isRunning
                              ? Icons.timer
                              : Icons
                                  .timer_outlined,
                          size: 50,
                          color:
                              AppColors.primary,
                        ),
                      ),
                      const SizedBox(
                        height: 22,
                      ),
                      Text(
                        isRunning
                            ? 'Timer Running'
                            : 'Track Your Work',
                        style:
                            const TextStyle(
                          fontSize: 25,
                          fontWeight:
                              FontWeight.bold,
                          color: AppColors
                              .textPrimary,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      const Text(
                        'Screenshots may be captured while the timer is running.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color: AppColors
                              .textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(
                        height: 28,
                      ),

                      if (!hasAvailableProjects &&
                          !isRunning)
                        buildNoProjectsMessage()
                      else
                        DropdownButtonFormField<
                            String>(
                          value:
                              validDropdownValue,
                          isExpanded: true,
                          decoration:
                              InputDecoration(
                            labelText:
                                'Select Project',
                            prefixIcon:
                                const Icon(
                              Icons
                                  .folder_open_outlined,
                              color: AppColors
                                  .primary,
                            ),
                            filled: true,
                            fillColor:
                                isRunning
                                    ? AppColors
                                        .background
                                    : AppColors
                                        .surface,
                            border:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                            enabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color: AppColors
                                    .border,
                              ),
                            ),
                            focusedBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color: AppColors
                                    .primary,
                                width: 1.6,
                              ),
                            ),
                            disabledBorder:
                                OutlineInputBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                              borderSide:
                                  const BorderSide(
                                color: AppColors
                                    .border,
                              ),
                            ),
                          ),
                          items: projects.map<
                              DropdownMenuItem<
                                  String>>(
                            (project) {
                              final projectId =
                                  project['id']
                                          ?.toString() ??
                                      '';

                              final projectName =
                                  project['project_name']
                                          ?.toString() ??
                                      'Unnamed Project';

                              return DropdownMenuItem<
                                  String>(
                                value: projectId,
                                child: Text(
                                  projectName,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: isRunning ||
                                  actionLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedProjectId =
                                        value;
                                  });
                                },
                        ),

                      if (isRunning) ...[
                        const SizedBox(
                          height: 18,
                        ),
                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          decoration:
                              BoxDecoration(
                            color: AppColors
                                .primarySurface,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color: AppColors
                                  .primaryLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons
                                    .work_outline,
                                color: AppColors
                                    .primary,
                                size: 20,
                              ),
                              const SizedBox(
                                width: 10,
                              ),
                              Expanded(
                                child: Text(
                                  selectedProjectName(),
                                  style:
                                      const TextStyle(
                                    color: AppColors
                                        .textPrimary,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: AppColors
                                      .success
                                      .withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    20,
                                  ),
                                ),
                                child:
                                    const Text(
                                  'ACTIVE',
                                  style:
                                      TextStyle(
                                    color: AppColors
                                        .success,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: 36,
                      ),
                      Text(
                        formatTime(),
                        style:
                            const TextStyle(
                          fontSize: 58,
                          fontWeight:
                              FontWeight.w800,
                          letterSpacing: 2,
                          color: AppColors
                              .textPrimary,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        isRunning
                            ? 'Tracking time now'
                            : hasAvailableProjects
                                ? 'Ready to begin'
                                : 'Waiting for project assignment',
                        style: TextStyle(
                          color: isRunning
                              ? AppColors.success
                              : AppColors
                                  .textMuted,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(
                        height: 34,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child:
                                  FilledButton
                                      .icon(
                                style:
                                    FilledButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors
                                          .primary,
                                  foregroundColor:
                                      Colors.white,
                                  disabledBackgroundColor:
                                      AppColors
                                          .border,
                                  disabledForegroundColor:
                                      AppColors
                                          .textMuted,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),
                                ),
                                onPressed: isRunning ||
                                        actionLoading ||
                                        !hasAvailableProjects
                                    ? null
                                    : startTimer,
                                icon: actionLoading &&
                                        !isRunning
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .play_arrow_rounded,
                                      ),
                                label:
                                    const Text(
                                  'Start',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 16,
                          ),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child:
                                  FilledButton
                                      .icon(
                                style:
                                    FilledButton
                                        .styleFrom(
                                  backgroundColor:
                                      AppColors
                                          .danger,
                                  foregroundColor:
                                      Colors.white,
                                  disabledBackgroundColor:
                                      AppColors
                                          .border,
                                  disabledForegroundColor:
                                      AppColors
                                          .textMuted,
                                  shape:
                                      RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      14,
                                    ),
                                  ),
                                ),
                                onPressed: isRunning &&
                                        !actionLoading
                                    ? stopTimer
                                    : null,
                                icon: actionLoading &&
                                        isRunning
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .stop_rounded,
                                      ),
                                label:
                                    const Text(
                                  'Stop',
                                  style:
                                      TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget buildNoProjectsMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryLight,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_off_outlined,
            color: AppColors.primary,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            isAdmin
                ? 'No active projects found'
                : 'No project assigned',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAdmin
                ? 'Create an active project before starting the timer.'
                : 'Ask your admin to assign you to a project.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(
                color: AppColors.primary,
              ),
            ),
            onPressed: refreshProjects,
            icon: const Icon(Icons.refresh),
            label: const Text(
              'Refresh Projects',
            ),
          ),
        ],
      ),
    );
  }
}