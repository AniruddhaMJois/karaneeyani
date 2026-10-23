import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/theme_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/pin_auth_service.dart';
import 'services/storage_service.dart';
import 'services/database_service.dart';
import 'services/alarm_service.dart';
import 'services/supabase_sync_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase client if configured
  await SupabaseSyncService.init();

  // Initialize storage & database services
  final storageService = StorageService();
  await storageService.init();

  final dbService = DatabaseService(storage: storageService);
  await dbService.init();

  final alarmService = AlarmService(dbService: dbService);
  alarmService.init();

  final pinAuthService = PinAuthService();
  await pinAuthService.init();

  final themeProvider = ThemeProvider();
  final navigationProvider = NavigationProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: navigationProvider),
        ChangeNotifierProvider.value(value: pinAuthService),
        Provider.value(value: dbService),
        Provider.value(value: alarmService),
      ],
      child: KaraneeyaaniWindowsApp(dbService: dbService),
    ),
  );
}

class KaraneeyaaniWindowsApp extends StatelessWidget {
  final DatabaseService dbService;

  const KaraneeyaaniWindowsApp({super.key, required this.dbService});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Karaneeyaani - Windows Desktop Edition',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: SplashScreen(dbService: dbService),
    );
  }
}

