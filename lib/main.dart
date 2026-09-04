import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'services/job_repository.dart';
import 'services/supabase_service.dart';
import 'screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Initialize Supabase Cloud Backend
  await SupabaseService.initialize();

  // 2. Initialize Local Storage & Hydrate Repository
  final repository = JobRepository();
  await repository.init();

  runApp(DetailCraftApp(repository: repository));
}

class DetailCraftApp extends StatelessWidget {
  final JobRepository repository;

  const DetailCraftApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: repository,
      builder: (context, _) {
        return MaterialApp(
          title: 'AutoDetailCraft',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
          home: MainNavigationScreen(repository: repository),
        );
      },
    );
  }
}
