import 'package:flutter/material.dart';
import '../models/goal_model.dart';

enum DesktopNavView {
  roadmap,
  calendar,
  goals,
  timeline,
  completed,
  bin,
  settings,
  goalDetails,
}

class NavigationProvider extends ChangeNotifier {
  DesktopNavView _currentView = DesktopNavView.roadmap;
  GoalModel? _selectedGoalForDetails;
  bool _isSidebarCollapsed = false;

  DesktopNavView get currentView => _currentView;
  GoalModel? get selectedGoalForDetails => _selectedGoalForDetails;
  bool get isSidebarCollapsed => _isSidebarCollapsed;

  void navigateTo(DesktopNavView view) {
    _currentView = view;
    if (view != DesktopNavView.goalDetails) {
      _selectedGoalForDetails = null;
    }
    notifyListeners();
  }

  void openGoalDetails(GoalModel goal) {
    _selectedGoalForDetails = goal;
    _currentView = DesktopNavView.goalDetails;
    notifyListeners();
  }

  void toggleSidebar() {
    _isSidebarCollapsed = !_isSidebarCollapsed;
    notifyListeners();
  }
}
