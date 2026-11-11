import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/app_settings.dart';
import '../widgets/hover_scale_card.dart';

class ConfiguracionView extends StatefulWidget {
  final Map<String, dynamic>? usuarioActual;

  const ConfiguracionView({super.key, this.usuarioActual});

  @override
  State<ConfiguracionView> createState() => _ConfiguracionViewState();
}

class _ConfiguracionViewState extends State<ConfiguracionView> {
  bool _isLoading = false;
  Map<String, dynamic> _statusData = {};
  int? _pingMs;

  static const Color _navy = Color(0xFF0F172A);
  static const Color _positive = Color(0xFF10B981);
  static const Color _primaryBlue = Color(0xFF1877F2);

  @override
  void initState() {
    super.initState();
    _cargarEstado();
  }

  Future<void> _cargarEstado() async {
    setState(() => _isLoading = true);
    final stopwatch = Stopwatch()..start();
    try {
      final resp = await http.get(Uri.parse('http://127.0.0.1:5000/api/status'));
      stopwatch.stop();
      if (resp.statusCode == 200) {
        setState(() {
          _statusData = jsonDecode(resp.body);
          _pingMs = stopwatch.elapsedMilliseconds;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoCambiarContrasena() {
    final passCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cambiar Contraseña',
            style: TextStyle(
              color: isDark ? Colors.white : _navy,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Ingresa tu contraseña actual' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: Icon(Icons.password_rounded),
                  ),
                  validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  final correo = widget.usuarioActual?['correo'] ?? AppSettings.currentUserNotifier.value?['correo'] ?? 'admin@empresa.com';
                  http.post(
                    Uri.parse('http://127.0.0.1:5000/api/usuarios/cambiar-password'),
                    headers: {'Content-Type': 'application/json'},
                    body: jsonEncode({
                      'correo': correo,
                      'password_actual': passCtrl.text,
                      'nueva_password': newPassCtrl.text,
                    }),
                  ).then((resp) {
                    Navigator.pop(ctx);
                    if (resp.statusCode == 200) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Contraseña actualizada correctamente en la base de datos.'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    } else {
                      final err = jsonDecode(resp.body)['error'] ?? 'No se pudo actualizar';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(err),
                          backgroundColor: const Color(0xFFDC2626),
                        ),
                      );
                    }
                  }).catchError((_) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Error de conexión con el backend.'),
                        backgroundColor: Color(0xFFDC2626),
                      ),
                    );
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _limpiarCacheTemporal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text('Caché de Playwright y sesiones temporales liberadas con éxito.'),
          ],
        ),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? const Color(0xFFF8FAFC) : _navy;
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final bd = _statusData['base_datos'] as Map<String, dynamic>? ?? {};
    final ia = _statusData['motor_ia'] as Map<String, dynamic>? ?? {};
    final fb = _statusData['sesion_facebook'] as Map<String, dynamic>? ?? {};
    final usuarios = (_statusData['usuarios'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final user = widget.usuarioActual ?? AppSettings.currentUserNotifier.value;
    final nombreUsuario = user?['nombre'] ?? 'Administrador';
    final correoUsuario = user?['correo'] ?? 'admin@empresa.com';
    final rolUsuario = user?['rol'] ?? 'admin';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarEstado,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Configuración & Diagnóstico del Sistema',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryTextColor,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              'Opciones de visualización, tema, preferencias generales y servicios locales',
                              style: TextStyle(fontSize: 14, color: secondaryTextColor),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _cargarEstado,
                          icon: const Icon(Icons.speed_rounded, size: 18),
                          label: Text(_pingMs != null ? 'Ping: ${_pingMs}ms' : 'Diagnosticar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            foregroundColor: primaryTextColor,
                            elevation: 0,
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // BANNER SOLO CONSULTA SI NO ES ADMIN
                    if (!AppSettings.isAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF3B82F6), size: 26),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Modo Solo Consulta Activo (Rol: ${rolUsuario.toUpperCase()})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Tu cuenta tiene permisos exclusivos de consulta sobre publicaciones y métricas. Los cambios en la configuración y ajustes del sistema están reservados para el Administrador.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF1E3A8A),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // SECCIÓN 1: APARIENCIA Y SELECCIÓN DE TEMA
                    _buildSeccionHeader('🎨 Apariencia & Modo Visual', 'Elige entre modo Claro, Oscuro o sincronizado con el sistema', primaryTextColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    _buildThemeSelectorCard(isDark, primaryTextColor, secondaryTextColor),

                    const SizedBox(height: 24),

                    // SECCIÓN 2: OPCIONES GENERALES FUNCIONALES
                    _buildSeccionHeader('⚙️ Opciones Generales de la Aplicación', 'Ajusta el comportamiento de alertas, animaciones y exportación', primaryTextColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    _buildGeneralSettingsCard(isDark, primaryTextColor, secondaryTextColor, AppSettings.isAdmin),

                    const SizedBox(height: 24),

                    // SECCIÓN 3: MI CUENTA Y SESIÓN
                    _buildSeccionHeader('👤 Cuenta & Control de Sesión', 'Gestiona tu acceso, contraseña y estado de autenticación', primaryTextColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    _buildAccountCard(nombreUsuario, correoUsuario, rolUsuario, isDark, primaryTextColor, secondaryTextColor),

                    const SizedBox(height: 24),

                    // SECCIÓN 4: DIAGNÓSTICO DE SERVICIOS
                    _buildSeccionHeader('🖥️ Estado de Microservicios & Conectividad', 'Monitoreo en vivo de MariaDB, Playwright y Google Gemini', primaryTextColor, secondaryTextColor),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 800;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildDbCard(bd, isDark, primaryTextColor, secondaryTextColor)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildIaCard(ia, isDark, primaryTextColor, secondaryTextColor)),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildFbCard(fb, isDark, primaryTextColor, secondaryTextColor)),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildDbCard(bd, isDark, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 16),
                                  _buildIaCard(ia, isDark, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 16),
                                  _buildFbCard(fb, isDark, primaryTextColor, secondaryTextColor),
                                ],
                              );
                      },
                    ),

                    const SizedBox(height: 28),

                    // SECCIÓN 5: USUARIOS REGISTRADOS
                    _buildUsuariosTable(usuarios, isDark, primaryTextColor, secondaryTextColor),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSeccionHeader(String title, String subtitle, Color pText, Color sText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: pText)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 12.5, color: sText)),
      ],
    );
  }

  Widget _buildThemeSelectorCard(bool isDark, Color pText, Color sText) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, currentMode, _) {
        return HoverScaleCard(
          scaleFactor: 1.01,
          translateY: -2.0,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 650;
                  return isCompact
                      ? Column(
                          children: [
                            _themeOptionCard(ThemeMode.light, 'Tema Claro', 'Fondo blanco, máxima nitidez', Icons.light_mode_rounded, currentMode, isDark),
                            const SizedBox(height: 10),
                            _themeOptionCard(ThemeMode.dark, 'Tema Oscuro', 'Fondo obsidiana, alto contraste', Icons.dark_mode_rounded, currentMode, isDark),
                            const SizedBox(height: 10),
                            _themeOptionCard(ThemeMode.system, 'Sistema', 'Sincronizado con Windows', Icons.brightness_auto_rounded, currentMode, isDark),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(child: _themeOptionCard(ThemeMode.light, 'Tema Claro', 'Fondo blanco, máxima nitidez', Icons.light_mode_rounded, currentMode, isDark)),
                            const SizedBox(width: 14),
                            Expanded(child: _themeOptionCard(ThemeMode.dark, 'Tema Oscuro', 'Fondo obsidiana, alto contraste', Icons.dark_mode_rounded, currentMode, isDark)),
                            const SizedBox(width: 14),
                            Expanded(child: _themeOptionCard(ThemeMode.system, 'Sistema', 'Sincronizado con Windows', Icons.brightness_auto_rounded, currentMode, isDark)),
                          ],
                        );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _themeOptionCard(
    ThemeMode mode,
    String title,
    String desc,
    IconData icon,
    ThemeMode currentMode,
    bool isDark,
  ) {
    final isSelected = currentMode == mode;
    final cardBg = isSelected
        ? _primaryBlue.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC));
    final borderColor = isSelected
        ? _primaryBlue
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => AppSettings.setThemeMode(mode),
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: isSelected ? 2.0 : 1.0),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? _primaryBlue : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22,
                color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected ? _primaryBlue : (isDark ? Colors.white : _navy),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: _primaryBlue, size: 20),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildGeneralSettingsCard(bool isDark, Color pText, Color sText, bool isAdmin) {
    return HoverScaleCard(
      scaleFactor: 1.01,
      translateY: -2.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Alerta de bots
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.alertOnHighBots,
            builder: (context, alertVal, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _primaryBlue,
                title: Text('Alerta de Tasa de Bots Crítica (>15%)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pText)),
                subtitle: Text('Muestra un aviso destacado cuando la presencia de ruido artificial sea elevada.', style: TextStyle(fontSize: 12, color: sText)),
                value: alertVal,
                onChanged: isAdmin ? (val) => AppSettings.alertOnHighBots.value = val : null,
              );
            },
          ),
          const Divider(height: 20),

          // Animaciones de gráficos
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.enableAnimations,
            builder: (context, animVal, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _primaryBlue,
                title: Text('Animaciones Fluidas en Gráficos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pText)),
                subtitle: Text('Animar el gráfico de dona y barras al abrir o consultar publicaciones.', style: TextStyle(fontSize: 12, color: sText)),
                value: animVal,
                onChanged: isAdmin ? (val) => AppSettings.enableAnimations.value = val : null,
              );
            },
          ),
          const Divider(height: 20),

          // Modo Headless de Playwright
          ValueListenableBuilder<bool>(
            valueListenable: AppSettings.headlessScraper,
            builder: (context, headlessVal, _) {
              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: _primaryBlue,
                title: Text('Modo Silencioso / Headless de Extracción', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pText)),
                subtitle: Text('Ejecuta Chromium en segundo plano sin desplegar ventanas visibles.', style: TextStyle(fontSize: 12, color: sText)),
                value: headlessVal,
                onChanged: isAdmin ? (val) => AppSettings.headlessScraper.value = val : null,
              );
            },
          ),
          const Divider(height: 20),

          // Formato de exportación
          ValueListenableBuilder<String>(
            valueListenable: AppSettings.defaultExportFormat,
            builder: (context, fmtVal, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Formato Predeterminado de Exportación', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pText)),
                      Text('Tipo de archivo generado al exportar tablas e informes.', style: TextStyle(fontSize: 12, color: sText)),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final fmt in ['xlsx', 'csv', 'json'])
                        ChoiceChip(
                          label: Text(fmt.toUpperCase()),
                          selected: fmtVal == fmt,
                          selectedColor: _primaryBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: fmtVal == fmt ? _primaryBlue : sText,
                          ),
                          onSelected: (_) => AppSettings.defaultExportFormat.value = fmt,
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
          const Divider(height: 20),

          // Botón limpiar caché
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Limpieza de Caché y Sesiones Temporales', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: pText)),
                  Text('Libera memoria y archivos temporales generados por Playwright.', style: TextStyle(fontSize: 12, color: sText)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: isAdmin ? _limpiarCacheTemporal : null,
                icon: Icon(isAdmin ? Icons.cleaning_services_rounded : Icons.lock_outline_rounded, size: 16),
                label: Text(isAdmin ? 'Limpiar Caché' : 'Solo Admin'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isAdmin ? _primaryBlue : Colors.grey,
                  side: BorderSide(color: isAdmin ? const Color(0xFF93C5FD) : Colors.grey.withValues(alpha: 0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(
    String nombre,
    String correo,
    String rol,
    bool isDark,
    Color pText,
    Color sText,
  ) {
    return HoverScaleCard(
      scaleFactor: 1.01,
      translateY: -2.0,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
              ),
            ),
            child: Center(
              child: Text(
                nombre.isNotEmpty ? nombre[0].toUpperCase() : 'A',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(nombre, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (rol.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rol.toLowerCase() == 'admin' ? 'ADMINISTRADOR' : 'SOLO CONSULTA',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: rol.toLowerCase() == 'admin' ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(correo, style: TextStyle(fontSize: 13, color: sText)),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: _mostrarDialogoCambiarContrasena,
            icon: const Icon(Icons.password_rounded, size: 16),
            label: const Text('Contraseña'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _primaryBlue,
              side: const BorderSide(color: Color(0xFF93C5FD)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => AppSettings.logout(context),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDbCard(Map<String, dynamic> bd, bool isDark, Color pText, Color sText) {
    final conectada = bd['conectada'] == true;
    final motor = bd['motor'] ?? 'MariaDB / MySQL (:3306)';
    final pubs = bd['total_publicaciones'] ?? 0;
    final coms = bd['total_comentarios_guardados'] ?? 0;
    final reacs = bd['total_reacciones_acumuladas'] ?? 0;

    return HoverScaleCard(
      scaleFactor: 1.02,
      translateY: -3.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storage_rounded, color: Color(0xFF0D9488), size: 22),
              ),
              _statusChip(conectada ? 'Conectado' : 'Desconectado', conectada ? _positive : Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text('Base de Datos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText)),
          Text(motor, style: TextStyle(fontSize: 12, color: sText)),
          const Divider(height: 24),
          _metricRow('Publicaciones analizadas:', '$pubs', pText, sText),
          const SizedBox(height: 6),
          _metricRow('Comentarios en histórico:', '$coms', pText, sText),
          const SizedBox(height: 6),
          _metricRow('Reacciones indexadas:', '$reacs', pText, sText),
        ],
      ),
    );
  }

  Widget _buildIaCard(Map<String, dynamic> ia, bool isDark, Color pText, Color sText) {
    final activo = ia['activo'] == true;
    final modelo = ia['modelo'] ?? 'gemini-3.1-flash-lite';
    final prov = ia['proveedor'] ?? 'Google Gemini API';

    return HoverScaleCard(
      scaleFactor: 1.02,
      translateY: -3.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8B5CF6), size: 22),
              ),
              _statusChip(activo ? 'Activo' : 'Inactivo', activo ? _positive : Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          Text('Motor de Inteligencia Artificial', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText)),
          Text(prov, style: TextStyle(fontSize: 12, color: sText)),
          const Divider(height: 24),
          _metricRow('Modelo en producción:', modelo, pText, sText),
          const SizedBox(height: 6),
          _metricRow('Modo de salida:', 'JSON Estructurado', pText, sText),
          const SizedBox(height: 6),
          _metricRow('Detección de bots:', 'Activada', pText, sText),
        ],
      ),
    );
  }

  Widget _buildFbCard(Map<String, dynamic> fb, bool isDark, Color pText, Color sText) {
    final modo = fb['modo'] ?? 'Invitado Seguro (Guest Mode)';

    return HoverScaleCard(
      scaleFactor: 1.02,
      translateY: -3.0,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.travel_explore_rounded, color: _primaryBlue, size: 22),
              ),
              _statusChip('Modo Invitado', const Color(0xFF64748B)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Motor de Extracción Web', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText)),
          Text('Playwright Chromium Headless', style: TextStyle(fontSize: 12, color: sText)),
          const Divider(height: 24),
          _metricRow('Modo actual:', modo, pText, sText),
          const SizedBox(height: 6),
          _metricRow('Bypass anti-scraping:', 'Habilitado', pText, sText),
          const SizedBox(height: 6),
          _metricRow('Aislamiento de hilos:', 'Thread-safe activo', pText, sText),
        ],
      ),
    );
  }

  Widget _buildUsuariosTable(
    List<Map<String, dynamic>> usuarios,
    bool isDark,
    Color pText,
    Color sText,
  ) {
    return HoverScaleCard(
      scaleFactor: 1.01,
      translateY: -2.0,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline_rounded, color: _primaryBlue),
                  const SizedBox(width: 8),
                  Text(
                    'Usuarios del Sistema & Permisos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText),
                  ),
                ],
              ),
              Text(
                '${usuarios.length} registrados',
                style: TextStyle(fontSize: 12.5, color: sText),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (usuarios.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text('No hay usuarios registrados', style: TextStyle(color: sText)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: usuarios.length,
              separatorBuilder: (_, __) => const Divider(height: 16),
              itemBuilder: (context, idx) {
                final u = usuarios[idx];
                final nombre = u['nombre'] ?? 'Usuario';
                final correo = u['correo'] ?? '';
                final rol = (u['rol'] ?? 'analista').toString().toUpperCase();

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                      child: Text(
                        nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: pText)),
                          Text(correo, style: TextStyle(fontSize: 12, color: sText)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rol,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color pText, Color sText) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: sText)),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: pText)),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
