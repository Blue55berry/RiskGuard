/// RiskGuard - Real-Time AI-Based Digital Risk Detection System
/// Main entry point for the Flutter application
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/call_detection/providers/call_history_provider.dart';
import 'features/voice_analysis/providers/voice_analysis_provider.dart';
import 'features/message_analysis/providers/message_analysis_provider.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/voice_analysis/screens/voice_analysis_screen.dart';
import 'features/message_analysis/screens/message_analysis_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style for dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF1A1A2E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const RiskGuardApp());
}

class RiskGuardApp extends StatelessWidget {
  const RiskGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CallHistoryProvider()),
        ChangeNotifierProvider(create: (_) => VoiceAnalysisProvider()),
        ChangeNotifierProvider(create: (_) => MessageAnalysisProvider()),
      ],
      child: MaterialApp(
        title: 'RiskGuard',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const DashboardScreen(),
        routes: {
          '/voice-analysis': (context) => const VoiceAnalysisScreen(),
          '/message-analysis': (context) => const MessageAnalysisScreen(),
        },
      ),
    );
  }
}
