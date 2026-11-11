import 'package:flutter/material.dart';

/// Servicio centralizado de configuración, preferencias y estado de sesión.
class AppSettings {
  // Modo de tema: System (Predeterminado), Light (Claro), Dark (Oscuro)
  static final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.system);

  // Usuario actual conectado (inicia en null para requerir inicio de sesión)
  static final ValueNotifier<Map<String, dynamic>?> currentUserNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  // Opciones generales funcionales
  static final ValueNotifier<bool> alertOnHighBots = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> enableAnimations = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> autoRefreshOnNav = ValueNotifier<bool>(false);
  static final ValueNotifier<String> defaultExportFormat = ValueNotifier<String>('xlsx');
  static final ValueNotifier<bool> headlessScraper = ValueNotifier<bool>(true);
  static final ValueNotifier<int> timeoutScraperSeconds = ValueNotifier<int>(30);

  /// Determina si actualmente se está renderizando en modo oscuro
  static bool isDarkMode(BuildContext context) {
    if (themeModeNotifier.value == ThemeMode.dark) return true;
    if (themeModeNotifier.value == ThemeMode.light) return false;
    return MediaQuery.of(context).platformBrightness == Brightness.dark;
  }

  /// Cambia el modo de tema de la aplicación
  static void setThemeMode(ThemeMode mode) {
    themeModeNotifier.value = mode;
  }

  /// Guarda el usuario activo tras login
  static void setCurrentUser(Map<String, dynamic>? user) {
    currentUserNotifier.value = user;
  }

  /// Indica si el usuario activo tiene rol de administrador
  static bool get isAdmin => (currentUserNotifier.value?['rol'] ?? '') == 'admin';

  /// Nombre del rol formateado para mostrar en la interfaz
  static String get rolLabel => isAdmin ? 'ADMINISTRADOR' : 'SOLO CONSULTA';

  /// Cierra la sesión activa y navega al login
  static void logout(BuildContext context) {
    currentUserNotifier.value = null;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }
}
