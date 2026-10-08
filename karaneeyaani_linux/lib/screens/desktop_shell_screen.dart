import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../services/database_service.dart';
import '../services/alarm_service.dart';
import '../services/pin_auth_service.dart';
import '../widgets/desktop_sidebar.dart';
import '../widgets/task_creation_sheet.dart';
import '../widgets/goal_creation_sheet.dart';

import 'daily_roadmap_view.dart';
import 'calendar_view.dart';
import 'goals_view.dart';
import 'goal_details_view.dart';
import 'sorted_tasks_view.dart';
import 'completed_items_view.dart';
import 'recycle_bin_view.dart';
import 'settings_view.dart';
import 'alarm_ringing_dialog.dart';

class DesktopShellScreen extends StatefulWidget {
  final DatabaseService dbService;
  final AlarmService? alarmService;

  const DesktopShellScreen({
    super.key,
    required this.dbService,
    this.alarmService,
  });

  @override
  State<DesktopShellScreen> createState() => _DesktopShellScreenState();
}

class _DesktopShellScreenState extends State<DesktopShellScreen> {
  StreamSubscription? _alarmSubscription;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final alarm = widget.alarmService ?? context.read<AlarmService>();
      _alarmSubscription = alarm.onAlarmTriggered.listen((task) {
        if (mounted) {
          AlarmRingingDialog.show(context, task, alarm);
        }
      });
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final isControlOrMeta = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isControlOrMeta) {
        if (event.logicalKey == LogicalKeyboardKey.keyN) {
          // Ctrl+N: Create Task
          showDialog(
            context: context,
            builder: (_) => TaskCreationSheet(dbService: widget.dbService),
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.keyG) {
          // Ctrl+G: Create Goal
          showDialog(
            context: context,
            builder: (_) => GoalCreationSheet(dbService: widget.dbService),
          );
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
          // Ctrl+L: Lock App
          context.read<PinAuthService>().lock();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
          // Ctrl+B: Toggle Sidebar
          context.read<NavigationProvider>().toggleSidebar();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<NavigationProvider>();

    return Focus(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F14),
        body: Row(
          children: [
            // Left Collapsible Sidebar Navigation Rail
            DesktopSidebar(dbService: widget.dbService),

            // Main Active View
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _buildCurrentView(navProvider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentView(NavigationProvider navProvider) {
    switch (navProvider.currentView) {
      case DesktopNavView.roadmap:
        return DailyRoadmapView(
          key: const ValueKey('roadmap'),
          dbService: widget.dbService,
        );
      case DesktopNavView.calendar:
        return CalendarView(
          key: const ValueKey('calendar'),
          dbService: widget.dbService,
        );
      case DesktopNavView.goals:
        return GoalsView(
          key: const ValueKey('goals'),
          dbService: widget.dbService,
        );
      case DesktopNavView.goalDetails:
        if (navProvider.selectedGoalForDetails != null) {
          return GoalDetailsView(
            key: ValueKey('goal_${navProvider.selectedGoalForDetails!.id}'),
            dbService: widget.dbService,
            goal: navProvider.selectedGoalForDetails!,
          );
        }
        return GoalsView(
          key: const ValueKey('goals_fallback'),
          dbService: widget.dbService,
        );
      case DesktopNavView.timeline:
        return SortedTasksView(
          key: const ValueKey('timeline'),
          dbService: widget.dbService,
        );
      case DesktopNavView.completed:
        return CompletedItemsView(
          key: const ValueKey('completed'),
          dbService: widget.dbService,
        );
      case DesktopNavView.bin:
        return RecycleBinView(
          key: const ValueKey('bin'),
          dbService: widget.dbService,
        );
      case DesktopNavView.settings:
        return SettingsView(
          key: const ValueKey('settings'),
          dbService: widget.dbService,
        );
    }
  }
}
