import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

class TracelySidebar extends StatelessWidget {
  final String activeRoute;

  const TracelySidebar({
    super.key,
    required this.activeRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: TracelyTheme.surfaceColor,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Icon(Icons.radar, color: TracelyTheme.primaryColor, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tracely',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SidebarItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Dashboard',
                  route: '/dashboard',
                  isActive: activeRoute == '/dashboard',
                ),
                _SidebarItem(
                  icon: Icons.workspaces_outline,
                  label: 'Workspaces',
                  route: '/workspaces',
                  isActive: activeRoute == '/workspaces',
                ),
                _SidebarItem(
                  icon: Icons.folder_outlined,
                  label: 'Collections',
                  route: '/collections',
                  isActive: activeRoute == '/collections',
                ),
                _SidebarItem(
                  icon: Icons.send_outlined,
                  label: 'Request Studio',
                  route: '/request-studio',
                  isActive: activeRoute == '/request-studio',
                ),
                _SidebarItem(
                  icon: Icons.analytics_outlined,
                  label: 'Topology',
                  route: '/topology',
                  isActive: activeRoute == '/topology',
                ),
                _SidebarItem(
                  icon: Icons.api_outlined,
                  label: 'Mocks',
                  route: '/mocks',
                  isActive: activeRoute == '/mocks',
                ),
                _SidebarItem(
                  icon: Icons.cloud_outlined,
                  label: 'Environments',
                  route: '/environments',
                  isActive: activeRoute == '/environments',
                ),
                _SidebarItem(
                  icon: Icons.account_tree_outlined,
                  label: 'Workflows',
                  route: '/workflows',
                  isActive: activeRoute == '/workflows',
                ),
                _SidebarItem(
                  icon: Icons.security_outlined,
                  label: 'Governance',
                  route: '/governance',
                  isActive: activeRoute == '/governance',
                ),
                _SidebarItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Reports',
                  route: '/reports',
                  isActive: activeRoute == '/reports',
                ),
                _SidebarItem(
                  icon: Icons.list_alt_outlined,
                  label: 'Audit Logs',
                  route: '/audit-logs',
                  isActive: activeRoute == '/audit-logs',
                ),
                _SidebarItem(
                  icon: Icons.gesture_outlined,
                  label: 'Data Generator',
                  route: '/data-generator',
                  isActive: activeRoute == '/data-generator',
                ),
                _SidebarItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Contract Testing',
                  route: '/contract-testing',
                  isActive: activeRoute == '/contract-testing',
                ),
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            route: '/dashboard',
            isActive: false,
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const ListTile(
            leading: CircleAvatar(
              backgroundColor: TracelyTheme.primaryColor,
              child: Text('JD'),
            ),
            title: Text('User Profile'),
            subtitle: Text('Admin'),
            trailing: Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.route,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? TracelyTheme.primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? TracelyTheme.primaryColor : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    color: isActive ? Colors.white : Colors.white60,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
