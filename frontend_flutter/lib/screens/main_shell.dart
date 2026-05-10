import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/camera_provider.dart';
import '../providers/incident_provider.dart';
import '../widgets/alert_sidebar.dart';
import '../widgets/glass.dart';
import 'activity_history_view.dart';
import 'landing_view.dart';
import 'live_operations_view.dart';
import 'photo_analyze_view.dart';
import 'realtime_device_view.dart';
import 'video_analyze_view.dart';

/// Root shell after auth: landing + section navigation (rail / bottom bar).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  void _refreshFeeds() {
    context.read<CameraProvider>().loadCameras();
    context.read<IncidentProvider>().refresh(silentErrors: false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final pages = <Widget>[
      const LandingView(),
      const LiveOperationsView(),
      RealtimeDeviceView(active: _index == 2),
      const VideoAnalyzeView(),
      const PhotoAnalyzeView(),
      const ActivityHistoryView(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;

        final rail = NavigationRail(
          backgroundColor: Colors.black.withValues(alpha: 0.2),
          selectedIndex: _index,
          onDestinationSelected: _go,
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 8),
            child: Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.85)),
          ),
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: Text('Home'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded),
              label: Text('Live'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.bolt_outlined),
              selectedIcon: Icon(Icons.bolt_rounded),
              label: Text('Realtime'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.movie_outlined),
              selectedIcon: Icon(Icons.movie_rounded),
              label: Text('Video'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.image_outlined),
              selectedIcon: Icon(Icons.image_rounded),
              label: Text('Photo'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history_rounded),
              label: Text('Activity'),
            ),
          ],
        );

        final body = IndexedStack(
          index: _index,
          children: pages,
        );

        final showAlertsDrawer = !wide && (_index == 1 || _index == 2);

        return Scaffold(
          key: _scaffoldKey,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.9), size: 26),
                const SizedBox(width: 10),
                Text(
                  'AIRS',
                  style: TextStyle(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
            actions: [
              if (showAlertsDrawer)
                IconButton(
                  tooltip: 'Alerts',
                  onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                  icon: const Icon(Icons.notifications_active_outlined),
                ),
              if (auth.isGuest)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: GlassChip(
                      label: 'Guest',
                      icon: Icons.person_outline_rounded,
                      accent: Color(0xFF3B9EFF),
                    ),
                  ),
                ),
              if (auth.profile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Text(
                      auth.profile!.role,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.55),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Refresh feeds',
                onPressed: _refreshFeeds,
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                onPressed: () => context.read<AuthProvider>().signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ],
          ),
          body: GradientBackground(
            child: SafeArea(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        rail,
                        VerticalDivider(width: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.08)),
                        Expanded(child: body),
                      ],
                    )
                  : SizedBox.expand(child: body),
            ),
          ),
          endDrawer: showAlertsDrawer
              ? Drawer(
                  backgroundColor: const Color(0xFF0A0E18).withValues(alpha: 0.97),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical - 24,
                        child: const AlertSidebar(),
                      ),
                    ),
                  ),
                )
              : null,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  height: 68,
                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                  indicatorColor: const Color(0xFF3B9EFF).withValues(alpha: 0.28),
                  selectedIndex: _index,
                  onDestinationSelected: _go,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home_rounded),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Live',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bolt_outlined),
                      selectedIcon: Icon(Icons.bolt_rounded),
                      label: 'Realtime',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.movie_outlined),
                      selectedIcon: Icon(Icons.movie_rounded),
                      label: 'Video',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.image_outlined),
                      selectedIcon: Icon(Icons.image_rounded),
                      label: 'Photo',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'Activity',
                    ),
                  ],
                ),
        );
      },
    );
  }
}
