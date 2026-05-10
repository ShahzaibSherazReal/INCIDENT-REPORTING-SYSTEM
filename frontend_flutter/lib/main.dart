import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/analysis_history_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/camera_provider.dart';
import 'providers/incident_provider.dart';
import 'screens/auth_view.dart';
import 'screens/main_shell.dart';
import 'services/app_config.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'theme.dart';
import 'widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final databaseService = DatabaseService();
  final authService = AuthService();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => CameraProvider(databaseService)),
        ChangeNotifierProvider(create: (_) => IncidentProvider(databaseService)),
      ],
      child: const AirsApp(),
    ),
  );
}

class AirsApp extends StatelessWidget {
  const AirsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incident Reporting System',
      debugShowCheckedModeBanner: false,
      theme: buildDarkExecutiveTheme(),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          if (authProvider.isLoading) {
            return Scaffold(
              body: GradientBackground(
                child: Center(
                  child: GlassPanel(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulseLoader(size: 52),
                        const SizedBox(height: 20),
                        Text(
                          'Loading',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.55),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          if (authProvider.session == null && !authProvider.isGuest) {
            return const AuthView();
          }
          return ChangeNotifierProvider(
            create: (_) => AnalysisHistoryProvider(),
            child: const MainShell(),
          );
        },
      ),
    );
  }
}
