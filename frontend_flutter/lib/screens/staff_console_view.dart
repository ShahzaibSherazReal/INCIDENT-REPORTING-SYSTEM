import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/incident_provider.dart';
import '../services/database_service.dart';
import '../widgets/glass.dart';

/// Built-in Admin / Super Administrator: manage DB users and (super only) AI tuning + evidence purge.
class StaffConsoleView extends StatefulWidget {
  const StaffConsoleView({super.key});

  @override
  State<StaffConsoleView> createState() => _StaffConsoleViewState();
}

class _StaffConsoleViewState extends State<StaffConsoleView> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<Map<String, dynamic>> _users = [];
  bool _loadingUsers = true;
  String? _usersError;

  bool _loadingAi = false;
  String? _aiError;
  double _confidence = 0.55;
  double _fps = 2.5;
  double _deviceConf = 0.45;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final superUser = auth.isBuiltInSuperAdministrator;
    _tabs = TabController(length: superUser ? 2 : 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reloadUsers();
      if (superUser) _loadAi();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String get _tierHeader => context.read<AuthProvider>().isBuiltInSuperAdministrator ? 'super' : 'admin';

  bool get _isSuper => context.read<AuthProvider>().isBuiltInSuperAdministrator;

  Future<void> _reloadUsers() async {
    final db = context.read<DatabaseService>();
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final rows = await db.fetchStaffUsers(tier: _tierHeader);
      if (!mounted) return;
      setState(() {
        _users = rows;
        _loadingUsers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e.toString();
        _loadingUsers = false;
      });
    }
  }

  Future<void> _loadAi() async {
    final db = context.read<DatabaseService>();
    setState(() {
      _loadingAi = true;
      _aiError = null;
    });
    try {
      final m = await db.fetchAiConfig(tier: 'super');
      if (!mounted) return;
      setState(() {
        _confidence = (m['confidence_threshold'] as num?)?.toDouble() ?? _confidence;
        _fps = (m['process_fps'] as num?)?.toDouble() ?? _fps;
        _deviceConf = (m['device_frame_confidence'] as num?)?.toDouble() ?? _deviceConf;
        _loadingAi = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiError = e.toString();
        _loadingAi = false;
      });
    }
  }

  Future<void> _saveAi() async {
    final db = context.read<DatabaseService>();
    try {
      await db.patchAiConfig(
        tier: 'super',
        confidenceThreshold: _confidence,
        processFps: _fps,
        deviceFrameConfidence: _deviceConf,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings updated on server (applies to new processing).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _purge() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete all evidence?'),
        content: const Text(
          'This removes incident rows from the database and JPEG snapshots stored on the API server. '
          'Connected cameras keep running.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Purge')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final db = context.read<DatabaseService>();
    try {
      final summary = await db.purgeEvidence(tier: 'super');
      if (!mounted) return;
      await context.read<IncidentProvider>().refresh(silentErrors: true);
      final ir = summary['incidents_removed'];
      final sr = summary['snapshot_files_removed'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purge complete (incidents removed: $ir, snapshot files: $sr).')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<String> get _assignableRoles => _isSuper
      ? const ['User', 'Operator', 'Admin', 'Super Administrator', 'System Administrator']
      : const ['User', 'Operator'];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: GlassPanel(
            borderRadius: 18,
            blurSigma: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: const Color(0xFF3B9EFF),
              tabs: [
                const Tab(text: 'Users & operators'),
                if (auth.isBuiltInSuperAdministrator) const Tab(text: 'AI & evidence'),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: auth.isBuiltInSuperAdministrator
                ? [
                    _UsersTab(
                      users: _users,
                      loading: _loadingUsers,
                      error: _usersError,
                      onRefresh: _reloadUsers,
                      assignableRoles: _assignableRoles,
                      tierHeader: _tierHeader,
                    ),
                    _SuperToolsTab(
                      loading: _loadingAi,
                      error: _aiError,
                      confidence: _confidence,
                      fps: _fps,
                      deviceConf: _deviceConf,
                      onConfidence: (v) => setState(() => _confidence = v),
                      onFps: (v) => setState(() => _fps = v),
                      onDevice: (v) => setState(() => _deviceConf = v),
                      onReloadAi: _loadAi,
                      onSaveAi: _saveAi,
                      onPurge: _purge,
                    ),
                  ]
                : [
                    _UsersTab(
                      users: _users,
                      loading: _loadingUsers,
                      error: _usersError,
                      onRefresh: _reloadUsers,
                      assignableRoles: _assignableRoles,
                      tierHeader: _tierHeader,
                    ),
                  ],
          ),
        ),
      ],
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    required this.users,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.assignableRoles,
    required this.tierHeader,
  });

  final List<Map<String, dynamic>> users;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final List<String> assignableRoles;
  final String tierHeader;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, style: const TextStyle(color: Color(0xFFFF8A80))),
              const SizedBox(height: 12),
              FilledButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        itemCount: users.length,
        itemBuilder: (context, i) {
          final row = users[i];
          final id = row['id']?.toString() ?? '';
          final email = row['email']?.toString() ?? '';
          final username = row['username']?.toString();
          final role = row['role']?.toString() ?? 'User';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassPanel(
              borderRadius: 16,
              blurSigma: 12,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username != null && username.isNotEmpty ? username : email,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        if (username != null && username.isNotEmpty)
                          Text(email, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45))),
                        Text(
                          'Role: $role',
                          style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.65)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 210,
                    child: _RoleEditor(
                      tierHeader: tierHeader,
                      userId: id,
                      currentRole: role,
                      assignableRoles: assignableRoles,
                      onApplied: onRefresh,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RoleEditor extends StatelessWidget {
  const _RoleEditor({
    required this.tierHeader,
    required this.userId,
    required this.currentRole,
    required this.assignableRoles,
    required this.onApplied,
  });

  final String tierHeader;
  final String userId;
  final String currentRole;
  final List<String> assignableRoles;
  final Future<void> Function() onApplied;

  static const _privileged = {'Admin', 'Super Administrator', 'System Administrator'};

  @override
  Widget build(BuildContext context) {
    final lockedForAdmin = tierHeader == 'admin' && _privileged.contains(currentRole);
    if (lockedForAdmin) {
      return Text(
        'Super Admin only',
        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
        textAlign: TextAlign.end,
      );
    }

    final value = assignableRoles.contains(currentRole) ? currentRole : assignableRoles.first;

    return DropdownButtonFormField<String>(
      value: value,
      decoration: const InputDecoration(isDense: true, labelText: 'Set role'),
      items: assignableRoles
          .map((r) => DropdownMenuItem(value: r, child: Text(r, overflow: TextOverflow.ellipsis)))
          .toList(),
      onChanged: (next) async {
        if (next == null || next == currentRole || userId.isEmpty) return;
        try {
          await context.read<DatabaseService>().updateStaffUserRole(
                tier: tierHeader,
                userId: userId,
                role: next,
              );
          await onApplied();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Role → $next')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
          }
        }
      },
    );
  }
}

class _SuperToolsTab extends StatelessWidget {
  const _SuperToolsTab({
    required this.loading,
    required this.error,
    required this.confidence,
    required this.fps,
    required this.deviceConf,
    required this.onConfidence,
    required this.onFps,
    required this.onDevice,
    required this.onReloadAi,
    required this.onSaveAi,
    required this.onPurge,
  });

  final bool loading;
  final String? error;
  final double confidence;
  final double fps;
  final double deviceConf;
  final ValueChanged<double> onConfidence;
  final ValueChanged<double> onFps;
  final ValueChanged<double> onDevice;
  final Future<void> Function() onReloadAi;
  final Future<void> Function() onSaveAi;
  final Future<void> Function() onPurge;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        if (loading)
          const LinearProgressIndicator(minHeight: 2)
        else if (error != null)
          Text(error!, style: const TextStyle(color: Color(0xFFFF8A80))),
        GlassPanel(
          borderRadius: 18,
          blurSigma: 14,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Live detection tuning',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.92)),
              ),
              const SizedBox(height: 6),
              Text(
                'Thresholds apply on this API instance (streams, uploads, device frames).',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 18),
              Text('Confidence threshold: ${confidence.toStringAsFixed(2)}'),
              Slider(
                value: confidence.clamp(0.05, 0.99),
                min: 0.05,
                max: 0.99,
                onChanged: onConfidence,
              ),
              Text('Process FPS cap: ${fps.toStringAsFixed(2)}'),
              Slider(
                value: fps.clamp(0.25, 30),
                min: 0.25,
                max: 30,
                onChanged: onFps,
              ),
              Text('Device frame confidence: ${deviceConf.toStringAsFixed(2)}'),
              Slider(
                value: deviceConf.clamp(0.05, 0.99),
                min: 0.05,
                max: 0.99,
                onChanged: onDevice,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton(onPressed: onSaveAi, child: const Text('Save AI settings')),
                  const SizedBox(width: 10),
                  OutlinedButton(onPressed: onReloadAi, child: const Text('Reload from server')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        GlassPanel(
          borderRadius: 18,
          blurSigma: 14,
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Evidence & logs',
                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.92)),
              ),
              const SizedBox(height: 8),
              Text(
                'Deletes incidents in Supabase and snapshot JPEGs under the API\'s snapshots folder.',
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
              ),
              const SizedBox(height: 14),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.red.shade100,
                  backgroundColor: Colors.red.withValues(alpha: 0.22),
                ),
                onPressed: onPurge,
                child: const Text('Purge all incidents & local snapshots'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
