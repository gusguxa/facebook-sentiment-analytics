import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/hover_scale_card.dart';

class AudienciaView extends StatefulWidget {
  const AudienciaView({super.key});

  @override
  State<AudienciaView> createState() => _AudienciaViewState();
}

class _AudienciaViewState extends State<AudienciaView> {
  bool _isLoading = false;
  Map<String, dynamic> _data = {};

  static const Color _navy = Color(0xFF0F172A);
  static const Color _primaryBlue = Color(0xFF1877F2);
  static const Color _positive = Color(0xFF10B981);
  static const Color _negative = Color(0xFFEF4444);
  static const Color _neutral = Color(0xFFF59E0B);
  static const Color _botColor = Color(0xFF9333EA);

  @override
  void initState() {
    super.initState();
    _cargarAudiencia();
  }

  Future<void> _cargarAudiencia() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.get(Uri.parse('http://127.0.0.1:5000/api/audiencia'));
      if (resp.statusCode == 200) {
        setState(() {
          _data = jsonDecode(resp.body);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pText = isDark ? const Color(0xFFF8FAFC) : _navy;
    final sText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final totales = _data['totales'] as Map<String, dynamic>? ?? {};
    final topComentaristas = (_data['top_comentaristas'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final bots = (_data['comentarios_bots'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final totalCom = totales['comentarios'] ?? 0;
    final totalBots = totales['bots'] ?? 0;
    final tasaBots = totales['tasa_bots_porcentaje']?.toString() ?? '0.0';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarAudiencia,
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
                              'Inteligencia de Audiencia & Detección de Bots',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: pText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Auditoría continua de usuarios frecuentes, perfiles sospechosos y patrones de spam',
                              style: TextStyle(fontSize: 14, color: sText),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _cargarAudiencia,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Actualizar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cardBg,
                            foregroundColor: pText,
                            elevation: 0,
                            side: BorderSide(color: borderCol),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tarjetas KPI de Auditoría
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Comentarios Auditados',
                            value: '$totalCom',
                            subtitle: 'En toda la base de datos',
                            icon: Icons.forum_rounded,
                            color: _primaryBlue,
                            isDark: isDark,
                            pText: pText,
                            sText: sText,
                            cardBg: cardBg,
                            borderCol: borderCol,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Bots y Spam Detectados',
                            value: '$totalBots',
                            subtitle: 'Identificados por Gemini IA',
                            icon: Icons.smart_toy_rounded,
                            color: _botColor,
                            isDark: isDark,
                            pText: pText,
                            sText: sText,
                            cardBg: cardBg,
                            borderCol: borderCol,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            title: 'Tasa de Ruido Artificial',
                            value: '$tasaBots%',
                            subtitle: totalBots > 0 ? 'Presencia detectada' : 'Audiencia 100% limpia',
                            icon: Icons.shield_rounded,
                            color: totalBots > 0 ? _negative : _positive,
                            isDark: isDark,
                            pText: pText,
                            sText: sText,
                            cardBg: cardBg,
                            borderCol: borderCol,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Layout 2 Columnas: Top Comentaristas + Feed de Bots
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth > 900;
                        return isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 5, child: _buildTopComentaristasSection(topComentaristas, isDark, pText, sText, cardBg, borderCol)),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 6, child: _buildBotsSection(bots, isDark, pText, sText, cardBg, borderCol)),
                                ],
                              )
                            : Column(
                                children: [
                                  _buildTopComentaristasSection(topComentaristas, isDark, pText, sText, cardBg, borderCol),
                                  const SizedBox(height: 24),
                                  _buildBotsSection(bots, isDark, pText, sText, cardBg, borderCol),
                                ],
                              );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required Color pText,
    required Color sText,
    required Color cardBg,
    required Color borderCol,
  }) {
    return HoverScaleCard(
      scaleFactor: 1.03,
      translateY: -3.0,
      cursor: SystemMouseCursors.click,
      padding: const EdgeInsets.all(20),
      baseDecoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      hoverDecoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.7), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.25 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sText),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: pText),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: sText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopComentaristasSection(
    List<Map<String, dynamic>> users,
    bool isDark,
    Color pText,
    Color sText,
    Color cardBg,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.leaderboard_rounded, color: _primaryBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Comentaristas Más Activos',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Usuarios con mayor frecuencia de interacción en publicaciones analizadas',
            style: TextStyle(fontSize: 12.5, color: sText),
          ),
          const SizedBox(height: 18),

          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No hay datos de usuarios disponibles', style: TextStyle(color: sText)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, __) => Divider(height: 18, color: borderCol),
              itemBuilder: (context, idx) {
                final u = users[idx];
                final name = u['usuario']?.toString() ?? 'Anónimo';
                final total = u['intervenciones'] ?? 0;
                final pos = u['pos'] ?? 0;
                final neg = u['neg'] ?? 0;
                final neu = u['neu'] ?? 0;
                final avatar = u['avatar_url']?.toString() ?? '';
                final isBot = (u['es_bot'] ?? 0) == 1;

                return Row(
                  children: [
                    Text(
                      '#${idx + 1}',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sText),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                      backgroundImage: (avatar.startsWith('http'))
                          ? NetworkImage('http://127.0.0.1:5000/api/avatar?url=${Uri.encodeComponent(avatar)}')
                          : null,
                      child: !avatar.startsWith('http')
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(fontWeight: FontWeight.bold, color: pText),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: pText),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isBot) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _botColor.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _botColor.withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    'BOT',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC084FC),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '$total comentario${total > 1 ? 's' : ''}',
                                style: TextStyle(fontSize: 11.5, color: sText),
                              ),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: sText)),
                              const SizedBox(width: 8),
                              Text('+$pos', style: const TextStyle(fontSize: 11, color: _positive, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Text('~$neu', style: const TextStyle(fontSize: 11, color: _neutral, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Text('-$neg', style: const TextStyle(fontSize: 11, color: _negative, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
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

  Widget _buildBotsSection(
    List<Map<String, dynamic>> bots,
    bool isDark,
    Color pText,
    Color sText,
    Color cardBg,
    Color borderCol,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _botColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.security_rounded, color: _botColor, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Centro de Detección de Bots y Spam',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: pText),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Comentarios marcados como artificiales con la justificación contextual de Gemini IA',
            style: TextStyle(fontSize: 12.5, color: sText),
          ),
          const SizedBox(height: 18),

          if (bots.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: _positive, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No se han detectado perfiles bots o spam en las publicaciones analizadas.',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final b = bots[idx];
                final user = b['usuario']?.toString() ?? 'Perfil Desconocido';
                final com = b['comentario']?.toString() ?? '';
                final motivo = b['motivo_bot']?.toString() ?? 'Patrón no orgánico';
                final avatar = b['avatar_url']?.toString() ?? '';

                return HoverScaleCard(
                  scaleFactor: 1.015,
                  translateY: -2.0,
                  padding: const EdgeInsets.all(14),
                  baseDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.35) : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFFE9D5FF),
                    ),
                  ),
                  hoverDecoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.55) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withValues(alpha: isDark ? 0.25 : 0.14),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            backgroundImage: (avatar.startsWith('http'))
                                ? NetworkImage('http://127.0.0.1:5000/api/avatar?url=${Uri.encodeComponent(avatar)}')
                                : null,
                            child: !avatar.startsWith('http')
                                ? Text(
                                    user.isNotEmpty ? user[0].toUpperCase() : '?',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: pText),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: pText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _botColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Sospechoso',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '"$com"',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF6B21A8).withValues(alpha: 0.5) : const Color(0xFFE9D5FF),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFC084FC)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Motivo: $motivo',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFFD8B4FE) : const Color(0xFF6B21A8),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
