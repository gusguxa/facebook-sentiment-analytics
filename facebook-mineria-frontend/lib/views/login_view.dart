import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/app_settings.dart';

enum AuthMode { login, register, forgotPassword }

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _formKey = GlobalKey<FormState>();
  final _forgotFormKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController(text: 'admin@empresa.com');
  final TextEditingController _passwordController = TextEditingController(text: '123456');

  // Controladores para recuperación de contraseña
  final TextEditingController _recoveryEmailController = TextEditingController();
  final TextEditingController _recoveryCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  AuthMode _authMode = AuthMode.login;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Clave de recuperación generada recibida del backend
  String? _codigoGenerado;

  static const Color _primaryBlue = Color(0xFF1877F2);
  static const Color _lightBlue = Color(0xFF38BDF8);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _recoveryEmailController.dispose();
    _recoveryCodeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _cambiarModo(AuthMode nuevoModo) {
    setState(() {
      _authMode = nuevoModo;
      _errorMessage = null;
      _successMessage = null;
      if (nuevoModo == AuthMode.forgotPassword && _emailController.text.isNotEmpty) {
        _recoveryEmailController.text = _emailController.text.trim();
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final isRegister = _authMode == AuthMode.register;
    final endpoint = isRegister ? '/api/registro' : '/api/login';
    final payload = isRegister
        ? {
            'nombre': _nameController.text.trim(),
            'correo': _emailController.text.trim(),
            'password': _passwordController.text,
            'rol': 'usuario',
          }
        : {
            'correo': _emailController.text.trim(),
            'password': _passwordController.text,
          };

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        final nombreUsuario = data['usuario']?['nombre'] ?? 'Usuario';
        final rolUsuario = data['usuario']?['rol'] ?? (isRegister ? 'usuario' : 'admin');
        final idUsuario = data['usuario']?['id'] ?? 1;

        final userMap = {
          'id': idUsuario,
          'nombre': nombreUsuario,
          'rol': rolUsuario,
          'correo': _emailController.text.trim(),
        };

        AppSettings.setCurrentUser(userMap);
        Navigator.pushReplacementNamed(
          context,
          '/dashboard',
          arguments: userMap,
        );
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'No se pudo completar la solicitud.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No fue posible conectar con el servidor backend (http://127.0.0.1:5000).';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _solicitarCodigoRecuperacion() async {
    final correo = _recoveryEmailController.text.trim();
    if (correo.isEmpty || !correo.contains('@')) {
      setState(() => _errorMessage = 'Ingresa un correo electrónico registrado válido.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/recuperar-password/solicitar'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'correo': correo}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _codigoGenerado = data['codigo_acceso'];
          _recoveryCodeController.text = _codigoGenerado ?? '';
          _successMessage = 'Clave generada con éxito. Úsala en el campo de código para restablecer.';
        });
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'No se encontró una cuenta con ese correo.';
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Error de conexión con el servidor al solicitar clave de acceso.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _reestablecerPassword() async {
    final correo = _recoveryEmailController.text.trim();
    final codigo = _recoveryCodeController.text.trim();
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (correo.isEmpty || !correo.contains('@')) {
      setState(() => _errorMessage = 'Ingresa tu correo electrónico registrado.');
      return;
    }
    if (codigo.isEmpty || codigo.length < 4) {
      setState(() => _errorMessage = 'Ingresa la clave o código de verificación recibido.');
      return;
    }
    if (newPass.length < 4) {
      setState(() => _errorMessage = 'La nueva contraseña debe tener al menos 4 caracteres.');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden. Verifícalas.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/api/recuperar-password/reestablecer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'correo': correo,
          'codigo': codigo,
          'nueva_password': newPass,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _emailController.text = correo;
          _passwordController.text = newPass;
          _authMode = AuthMode.login;
          _codigoGenerado = null;
          _recoveryCodeController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          _successMessage = '¡Contraseña restablecida correctamente! Ya puedes iniciar sesión.';
        });
      } else {
        setState(() {
          _errorMessage = data['error'] ?? 'El código es inválido o ha expirado.';
        });
      }
    } catch (_) {
      setState(() {
        _errorMessage = 'Error de conexión al restablecer contraseña.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.themeModeNotifier,
      builder: (context, currentMode, _) {
        final isDark = AppSettings.isDarkMode(context);

        // Colores dinámicos con máximo contraste
        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
        final pText = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
        final sText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
        final accent = isDark ? _lightBlue : _primaryBlue;

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
          body: Stack(
            children: [
              // Resplandores ambientales de fondo
              Positioned(
                top: -120,
                right: -100,
                child: Container(
                  width: 450,
                  height: 450,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFF1D4ED8) : const Color(0xFF3B82F6)).withValues(alpha: isDark ? 0.2 : 0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -100,
                child: Container(
                  width: 380,
                  height: 380,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isDark ? const Color(0xFF0D9488) : const Color(0xFF14B8A6)).withValues(alpha: isDark ? 0.15 : 0.08),
                  ),
                ),
              ),

              // Botón superior de Alternancia de Tema
              Positioned(
                top: 20,
                right: 24,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    tooltip: isDark ? 'Cambiar a Tema Claro' : 'Cambiar a Tema Oscuro',
                    icon: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      color: isDark ? const Color(0xFFFDE047) : const Color(0xFF334155),
                      size: 20,
                    ),
                    onPressed: () {
                      AppSettings.setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
                    },
                  ),
                ),
              ),

              // Tarjeta central de autenticación
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 490),
                    child: Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withValues(alpha: 0.5) : const Color(0xFF0F172A).withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _authMode == AuthMode.forgotPassword
                            ? _buildForgotPasswordView(isDark, cardBg, cardBorder, pText, sText, accent)
                            : _buildLoginOrRegisterView(isDark, cardBg, cardBorder, pText, sText, accent),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construye un campo de texto con encabezado de sección destacado, subtítulo explicativo, bordes de alto contraste y tipografía nítida
  Widget _buildField({
    required String labelTitle,
    required String helpSubtitle,
    required String hintText,
    required IconData prefixIcon,
    required TextEditingController controller,
    required bool isDark,
    required Color pText,
    required Color sText,
    required Color accent,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    // Fondo de campo en máximo contraste contra la tarjeta
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final inputBorder = isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. ENCABEZADO DE SECCIÓN: Indica claramente QUÉ ingresar
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.45) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.6) : const Color(0xFFBFDBFE),
                    width: 1.2,
                  ),
                ),
                child: Icon(prefixIcon, size: 16, color: accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      labelTitle.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: pText,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      helpSubtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: sText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // 2. CAMPO DE ENTRADA CON MÁXIMO CONTRASTE
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            color: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A),
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: obscureText ? 2.5 : 0.3,
          ),
          cursorColor: accent,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              fontSize: 13.5,
              fontWeight: FontWeight.normal,
              letterSpacing: 0,
            ),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            suffixIcon: suffixIcon,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: inputBorder, width: 1.8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: accent, width: 2.4),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.8),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2.4),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildLoginOrRegisterView(
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color pText,
    Color sText,
    Color accent,
  ) {
    final isRegister = _authMode == AuthMode.register;

    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey<bool>(isRegister),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encabezado con Icono
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Facebook Pulse AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: pText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isRegister
                          ? 'Crear nueva cuenta de usuario'
                          : 'Minería & Análisis de Sentimientos',
                      style: TextStyle(fontSize: 13, color: sText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Banner distintivo indicando el tipo de formulario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(isRegister ? Icons.person_add_alt_1_rounded : Icons.login_rounded, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isRegister
                        ? 'CREAR CUENTA • INGRESA TUS DATOS'
                        : 'INICIO DE SESIÓN • INTRODUCE TUS CREDENCIALES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Banner de Éxito
          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Banner de Error
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CAMPO 1: NOMBRE COMPLETO (Solo en modo registro)
          if (isRegister) ...[
            _buildField(
              labelTitle: 'Nombre Completo',
              helpSubtitle: 'Ingresa aquí tu nombre y apellido',
              hintText: 'Ej. Carlos Gómez',
              prefixIcon: Icons.person_rounded,
              controller: _nameController,
              isDark: isDark,
              pText: pText,
              sText: sText,
              accent: accent,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tu nombre completo' : null,
            ),
            const SizedBox(height: 18),
          ],

          // CAMPO 2: CORREO ELECTRÓNICO
          _buildField(
            labelTitle: 'Correo Electrónico',
            helpSubtitle: isRegister
                ? 'Ingresa aquí el correo con el que iniciarás sesión'
                : 'Ingresa aquí tu correo de usuario registrado',
            hintText: 'ejemplo: admin@empresa.com',
            prefixIcon: Icons.alternate_email_rounded,
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa un correo electrónico corporativo válido' : null,
          ),

          const SizedBox(height: 18),

          // CAMPO 3: CONTRASEÑA DE ACCESO
          _buildField(
            labelTitle: isRegister ? 'Crear Contraseña' : 'Contraseña de Acceso',
            helpSubtitle: isRegister
                ? 'Define una contraseña segura (mínimo 4 caracteres)'
                : 'Ingresa aquí tu contraseña secreta de acceso',
            hintText: 'Escribe tu contraseña secreta',
            prefixIcon: Icons.lock_rounded,
            controller: _passwordController,
            obscureText: _obscurePassword,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: sText,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) => (v == null || v.length < 4) ? 'La contraseña debe tener al menos 4 caracteres' : null,
          ),

          if (isRegister) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Las nuevas cuentas se crean con rol de Consulta (lectura y análisis de publicaciones). Las opciones administrativas quedan reservadas.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E40AF),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Botón Principal (Iniciar Sesión / Registrarme)
          ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: isDark ? 2 : 1,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(
                    isRegister ? 'Registrarme / Crear cuenta' : 'Iniciar Sesión',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                  ),
          ),

          const SizedBox(height: 16),

          // 1. Registrarme / Crear cuenta (directamente debajo del login)
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                foregroundColor: accent,
              ),
              onPressed: () => _cambiarModo(isRegister ? AuthMode.login : AuthMode.register),
              child: Text(
                isRegister
                    ? '¿Ya tienes una cuenta? Iniciar Sesión'
                    : '¿No tienes cuenta? Registrarme / Crear cuenta',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

          // 2. Debajo de esta: Olvidé mi contraseña
          Center(
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                foregroundColor: sText,
              ),
              onPressed: () => _cambiarModo(AuthMode.forgotPassword),
              child: Text(
                '¿Olvidaste tu contraseña? Recuperar clave de acceso',
                style: TextStyle(
                  color: sText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),

          const Divider(height: 28, color: Color(0xFF334155)),

          // Cuentas de demostración
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 8),
                        Text(
                          'Admin: admin@empresa.com',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pText),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _emailController.text = 'admin@empresa.com';
                          _passwordController.text = '123456';
                          _authMode = AuthMode.login;
                        });
                      },
                      child: Text(
                        'Cargar Admin',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Text(
                          'Lector: carlos@empresa.com',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pText),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _emailController.text = 'carlos@empresa.com';
                          _passwordController.text = 'newsecretpassword456';
                          _authMode = AuthMode.login;
                        });
                      },
                      child: Text(
                        'Cargar Lector',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: accent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForgotPasswordView(
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color pText,
    Color sText,
    Color accent,
  ) {
    return Form(
      key: _forgotFormKey,
      child: Column(
        key: const ValueKey<String>('forgotPassword'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.lock_reset_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recuperar Contraseña',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: pText,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acceso mediante correo electrónico',
                      style: TextStyle(fontSize: 13, color: sText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_key_rounded, size: 18, color: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'RESTABLECER ACCESO • SIGUE LOS PASOS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(_errorMessage!, style: TextStyle(color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_successMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      style: TextStyle(
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CORREO ELECTRÓNICO REGISTRADO
          _buildField(
            labelTitle: 'Correo Registrado',
            helpSubtitle: 'Ingresa aquí el correo vinculado a tu cuenta',
            hintText: 'Ingresa tu correo aquí',
            prefixIcon: Icons.alternate_email_rounded,
            controller: _recoveryEmailController,
            keyboardType: TextInputType.emailAddress,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            suffixIcon: IconButton(
              tooltip: 'Generar clave de acceso por correo',
              icon: Icon(Icons.send_rounded, size: 20, color: accent),
              onPressed: _isLoading ? null : _solicitarCodigoRecuperacion,
            ),
            validator: (v) => (v == null || !v.contains('@')) ? 'Ingresa el correo registrado' : null,
          ),

          const SizedBox(height: 16),

          // Botón para solicitar clave si aún no se ha generado
          if (_codigoGenerado == null) ...[
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _solicitarCodigoRecuperacion,
              icon: const Icon(Icons.vpn_key_rounded, size: 18),
              label: const Text('Solicitar clave o código de acceso'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Si ya hay código generado, mostrar banner con la clave
          if (_codigoGenerado != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_rounded, color: accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Clave de seguridad generada:',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _codigoGenerado!,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                            color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _recoveryCodeController.text = _codigoGenerado!;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    child: const Text('Llenar', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // CAMPO CLAVE O CÓDIGO DE 6 DÍGITOS
          _buildField(
            labelTitle: 'Código de 6 Dígitos',
            helpSubtitle: 'Ingresa aquí la clave generada para verificar tu identidad',
            hintText: 'Ej. 123456',
            prefixIcon: Icons.pin_rounded,
            controller: _recoveryCodeController,
            keyboardType: TextInputType.number,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            validator: (v) => (v == null || v.trim().length < 4) ? 'Ingresa la clave de verificación' : null,
          ),

          const SizedBox(height: 16),

          // CAMPO NUEVA CONTRASEÑA
          _buildField(
            labelTitle: 'Nueva Contraseña',
            helpSubtitle: 'Ingresa aquí tu nueva clave secreta',
            hintText: 'Mínimo 4 caracteres',
            prefixIcon: Icons.lock_outline_rounded,
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: sText,
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            validator: (v) => (v == null || v.length < 4) ? 'Mínimo 4 caracteres' : null,
          ),

          const SizedBox(height: 16),

          // CAMPO CONFIRMAR NUEVA CONTRASEÑA
          _buildField(
            labelTitle: 'Confirmar Nueva Contraseña',
            helpSubtitle: 'Vuelve a escribir aquí la misma contraseña',
            hintText: 'Repite la nueva contraseña',
            prefixIcon: Icons.lock_reset_rounded,
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            isDark: isDark,
            pText: pText,
            sText: sText,
            accent: accent,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: sText,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Confirma tu contraseña' : null,
          ),

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isLoading ? null : _reestablecerPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF1877F2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 17),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: isDark ? 2 : 1,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Restablecer Contraseña',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),

          const SizedBox(height: 16),

          Center(
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: accent,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () => _cambiarModo(AuthMode.login),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Volver al Inicio de Sesión',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
