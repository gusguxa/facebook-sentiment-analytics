import 'package:flutter/material.dart';
import 'services/app_settings.dart';
import 'views/splash_screen.dart';
import 'views/login_view.dart';
import 'views/main_shell_view.dart';

void main() {
  runApp(const MineriaIAApp());
}

class MineriaIAApp extends StatelessWidget {
  const MineriaIAApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Facebook Pulse AI • Arthur Mining Engine',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
          // Tema Claro
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF0F172A),
              brightness: Brightness.light,
              primary: const Color(0xFF0F172A),
              surface: Colors.white,
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            dividerColor: const Color(0xFFE2E8F0),
            fontFamily: 'Roboto',
          ),
          // Tema Oscuro con alto contraste
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              secondary: Color(0xFF60A5FA),
              surface: Color(0xFF1E293B),
              onSurface: Color(0xFFF8FAFC),
              surfaceContainerHighest: Color(0xFF334155),
            ),
            scaffoldBackgroundColor: const Color(0xFF0B1120),
            cardColor: const Color(0xFF1E293B),
            dividerColor: const Color(0xFF334155),
            fontFamily: 'Roboto',
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/login': (context) => const LoginView(),
            '/dashboard': (context) => const MainShellView(),
          },
        );
      },
    );
  }
}
