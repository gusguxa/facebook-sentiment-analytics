import 'dart:async';
import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    // Navegar automáticamente a Login después de 2.2 segundos
    _navTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      final target = AppSettings.currentUserNotifier.value != null ? '/dashboard' : '/login';
      Navigator.pushReplacementNamed(context, target);
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppSettings.isDarkMode(context);
    final bgColor = isDark ? const Color(0xFF0B1120) : const Color(0xFF0F172A);
    final primaryTextColor = Colors.white;
    final secondaryTextColor = const Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono animado con efecto pulso de minería IA
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Halo exterior difuso
                    Container(
                      width: 140 * _pulseAnimation.value,
                      height: 140 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1877F2).withValues(alpha: 0.18),
                      ),
                    ),
                    // Halo medio
                    Container(
                      width: 110 * _pulseAnimation.value,
                      height: 110 * _pulseAnimation.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                      ),
                    ),
                    // Icono central elevado
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1877F2), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1877F2).withValues(alpha: 0.45),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 36),

            // Título de la Aplicación
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'Facebook Pulse AI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.6,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Minería de Datos & Análisis de Sentimientos con IA',
                    style: TextStyle(
                      fontSize: 14,
                      color: secondaryTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            // Barra de carga suave
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: const LinearProgressIndicator(
                  minHeight: 3.5,
                  backgroundColor: Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Cargando entorno analítico...',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor.withValues(alpha: 0.8),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
