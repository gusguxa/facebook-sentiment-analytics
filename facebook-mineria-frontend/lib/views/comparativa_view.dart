import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../services/app_settings.dart';
import '../widgets/hover_scale_card.dart';

class ComparativaView extends StatefulWidget {
  final Function(int idAnalisis)? onCargarEnDashboard;

  const ComparativaView({super.key, this.onCargarEnDashboard});

  @override
  State<ComparativaView> createState() => _ComparativaViewState();
}

class _ComparativaViewState extends State<ComparativaView> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _posts = [];
  final Set<int> _selectedIds = {};
  String _filtroTexto = '';

  static const Color _navy = Color(0xFF0F172A);
  static const Color _primaryBlue = Color(0xFF1877F2);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _positive = Color(0xFF10B981);
  static const Color _negative = Color(0xFFEF4444);
  static const Color _neutral = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);
    try {
      final resp = await http.get(Uri.parse('http://127.0.0.1:5000/api/historial'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final list = (data['historial'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _posts = list;
          if (_posts.length >= 2 && _selectedIds.isEmpty) {
            _selectedIds.add(_posts[0]['id']);
            _selectedIds.add(_posts[1]['id']);
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _eliminarPost(int id) async {
    if (!AppSettings.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso restringido: Solo las cuentas de Administrador pueden eliminar publicaciones.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Text(
          'Eliminar análisis',
          style: TextStyle(color: isDark ? Colors.white : _navy, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar este análisis del historial?',
          style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _negative, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await http.delete(Uri.parse('http://127.0.0.1:5000/api/historial/$id'), headers: {'X-User-Role': AppSettings.currentUserNotifier.value?['rol'] ?? 'usuario'});
      _selectedIds.remove(id);
      _cargarHistorial();
    } catch (_) {}
  }

  void _descargarExcel(int id) async {
    final url = Uri.parse('http://127.0.0.1:5000/api/exportar/$id');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pText = isDark ? const Color(0xFFF8FAFC) : _navy;
    final sText = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final postsFiltrados = _posts.where((p) {
      final url = (p['url_post'] ?? '').toString().toLowerCase();
      final fecha = (p['fecha_analisis'] ?? '').toString().toLowerCase();
      return url.contains(_filtroTexto.toLowerCase()) || fecha.contains(_filtroTexto.toLowerCase());
    }).toList();

    final postsComparados = _posts.where((p) => _selectedIds.contains(p['id'])).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarHistorial,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header de sección
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historial & Comparativa de Publicaciones',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: pText,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compara el engagement, sentimiento y detección de bots entre 2 o más publicaciones',
                              style: TextStyle(fontSize: 14, color: sText),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: _cargarHistorial,
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

                    // Panel de Comparativa si hay 2 o más seleccionados
                    if (postsComparados.length >= 2) ...[
                      _buildComparisonPanel(postsComparados, isDark, pText, sText, cardBg, borderCol),
                      const SizedBox(height: 28),
                    ],

                    // Barra de búsqueda y contador
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _filtroTexto = v),
                            style: TextStyle(color: pText),
                            decoration: InputDecoration(
                              hintText: 'Buscar por URL o fecha de análisis...',
                              hintStyle: TextStyle(color: sText, fontSize: 13),
                              prefixIcon: Icon(Icons.search, size: 20, color: sText),
                              filled: true,
                              fillColor: cardBg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: borderCol),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: _primaryBlue, width: 1.6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderCol),
                          ),
                          child: Text(
                            '${postsComparados.length} seleccionados para comparar',
                            style: TextStyle(fontWeight: FontWeight.w600, color: pText, fontSize: 13),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Lista / Tabla de publicaciones
                    if (postsFiltrados.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderCol),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.inbox_rounded, size: 48, color: sText),
                              const SizedBox(height: 12),
                              Text(
                                'No hay publicaciones en el historial',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: pText),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ingresa una URL en el Dashboard para comenzar a analizar contenido.',
                                style: TextStyle(color: sText, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: postsFiltrados.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final post = postsFiltrados[index];
                          final id = post['id'] as int;
                          final isSelected = _selectedIds.contains(id);

                          return _buildPostCard(post, isSelected, isDark, pText, sText, cardBg, borderCol);
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildComparisonPanel(
    List<Map<String, dynamic>> posts,
    bool isDark,
    Color pText,
    Color sText,
    Color cardBg,
    Color borderCol,
  ) {
    int maxLikes = 1;
    int maxCom = 1;
    for (var p in posts) {
      if ((p['total_likes'] ?? 0) > maxLikes) maxLikes = p['total_likes'];
      if ((p['total_comentarios'] ?? 0) > maxCom) maxCom = p['total_comentarios'];
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded, color: _accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Cuadro Comparativo Directo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: pText),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedIds.clear()),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Limpiar selección'),
                style: TextButton.styleFrom(foregroundColor: sText),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Tarjetas de comparativa en Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: posts
                          .map((p) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _buildComparisonColumn(p, maxLikes, maxCom, isDark, pText, sText, borderCol),
                                ),
                              ))
                          .toList(),
                    )
                  : Column(
                      children: posts
                          .map((p) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _buildComparisonColumn(p, maxLikes, maxCom, isDark, pText, sText, borderCol),
                              ))
                          .toList(),
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonColumn(
    Map<String, dynamic> post,
    int maxLikes,
    int maxCom,
    bool isDark,
    Color pText,
    Color sText,
    Color borderCol,
  ) {
    final likes = post['total_likes'] ?? 0;
    final com = post['total_comentarios'] ?? 0;
    final shares = post['total_compartidos'] ?? 0;
    final bots = post['total_bots'] ?? 0;
    final pos = (post['positivos'] ?? 0).toDouble();
    final neg = (post['negativos'] ?? 0).toDouble();
    final neu = (post['neutros'] ?? 0).toDouble();
    final url = (post['url_post'] ?? '').toString();

    final colBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final colHover = isDark ? const Color(0xFF1E293B) : Colors.white;

    return HoverScaleCard(
      scaleFactor: 1.02,
      translateY: -3.0,
      padding: const EdgeInsets.all(16),
      baseDecoration: BoxDecoration(
        color: colBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      hoverDecoration: BoxDecoration(
        color: colHover,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryBlue.withValues(alpha: 0.7), width: 1.6),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 16, color: _primaryBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  url,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: pText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            post['fecha_analisis']?.toString() ?? '',
            style: TextStyle(fontSize: 11, color: sText),
          ),
          const SizedBox(height: 14),

          // Barras de progreso de engagement
          _barIndicator('Reacciones:', likes, maxLikes, _primaryBlue, pText, sText, borderCol),
          const SizedBox(height: 8),
          _barIndicator('Comentarios:', com, maxCom, Colors.indigoAccent, pText, sText, borderCol),
          const SizedBox(height: 8),
          _barIndicator('Compartidos:', shares, maxLikes > 10 ? maxLikes ~/ 2 : 10, Colors.teal, pText, sText, borderCol),
          const SizedBox(height: 8),
          _barIndicator('Cuentas Bot:', bots, maxCom > 5 ? maxCom : 5, Colors.purpleAccent, pText, sText, borderCol),

          const SizedBox(height: 14),
          Text('Sentimiento de la audiencia:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: sText)),
          const SizedBox(height: 6),

          // Barra tricolor de sentimiento
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  if (pos > 0) Expanded(flex: pos.toInt(), child: Container(color: _positive)),
                  if (neu > 0) Expanded(flex: neu.toInt(), child: Container(color: _neutral)),
                  if (neg > 0) Expanded(flex: neg.toInt(), child: Container(color: _negative)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Pos: ${pos.toInt()}%', style: const TextStyle(fontSize: 10.5, color: _positive, fontWeight: FontWeight.bold)),
              Text('Neu: ${neu.toInt()}%', style: const TextStyle(fontSize: 10.5, color: _neutral, fontWeight: FontWeight.bold)),
              Text('Neg: ${neg.toInt()}%', style: const TextStyle(fontSize: 10.5, color: _negative, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barIndicator(String label, int val, int max, Color color, Color pText, Color sText, Color borderCol) {
    final double ratio = max > 0 ? (val / max).clamp(0.02, 1.0) : 0.02;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: sText)),
            Text('$val', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pText)),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(height: 6, width: double.infinity, color: borderCol),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPostCard(
    Map<String, dynamic> post,
    bool isSelected,
    bool isDark,
    Color pText,
    Color sText,
    Color cardBg,
    Color borderCol,
  ) {
    final id = post['id'] as int;
    final url = post['url_post']?.toString() ?? 'Sin URL';
    final fecha = post['fecha_analisis']?.toString() ?? '';
    final likes = post['total_likes'] ?? 0;
    final com = post['total_comentarios'] ?? 0;
    final shares = post['total_compartidos'] ?? 0;
    final bots = post['total_bots'] ?? 0;
    final pos = post['positivos'] ?? 0;
    final neg = post['negativos'] ?? 0;

    final selectedBg = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
    final cardHoverBg = isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC);

    return HoverScaleCard(
      scaleFactor: 1.015,
      translateY: -2.0,
      cursor: SystemMouseCursors.basic,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      baseDecoration: BoxDecoration(
        color: isSelected ? selectedBg : cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? _primaryBlue : borderCol,
          width: isSelected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      hoverDecoration: BoxDecoration(
        color: isSelected ? selectedBg : cardHoverBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryBlue.withValues(alpha: 0.8),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            activeColor: _primaryBlue,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.add(id);
                } else {
                  _selectedIds.remove(id);
                }
              });
            },
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  url,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: pText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 12, color: sText),
                    const SizedBox(width: 4),
                    Text(fecha, style: TextStyle(fontSize: 11.5, color: sText)),
                    const SizedBox(width: 14),
                    _miniPill(Icons.thumb_up_alt_rounded, '$likes', Colors.blue, sText),
                    const SizedBox(width: 8),
                    _miniPill(Icons.chat_bubble_outline_rounded, '$com', Colors.indigoAccent, sText),
                    const SizedBox(width: 8),
                    _miniPill(Icons.share_rounded, '$shares', Colors.teal, sText),
                    if (bots > 0) ...[
                      const SizedBox(width: 8),
                      _miniPill(Icons.smart_toy_outlined, '$bots bots', Colors.purpleAccent, sText),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Píldora de sentimiento dominante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (pos >= 60 ? _positive : (neg >= 50 ? _negative : _neutral)).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (pos >= 60 ? _positive : (neg >= 50 ? _negative : _neutral)).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              pos >= 60 ? '$pos% Positivo' : (neg >= 50 ? '$neg% Crítica' : '$pos% Balanceado'),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: pos >= 60 ? _positive : (neg >= 50 ? _negative : _neutral),
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Acciones
          IconButton(
            tooltip: 'Descargar Excel',
            icon: const Icon(Icons.table_view_rounded, color: Colors.teal, size: 20),
            onPressed: () => _descargarExcel(id),
          ),
          IconButton(
            tooltip: 'Cargar en Dashboard',
            icon: const Icon(Icons.visibility_rounded, color: _primaryBlue, size: 20),
            onPressed: () {
              if (widget.onCargarEnDashboard != null) {
                widget.onCargarEnDashboard!(id);
              }
            },
          ),
          IconButton(
            tooltip: AppSettings.isAdmin ? 'Eliminar del historial' : 'Solo Administrador puede eliminar',
            icon: Icon(
              Icons.delete_outline_rounded,
              color: AppSettings.isAdmin ? Colors.redAccent : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
              size: 20,
            ),
            onPressed: AppSettings.isAdmin ? () => _eliminarPost(id) : null,
          ),
        ],
      ),
    );
  }

  Widget _miniPill(IconData icon, String text, Color color, Color sText) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: sText)),
      ],
    );
  }
}
