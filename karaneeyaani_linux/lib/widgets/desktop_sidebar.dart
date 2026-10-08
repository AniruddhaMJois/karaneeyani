import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/theme_provider.dart';
import '../services/database_service.dart';
import '../services/pin_auth_service.dart';

class DesktopSidebar extends StatelessWidget {
  final DatabaseService dbService;

  const DesktopSidebar({
    super.key,
    required this.dbService,
  });

  @override
  Widget build(BuildContext context) {
    final nav = Provider.of<NavigationProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final isCollapsed = nav.isSidebarCollapsed;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isCollapsed ? 76 : 260,
      decoration: BoxDecoration(
        color: const Color(0xFF101014),
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header / Logo
          _buildHeader(context, theme, isCollapsed, nav),
          const Divider(color: Colors.white10, height: 1),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              children: [
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.roadmap,
                  icon: Icons.dashboard_rounded,
                  label: 'Daily Roadmap',
                  activeColor: theme.primaryColor,
                  isCollapsed: isCollapsed,
                  badgeStream: dbService.activeTasks.map((l) => l.length),
                ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.calendar,
                  icon: Icons.calendar_month_rounded,
                  label: 'Calendar & Ribbon',
                  activeColor: Colors.purpleAccent,
                  isCollapsed: isCollapsed,
                ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.goals,
                  icon: Icons.flag_rounded,
                  label: 'Goals & Projects',
                  activeColor: Colors.amberAccent,
                  isCollapsed: isCollapsed,
                  badgeStream: dbService.activeGoals.map((l) => l.length),
                ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.timeline,
                  icon: Icons.timeline_rounded,
                  label: 'Future Timeline',
                  activeColor: Colors.blueAccent,
                  isCollapsed: isCollapsed,
                ),
                const SizedBox(height: 16),
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'ARCHIVE & TRASH',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.completed,
                  icon: Icons.check_circle_rounded,
                  label: 'Completed Items',
                  activeColor: Colors.greenAccent,
                  isCollapsed: isCollapsed,
                  badgeStream: dbService.completedTasks.map((l) => l.length),
                ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.bin,
                  icon: Icons.delete_sweep_rounded,
                  label: 'Recycle Bin',
                  activeColor: Colors.redAccent,
                  isCollapsed: isCollapsed,
                  badgeStream: dbService.trashedTasks.map((l) => l.length),
                ),
                const SizedBox(height: 16),
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                      'PREFERENCES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ),
                _buildNavItem(
                  context: context,
                  view: DesktopNavView.settings,
                  icon: Icons.settings_rounded,
                  label: 'Settings & Themes',
                  activeColor: Colors.cyanAccent,
                  isCollapsed: isCollapsed,
                ),
              ],
            ),
          ),

          // Lock App Action at bottom
          const Divider(color: Colors.white10, height: 1),
          _buildLockSection(context, isCollapsed),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeProvider theme, bool isCollapsed, NavigationProvider nav) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 16, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 10),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon.png', fit: BoxFit.cover),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Karaneeyaani',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Linux Desktop',
                    style: TextStyle(fontSize: 11, color: Colors.white54),
                  ),
                ],
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
              color: Colors.white54,
              size: 20,
            ),
            tooltip: isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar',
            onPressed: () => nav.toggleSidebar(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required DesktopNavView view,
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isCollapsed,
    Stream<int>? badgeStream,
  }) {
    final nav = Provider.of<NavigationProvider>(context);
    final isSelected = nav.currentView == view;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => nav.navigateTo(view),
          hoverColor: Colors.white.withOpacity(0.05),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? activeColor.withOpacity(0.4) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? activeColor : Colors.white70,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ),
                  if (badgeStream != null)
                    StreamBuilder<int>(
                      stream: badgeStream,
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        if (count == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? activeColor : Colors.white12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.black : Colors.white70,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLockSection(BuildContext context, bool isCollapsed) {
    final pinAuth = Provider.of<PinAuthService>(context, listen: false);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Material(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            pinAuth.lock();
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 12 : 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.orangeAccent),
                if (!isCollapsed) ...[
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Lock Application',
                      style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
