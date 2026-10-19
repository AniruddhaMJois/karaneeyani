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

  // Initialize Supabase client
  await SupabaseSyncService.init();

  // Initialize storage & database services
  final storageService = StorageService();
  await storageService.init();

  final syncService = SupabaseSyncService(storage: storageService);

  final pinAuthService = PinAuthService(storage: storageService);
  await pinAuthService.init();

  final dbService = DatabaseService(
    userId: pinAuthService.userId.isNotEmpty ? pinAuthService.userId : 'local_user',
    storage: storageService,
    syncService: syncService,
  );
  await dbService.init();

  final alarmService = AlarmService(dbService: dbService);
  alarmService.init();

  final themeProvider = ThemeProvider();
  final navigationProvider = NavigationProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: navigationProvider),
        ChangeNotifierProvider.value(value: pinAuthService),
        Provider.value(value: dbService),
        Provider.value(value: syncService),
        Provider.value(value: alarmService),
      ],
      child: KaraneeyaaniLinuxApp(dbService: dbService),
    ),
  );
}

class KaraneeyaaniLinuxApp extends StatelessWidget {
  final DatabaseService dbService;

  const KaraneeyaaniLinuxApp({super.key, required this.dbService});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Karaneeyaani - Linux Desktop',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: SplashScreen(dbService: dbService),
    );
  }
}
