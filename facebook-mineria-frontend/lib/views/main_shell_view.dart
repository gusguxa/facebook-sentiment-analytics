import 'package:flutter/material.dart';
import '../services/app_settings.dart';
import 'dashboard_view.dart';
import 'comparativa_view.dart';
import 'audiencia_view.dart';
import 'configuracion_view.dart';

class MainShellView extends StatefulWidget {
  const MainShellView({super.key});

  @override
  State<MainShellView> createState() => MainShellViewState();
}

class MainShellViewState extends State<MainShellView> {
  int _currentIndex = 0;
  final GlobalKey<DashboardViewState> _dashboardKey = GlobalKey<DashboardViewState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const Color _navy = Color(0xFF0F172A);
  static const Color _primaryBlue = Color(0xFF1877F2);
  static const Color _accent = Color(0xFF2563EB);

  void navegarYcargarAnalisis(int idAnalisis) {
    setState(() {
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dashboardKey.currentState?.cargarAnalisisPorId(idAnalisis);
    });
  }

  void _confirmarCerrarSesion() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 24),
              const SizedBox(width: 10),
              Text(
                'Cerrar Sesión',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            '¿Estás seguro de que deseas salir del sistema? Podrás volver a iniciar sesión en cualquier momento.',
            style: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                AppSettings.logout(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarDialogoPerfil(String nombre, String correo, String rol) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar grande
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
                  ),
                ),
                child: Center(
                  child: Text(
                    nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                nombre,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                correo,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: (rol.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (rol.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.4)),
                ),
                child: Text(
                  rol.toLowerCase() == 'admin' ? 'ADMINISTRADOR' : 'SOLO CONSULTA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: rol.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF334155)),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, color: _primaryBlue, size: 20),
                ),
                title: Text(
                  'Ajustes & Preferencias',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  'Tema visual, scraping y opciones',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _currentIndex = 3);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmarCerrarSesion();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFDC2626)),
                  label: const Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFDC2626)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: AppSettings.currentUserNotifier,
      builder: (context, user, _) {
        final nombreUsuario = user?['nombre'] ?? 'Administrador';
        final correoUsuario = user?['correo'] ?? 'admin@empresa.com';
        final rolUsuario = user?['rol'] ?? 'admin';

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          drawer: _buildNavigationDrawer(isDark, nombreUsuario, rolUsuario),
          appBar: AppBar(
            toolbarHeight: 62,
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'Menú de vistas',
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
            backgroundColor: isDark ? const Color(0xFF0B1120) : _navy,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B),
                height: 1,
              ),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Facebook Pulse AI',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                ),
                const SizedBox(width: 20),
                // Pill de estado en vivo
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'Backend :5000 • MariaDB :3306 • Gemini Activo',
                        style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              // Selector Rápido de Tema (Claro / Oscuro / Sistema)
              ValueListenableBuilder<ThemeMode>(
                valueListenable: AppSettings.themeModeNotifier,
                builder: (context, themeMode, _) {
                  IconData icon;
                  String tooltip;
                  if (themeMode == ThemeMode.light) {
                    icon = Icons.light_mode_rounded;
                    tooltip = 'Tema: Claro (Clic para Oscuro)';
                  } else if (themeMode == ThemeMode.dark) {
                    icon = Icons.dark_mode_rounded;
                    tooltip = 'Tema: Oscuro (Clic para Sistema)';
                  } else {
                    icon = Icons.brightness_auto_rounded;
                    tooltip = 'Tema: Sistema (Clic para Claro)';
                  }

                  return IconButton(
                    tooltip: tooltip,
                    icon: Icon(icon, size: 20, color: const Color(0xFFCBD5E1)),
                    onPressed: () {
                      if (themeMode == ThemeMode.system) {
                        AppSettings.setThemeMode(ThemeMode.dark);
                      } else if (themeMode == ThemeMode.dark) {
                        AppSettings.setThemeMode(ThemeMode.light);
                      } else {
                        AppSettings.setThemeMode(ThemeMode.system);
                      }
                    },
                  );
                },
              ),
              const SizedBox(width: 4),

              // Badge Clickeable de Usuario / Cuenta (Diseño horizontal blindado contra overflow)
              Center(
                child: InkWell(
                  onTap: () => _mostrarDialogoPerfil(nombreUsuario, correoUsuario, rolUsuario),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: _accent,
                          child: Text(
                            nombreUsuario.isNotEmpty ? nombreUsuario[0].toUpperCase() : 'A',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          nombreUsuario,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (rolUsuario.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: (rolUsuario.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            rolUsuario.toLowerCase() == 'admin' ? 'ADMIN' : 'SOLO CONSULTA',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: rolUsuario.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF94A3B8), size: 18),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Botón directo de cerrar sesión
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: const Icon(Icons.logout_rounded, size: 20, color: Color(0xFF94A3B8)),
                onPressed: _confirmarCerrarSesion,
              ),
              const SizedBox(width: 14),
            ],
          ),
          body: IndexedStack(
            index: _currentIndex,
            children: [
              DashboardView(
                key: _dashboardKey,
                embedInShell: true,
              ),
              ComparativaView(
                onCargarEnDashboard: (id) => navegarYcargarAnalisis(id),
              ),
              const AudienciaView(),
              ConfiguracionView(
                usuarioActual: {
                  'nombre': nombreUsuario,
                  'rol': rolUsuario,
                  'correo': correoUsuario,
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavigationDrawer(bool isDark, String nombreUsuario, String rolUsuario) {
    final drawerBg = isDark ? const Color(0xFF0F172A) : _navy;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFF1E293B);

    return Drawer(
      backgroundColor: drawerBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header del Drawer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Facebook Pulse AI',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Menú de navegación',
                          style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                    tooltip: 'Ocultar menú',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text(
                'VISTAS DISPONIBLES',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[400],
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 4),

            _drawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Analizador & KPI',
              subtitle: 'Extracción en vivo y métricas',
              index: 0,
            ),
            _drawerItem(
              icon: Icons.compare_arrows_rounded,
              label: 'Historial & Comparativa',
              subtitle: 'Comparación lado a lado',
              index: 1,
            ),
            _drawerItem(
              icon: Icons.groups_rounded,
              label: 'Audiencia & Bots',
              subtitle: 'Auditoría de spam y usuarios',
              index: 2,
            ),
            _drawerItem(
              icon: Icons.tune_rounded,
              label: 'Configuración & Estado',
              subtitle: 'Tema, scraping y cuenta',
              index: 3,
            ),

            const Spacer(),

            // Tarjeta inferior de versión
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_rounded, size: 14, color: Color(0xFF10B981)),
                      SizedBox(width: 6),
                      Text(
                        'v2.5 - Arthur Edition',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Extracción autoritativa DOM y análisis de sentimientos Gemini.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required int index,
  }) {
    final isSelected = _currentIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() => _currentIndex = index);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(color: _primaryBlue.withValues(alpha: 0.5), width: 1.2)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? _primaryBlue : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryBlue,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
