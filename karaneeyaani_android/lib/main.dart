import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alarm/alarm.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/pin_auth_service.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SupabaseService.init();
  if (!kIsWeb) {
    await Alarm.init();
    await NotificationService.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => PinAuthService()),
      ],
      child: const KaraneeyaaniApp(),
    ),
  );
}

class KaraneeyaaniApp extends StatelessWidget {
  const KaraneeyaaniApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'Karaneeyaani',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      home: const SplashScreen(),
    );
  }
}
