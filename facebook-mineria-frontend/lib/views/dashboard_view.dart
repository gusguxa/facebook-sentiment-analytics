import 'dart:async';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';

import 'package:http/http.dart' as http;

import 'package:url_launcher/url_launcher.dart';

import '../widgets/hover_scale_card.dart';
import '../services/app_settings.dart';



class DashboardView extends StatefulWidget {

  final bool embedInShell;



  const DashboardView({super.key, this.embedInShell = false});



  @override

  State<DashboardView> createState() => DashboardViewState();

}



class DashboardViewState extends State<DashboardView> with TickerProviderStateMixin {

  late AnimationController _chartAnimController;

  late Animation<double> _chartCurvedAnimation;

  void cargarAnalisisPorId(int id) {

    _seleccionarItemHistorial(id, cerrarDrawer: false);

  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final TextEditingController _urlController = TextEditingController();

  final TextEditingController _searchCommentController = TextEditingController();

  final ScrollController _mainScrollController = ScrollController();



  static const Color _headerNavy = Color(0xFF0F172A);

  static const Color _fbBlue = Color(0xFF1877F2);

  

  // static colors replaced with dynamic getters

  



  bool _isLoading = false;

  bool _hasAnalyzed = false;

  int _touchedIndex = -1;



  Timer? _loadingTimer;

  int _elapsedSeconds = 0;

  int _remainingSeconds = 25;

  double _progressValue = 0.0;

  String _loadingStageText = 'Preparando consulta...';



  int? _idAnalisis;

  String _contextoPost = '';

  String _contextoMultimedia = '';

  int _likes = 0;

  int _compartidos = 0;

  int _totalComentarios = 0;

  int _totalBots = 0;

  double _porcPositivo = 0;

  double _porcNegativo = 0;

  double _porcNeutro = 0;



  int _reacPositivo = 0;

  int _reacNegativo = 0;

  int _reacNeutro = 0;

  bool _meDivierteComoBurla = false;



  String _resumenIA = '';

  List<Map<String, dynamic>> _palabrasFrecuentes = [];

  List<Map<String, dynamic>> _reaccionesLista = [];

  List<Map<String, dynamic>> _comments = [];



  String _filtroReacciones = 'Todos';

  String _filtroSentimiento = 'Todos';

  String _busquedaTexto = '';

  List<Map<String, dynamic>> _historialList = [];

  bool _loadingHistorial = false;



  void _startLoadingTimer() {

    _loadingTimer?.cancel();

    _elapsedSeconds = 0;

    _remainingSeconds = 25;

    _progressValue = 0.06;

    _loadingStageText = 'Conectando con pestaña activa de Facebook...';



    _loadingTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {

      if (!mounted || !_isLoading) {

        timer.cancel();

        return;

      }

      try {

        final resp = await http.get(Uri.parse('http://127.0.0.1:5000/api/progreso'));

        if (resp.statusCode == 200 && mounted && _isLoading) {

          final data = jsonDecode(resp.body);

          setState(() {

            final int porc = data['porcentaje'] ?? 6;

            _progressValue = (porc / 100.0).clamp(0.02, 1.0);

            _loadingStageText = data['etapa'] ?? 'Procesando publicación...';

            _elapsedSeconds = data['tiempo_transcurrido'] ?? _elapsedSeconds;

            _remainingSeconds = data['tiempo_restante'] ?? 4;

          });

        }

      } catch (_) {}

    });

  }



  void _stopLoadingTimer() {

    _loadingTimer?.cancel();

    _loadingTimer = null;

  }



  @override

  void initState() {

    super.initState();

    _chartAnimController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1200),

    );

    _chartCurvedAnimation = CurvedAnimation(

      parent: _chartAnimController,

      curve: Curves.easeOutCubic,

    );

    _cargarHistorial();

  }



  @override

  void dispose() {

    _chartAnimController.dispose();

    _stopLoadingTimer();

    _urlController.dispose();

    _searchCommentController.dispose();

    super.dispose();

  }



  void _aplicarDatosRecibidos(Map<String, dynamic> data) {

    final reacSent = data['reacciones_sentimiento'] ?? {};

    setState(() {

      _progressValue = 1.0;

      _idAnalisis = data['id_analisis'];

      _contextoPost = data['contexto_post'] ?? '';

      _contextoMultimedia = data['contexto_multimedia'] ?? '';

      _likes = data['likes'] ?? 0;

      _compartidos = data['compartidos'] ?? 0;

      _totalComentarios = data['total_comentarios'] ?? 0;

      _totalBots = data['total_bots'] ?? 0;

      _porcPositivo = (data['porcentajes']['positivo'] ?? 0).toDouble();

      _porcNegativo = (data['porcentajes']['negativo'] ?? 0).toDouble();

      _porcNeutro = (data['porcentajes']['neutro'] ?? 0).toDouble();

      _reacPositivo = reacSent['positivo'] ?? 100;

      _reacNegativo = reacSent['negativo'] ?? 0;

      _reacNeutro = reacSent['neutro'] ?? 0;

      _meDivierteComoBurla = reacSent['me_divierte_como_burla'] ?? false;

      _resumenIA = data['resumen_ia'] ?? '';

      _palabrasFrecuentes = List<Map<String, dynamic>>.from(data['palabras_frecuentes'] ?? []);

      _reaccionesLista = List<Map<String, dynamic>>.from(data['reacciones_lista'] ?? []);

      _comments = List<Map<String, dynamic>>.from(data['comentarios'] ?? []);

      _filtroReacciones = 'Todos';

      _filtroSentimiento = 'Todos';

      _busquedaTexto = '';

      _searchCommentController.clear();

      _hasAnalyzed = true;

      _touchedIndex = -1;

    });

    _chartAnimController.reset();

    _chartAnimController.forward();

  }



  Future<void> _triggerAnalysis() async {

    final urlText = _urlController.text.trim();

    if (urlText.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Por favor pega un enlace válido de Facebook'),

          backgroundColor: Colors.orange,

        ),

      );

      return;

    }



    setState(() {

      _isLoading = true;

    });

    _startLoadingTimer();



    try {

      final response = await http.post(

        Uri.parse('http://127.0.0.1:5000/api/analizar'),

        headers: {'Content-Type': 'application/json'},

        body: jsonEncode({'url': urlText}),

      );



      final data = jsonDecode(response.body);

      if (!mounted) return;



      if (response.statusCode == 200) {

        _aplicarDatosRecibidos(data);

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text('Análisis finalizado en $_elapsedSeconds segundos'),

            backgroundColor: const Color(0xFF10B981),

          ),

        );

      } else {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(data['error'] ?? 'No fue posible analizar la publicación'),

            backgroundColor: const Color(0xFFE41E3F),

          ),

        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Error de conexión con el servidor local'),

          backgroundColor: Color(0xFFE41E3F),

        ),

      );

    } finally {

      _stopLoadingTimer();

      if (mounted) {

        setState(() {

          _isLoading = false;

        });

      }

    }

  }



  Future<void> _cargarHistorial() async {

    setState(() {

      _loadingHistorial = true;

    });

    try {

      final response = await http.get(Uri.parse('http://127.0.0.1:5000/api/historial'));

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        setState(() {

          _historialList = List<Map<String, dynamic>>.from(data['historial'] ?? []);

        });

        if (!_hasAnalyzed && _historialList.isNotEmpty) {

          final primerId = _historialList.first['id'] as int;

          _seleccionarItemHistorial(primerId, cerrarDrawer: false);

        }

      }

    } catch (_) {

    } finally {

      if (mounted) {

        setState(() {

          _loadingHistorial = false;

        });

      }

    }

  }



  Future<void> _seleccionarItemHistorial(int id, {bool cerrarDrawer = true}) async {

    if (cerrarDrawer && _scaffoldKey.currentState?.isDrawerOpen == true) {

      Navigator.pop(context);

    }

    setState(() {

      _isLoading = true;

    });

    try {

      final response = await http.get(Uri.parse('http://127.0.0.1:5000/api/historial/$id'));

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        _urlController.text = data['url_post'] ?? '';

        _aplicarDatosRecibidos(data);

      }

    } catch (_) {

    } finally {

      if (mounted) {

        setState(() {

          _isLoading = false;

        });

      }

    }

  }



  Future<void> _eliminarItemHistorial(int id) async {

    try {

      final response = await http.delete(Uri.parse('http://127.0.0.1:5000/api/historial/$id'));

      if (response.statusCode == 200) {

        _cargarHistorial();

      }

    } catch (_) {}

  }



  Future<void> _descargarExcel() async {

    if (_idAnalisis == null) return;

    final Uri url = Uri.parse('http://127.0.0.1:5000/api/exportar/$_idAnalisis');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('No se pudo abrir la descarga del archivo de Excel'),

          backgroundColor: Color(0xFFE41E3F),

        ),

      );

    }

  }



  Color get _pTextColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);

  Color get _sTextColor => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  Color get _bgAnalyticalDyn => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF4F6F9);

  Color get _borderDyn => Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);



  BoxDecoration _analyticalCardDecoration() {

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BoxDecoration(

      color: isDark ? const Color(0xFF1E293B) : Colors.white,

      borderRadius: BorderRadius.circular(14),

      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

      boxShadow: [

        BoxShadow(

          color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF0F172A).withValues(alpha: 0.05),

          blurRadius: 14,

          offset: const Offset(0, 4),

        ),

      ],

    );

  }



  Widget _buildUserAvatar(String username, String avatarUrl) {

    final inicial = username.isNotEmpty ? username[0].toUpperCase() : 'U';

    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) {

      final proxyUrl = 'http://127.0.0.1:5000/api/avatar?url=${Uri.encodeComponent(avatarUrl)}';

      return ClipOval(

        child: Image.network(

          proxyUrl,

          width: 30,

          height: 30,

          fit: BoxFit.cover,

          errorBuilder: (_, __, ___) => CircleAvatar(

            radius: 15,

            backgroundColor: const Color(0xFFE7F3FF),

            child: Text(

              inicial,

              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _fbBlue),

            ),

          ),

        ),

      );

    }

    return CircleAvatar(

      radius: 15,

      backgroundColor: const Color(0xFFE7F3FF),

      child: Text(

        inicial,

        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _fbBlue),

      ),

    );

  }



  List<Map<String, dynamic>> get _reaccionesFiltradas {

    return _reaccionesLista.where((item) {

      final sent = (item['sentiment'] ?? 'Neutro').toString();

      return _filtroReacciones == 'Todos' ||

          (_filtroReacciones == 'Positivos' && sent == 'Positivo') ||

          (_filtroReacciones == 'Negativos' && sent == 'Negativo') ||

          (_filtroReacciones == 'Neutros' && sent == 'Neutro');

    }).toList();

  }



  List<Map<String, dynamic>> get _comentariosFiltrados {

    return _comments.where((item) {

      final sent = (item['sentiment'] ?? 'Neutro').toString();

      final esBot = item['es_bot'] == true;

      final user = (item['username'] ?? '').toString().toLowerCase();

      final text = (item['comment'] ?? '').toString().toLowerCase();



      final pasaFiltro = _filtroSentimiento == 'Todos' ||

          (_filtroSentimiento == 'Positivos' && sent == 'Positivo') ||

          (_filtroSentimiento == 'Negativos' && sent == 'Negativo') ||

          (_filtroSentimiento == 'Neutros' && sent == 'Neutro') ||

          (_filtroSentimiento == 'Posibles bots' && esBot);



      final pasaBusqueda = _busquedaTexto.isEmpty ||

          user.contains(_busquedaTexto.toLowerCase()) ||

          text.contains(_busquedaTexto.toLowerCase());



      return pasaFiltro && pasaBusqueda;

    }).toList();

  }



  IconData _iconoPorReaccion(String nombre) {

    final n = nombre.toLowerCase();

    if (n.contains('encanta')) return Icons.favorite_rounded;

    if (n.contains('importa')) return Icons.volunteer_activism_rounded;

    if (n.contains('divierte')) return Icons.sentiment_very_satisfied_rounded;

    if (n.contains('asombra')) return Icons.sentiment_neutral_rounded;

    if (n.contains('entristece')) return Icons.sentiment_dissatisfied_rounded;

    if (n.contains('enoja')) return Icons.sentiment_very_dissatisfied_rounded;

    return Icons.thumb_up_alt_rounded;

  }



  Color _colorPorReaccion(String nombre) {

    final n = nombre.toLowerCase();

    if (n.contains('encanta') || n.contains('importa')) return const Color(0xFFE41E3F);

    if (n.contains('divierte') || n.contains('asombra')) return const Color(0xFFF59E0B);

    if (n.contains('entristece') || n.contains('enoja')) return const Color(0xFFDC2626);

    return _fbBlue;

  }





  void _irAComentarios() {

    if (_mainScrollController.hasClients) {

      _mainScrollController.animateTo(

        900,

        duration: const Duration(milliseconds: 600),

        curve: Curves.easeOutCubic,

      );

    }

  }



  void _filtrarBots() {

    setState(() {

      _filtroSentimiento = 'Posibles bots';

    });

    _irAComentarios();

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text('Filtrando comentarios: Mostrando los $_totalBots posibles bots detectados.'),

        backgroundColor: const Color(0xFFF59E0B),

        duration: const Duration(seconds: 2),

      ),

    );

  }



  void _mostrarModalReaccionesDetalladas() {

    showDialog(

      context: context,

      builder: (ctx) {

        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        final pText = isDark ? const Color(0xFFF8FAFC) : _pTextColor;

        final sText = isDark ? const Color(0xFF94A3B8) : _sTextColor;

        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;



        return AlertDialog(

          backgroundColor: cardBg,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: Row(

            children: [

              Container(

                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(

                  color: _fbBlue.withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: const Icon(Icons.thumb_up_alt_rounded, color: _fbBlue, size: 22),

              ),

              const SizedBox(width: 12),

              Text(

                'Desglose Completo de Reacciones',

                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: pText),

              ),

            ],

          ),

          content: SizedBox(

            width: 480,

            child: SingleChildScrollView(

              child: Column(

                mainAxisSize: MainAxisSize.min,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    'Total acumulado: $_likes reacciones indexadas directamente del DOM oficial de Facebook.',

                    style: TextStyle(fontSize: 13, color: sText),

                  ),

                  const SizedBox(height: 16),

                  // Agrupacion consolidada de reacciones

                  Builder(

                    builder: (context) {

                      final Map<String, int> conteoPorTipo = {};

                      final Map<String, String> sentPorTipo = {};

                      for (final item in _reaccionesLista) {

                        final tipo = item['reaccion']?.toString() ?? 'Me gusta';

                        conteoPorTipo[tipo] = (conteoPorTipo[tipo] ?? 0) + 1;

                        sentPorTipo[tipo] = item['sentiment']?.toString() ?? 'Positivo';

                      }

                      if (conteoPorTipo.isEmpty) {

                        conteoPorTipo['Me gusta'] = _likes;

                        sentPorTipo['Me gusta'] = 'Positivo';

                      }



                      return Column(

                        children: [

                          for (final entry in conteoPorTipo.entries) ...[

                            Padding(

                              padding: const EdgeInsets.symmetric(vertical: 4),

                              child: Row(

                                children: [

                                  Icon(_iconoPorReaccion(entry.key), size: 20, color: _colorPorReaccion(entry.key)),

                                  const SizedBox(width: 10),

                                  Expanded(

                                    child: Text(

                                      entry.key,

                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: pText),

                                    ),

                                  ),

                                  Text(

                                    '',

                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _fbBlue),

                                  ),

                                  const SizedBox(width: 10),

                                  Container(

                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),

                                    decoration: BoxDecoration(

                                      color: (sentPorTipo[entry.key] == 'Positivo'

                                              ? const Color(0xFF10B981)

                                              : (sentPorTipo[entry.key] == 'Negativo' ? const Color(0xFFE41E3F) : const Color(0xFF64748B)))

                                          .withValues(alpha: 0.12),

                                      borderRadius: BorderRadius.circular(8),

                                    ),

                                    child: Text(

                                      '',

                                      style: TextStyle(

                                        fontSize: 11,

                                        fontWeight: FontWeight.bold,

                                        color: (sentPorTipo[entry.key] == 'Positivo'

                                            ? const Color(0xFF10B981)

                                            : (sentPorTipo[entry.key] == 'Negativo' ? const Color(0xFFE41E3F) : const Color(0xFF64748B))),

                                      ),

                                    ),

                                  ),

                                ],

                              ),

                            ),

                            const Divider(height: 10),

                          ],

                        ],

                      );

                    },

                  ),

                  const SizedBox(height: 12),

                  // Clasificación de la IA

                  Container(

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(

                      color: isDark ? const Color(0xFF0F172A) : _bgAnalyticalDyn,

                      borderRadius: BorderRadius.circular(10),

                    ),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Text(

                          'Interpretación de Sentimientos de la Reacción:',

                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: pText),

                        ),

                        const SizedBox(height: 4),

                        Text(

                          'Positivas: $_reacPositivo% • Neutras: $_reacNeutro% • Críticas/Burla: $_reacNegativo%',

                          style: TextStyle(fontSize: 12, color: sText),

                        ),

                        if (_meDivierteComoBurla) ...[

                          const SizedBox(height: 4),

                          Text(

                            'ℹ️ Gemini clasificó las reacciones "Me divierte" como crítica/burla sarcástica debido al contexto de la publicación.',

                            style: TextStyle(fontSize: 11.5, color: Color(0xFFE41E3F), fontStyle: FontStyle.italic),

                          ),

                        ],

                      ],

                    ),

                  ),

                ],

              ),

            ),

          ),

          actions: [

            ElevatedButton(

              onPressed: () => Navigator.pop(ctx),

              style: ElevatedButton.styleFrom(backgroundColor: _fbBlue, foregroundColor: Colors.white),

              child: Text('Entendido'),

            ),

          ],

        );

      },

    );

  }



  void _mostrarModalViralidad() {

    showDialog(

      context: context,

      builder: (ctx) {

        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        final pText = isDark ? const Color(0xFFF8FAFC) : _pTextColor;

        final sText = isDark ? const Color(0xFF94A3B8) : _sTextColor;

        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;



        final double ratioSharesReactions = _likes > 0 ? (_compartidos / _likes) * 100 : 0;

        final double ratioSharesComments = _totalComentarios > 0 ? (_compartidos / _totalComentarios) * 100 : 0;



        return AlertDialog(

          backgroundColor: cardBg,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: Row(

            children: [

              Container(

                padding: const EdgeInsets.all(8),

                decoration: BoxDecoration(

                  color: const Color(0xFF10B981).withValues(alpha: 0.12),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: const Icon(Icons.share_rounded, color: Color(0xFF10B981), size: 22),

              ),

              const SizedBox(width: 12),

              Text(

                'Métricas de Viralidad & Difusión',

                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: pText),

              ),

            ],

          ),

          content: Column(

            mainAxisSize: MainAxisSize.min,

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text('Esta publicación ha sido compartida $_compartidos veces.', style: TextStyle(fontSize: 13.5, color: sText)),

              const SizedBox(height: 16),

              _metricRowModal('Índice Compartidos / Reacciones:', '${ratioSharesReactions.toStringAsFixed(1)}%', pText, sText),

              const SizedBox(height: 8),

              _metricRowModal('Índice Compartidos / Comentarios:', '${ratioSharesComments.toStringAsFixed(1)}%', pText, sText),

              const SizedBox(height: 8),

              _metricRowModal('Nivel de Difusión Orgánica:', _compartidos >= 20 ? 'Alta Viralidad' : (_compartidos >= 5 ? 'Difusión Moderada' : 'Alcance Básico'), const Color(0xFF10B981), sText),

            ],

          ),

          actions: [

            ElevatedButton(

              onPressed: () => Navigator.pop(ctx),

              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),

              child: Text('Cerrar'),

            ),

          ],

        );

      },

    );

  }



  void _mostrarDetalleComentario(Map<String, dynamic> item) {

    showDialog(

      context: context,

      builder: (ctx) {

        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        final pText = isDark ? const Color(0xFFF8FAFC) : _pTextColor;

        final sText = isDark ? const Color(0xFF94A3B8) : _sTextColor;

        final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;



        final user = item['username'] ?? 'Usuario';

        final comment = item['comment'] ?? '';

        final sentiment = item['sentiment'] ?? 'Neutro';

        final esBot = item['es_bot'] == true;

        final motivoBot = item['motivo_bot'] ?? 'Comentario orgánico';

        final explicacion = item['explicacion_ia'] ?? 'Clasificado según semántica textual.';



        Color sentColor = const Color(0xFF10B981);

        if (sentiment == 'Negativo') sentColor = const Color(0xFFE41E3F);

        if (sentiment == 'Neutro') sentColor = const Color(0xFF64748B);



        return AlertDialog(

          backgroundColor: cardBg,

          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

          title: Row(

            children: [

              CircleAvatar(

                backgroundColor: _fbBlue,

                radius: 16,

                child: Text(user.isNotEmpty ? user[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),

              ),

              const SizedBox(width: 10),

              Expanded(

                child: Text(

                  user,

                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: pText),

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                ),

              ),

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

                decoration: BoxDecoration(

                  color: sentColor.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(10),

                ),

                child: Text(

                  sentiment,

                  style: TextStyle(color: sentColor, fontWeight: FontWeight.bold, fontSize: 12),

                ),

              ),

            ],

          ),

          content: SizedBox(

            width: 480,

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text('Texto del Comentario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: sText)),

                const SizedBox(height: 6),

                Container(

                  width: double.infinity,

                  padding: const EdgeInsets.all(12),

                  decoration: BoxDecoration(

                    color: isDark ? const Color(0xFF0F172A) : _bgAnalyticalDyn,

                    borderRadius: BorderRadius.circular(10),

                  ),

                  child: Text(

                    comment.isNotEmpty ? comment : '(Comentario multimedia / sin texto)',

                    style: TextStyle(fontSize: 14, color: pText, height: 1.4),

                  ),

                ),

                const SizedBox(height: 14),

                Text('Análisis Contextual de Gemini IA:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: sText)),

                const SizedBox(height: 6),

                Text(explicacion, style: TextStyle(fontSize: 13, color: pText, height: 1.4)),

                const SizedBox(height: 14),

                if (esBot) ...[

                  Container(

                    padding: const EdgeInsets.all(10),

                    decoration: BoxDecoration(

                      color: const Color(0xFFFEF3C7),

                      borderRadius: BorderRadius.circular(8),

                      border: Border.all(color: const Color(0xFFF59E0B)),

                    ),

                    child: Row(

                      children: [

                        const Icon(Icons.smart_toy_outlined, color: Color(0xFFB45309), size: 18),

                        const SizedBox(width: 8),

                        Expanded(

                          child: Text(

                            'Alerta Bot: $motivoBot',

                            style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 12),

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ],

            ),

          ),

          actions: [

            TextButton(

              onPressed: () => Navigator.pop(ctx),

              child: Text('Cerrar'),

            ),

          ],

        );

      },

    );

  }



  Widget _metricRowModal(String label, String val, Color vColor, Color sText) {

    return Row(

      mainAxisAlignment: MainAxisAlignment.spaceBetween,

      children: [

        Text(label, style: TextStyle(fontSize: 13, color: sText)),

        Text(val, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: vColor)),

      ],

    );

  }



  Widget _buildMainBody() {

    return SingleChildScrollView(

      controller: _mainScrollController,

      padding: const EdgeInsets.all(24.0),

      child: Center(

        child: Container(

          constraints: const BoxConstraints(maxWidth: 1180),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: [

              _buildAnalysisInputCard(),

              const SizedBox(height: 20),

              if (_isLoading)

                _buildLoadingIndicator()

              else if (_hasAnalyzed) ...[

                _buildMetricsCards(),

                const SizedBox(height: 20),

                _buildContextAndKeywordsCard(),

                const SizedBox(height: 20),

                LayoutBuilder(

                  builder: (context, constraints) {

                    final isMobile = constraints.maxWidth < 850;

                    if (isMobile) {

                      return Column(

                        children: [

                          _buildSentimentChartCard(),

                          const SizedBox(height: 20),

                          _buildReactionsAndSummaryCard(),

                        ],

                      );

                    }

                    return Row(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        Expanded(

                          flex: 5,

                          child: _buildSentimentChartCard(),

                        ),

                        const SizedBox(width: 20),

                        Expanded(

                          flex: 5,

                          child: _buildReactionsAndSummaryCard(),

                        ),

                      ],

                    );

                  },

                ),

                const SizedBox(height: 20),

                _buildReactionsTableCard(),

                const SizedBox(height: 20),

                _buildCommentsTableCard(),

              ],

            ],

          ),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    if (widget.embedInShell) {

      return _buildMainBody();

    }



    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    final nombreUsuario = args?['nombre'] ?? 'Usuario';



    return Scaffold(

      key: _scaffoldKey,

      backgroundColor: _bgAnalyticalDyn,

      drawer: _buildHistorialDrawer(),

      appBar: AppBar(

        automaticallyImplyLeading: false,

        backgroundColor: _headerNavy,

        foregroundColor: Colors.white,

        elevation: 2,

        bottom: PreferredSize(

          preferredSize: const Size.fromHeight(3),

          child: Container(color: _fbBlue, height: 3),

        ),

        title: Row(

          children: [

            Container(

              padding: const EdgeInsets.all(6),

              decoration: BoxDecoration(

                color: _fbBlue,

                borderRadius: BorderRadius.circular(8),

              ),

              child: const Icon(Icons.insights_rounded, color: Colors.white, size: 22),

            ),

            const SizedBox(width: 12),

            Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  'Sistema de minería y análisis con IA • Módulo Facebook',

                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),

                ),

                Text(

                  'Panel de resultados • Usuario activo: $nombreUsuario',

                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),

                ),

              ],

            ),

          ],

        ),

        actions: [

          TextButton.icon(

            onPressed: () {

              _cargarHistorial();

              _scaffoldKey.currentState?.openDrawer();

            },

            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 19),

            label: Text(

              'Historial de consultas',

              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),

            ),

          ),

          if (_hasAnalyzed && _idAnalisis != null)

            Padding(

              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),

              child: ElevatedButton.icon(

                onPressed: _descargarExcel,

                icon: const Icon(Icons.download_rounded, size: 18),

                label: Text('Descargar reporte en Excel'),

                style: ElevatedButton.styleFrom(

                  backgroundColor: const Color(0xFF10B981),

                  foregroundColor: Colors.white,

                  elevation: 0,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(8),

                  ),

                ),

              ),

            ),

          IconButton(

            tooltip: 'Cerrar sesión',

            icon: const Icon(Icons.logout_rounded, color: Colors.white),

            onPressed: () {

              AppSettings.logout(context);

            },

          ),

          const SizedBox(width: 8),

        ],

      ),

      body: _buildMainBody(),

    );

  }



  Widget _buildHistorialDrawer() {

    return Drawer(

      backgroundColor: Colors.white,

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          Container(

            padding: const EdgeInsets.fromLTRB(20, 44, 20, 20),

            color: _headerNavy,

            child: const Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Row(

                  children: [

                    Icon(Icons.history_rounded, color: _fbBlue, size: 26),

                    SizedBox(width: 10),

                    Text(

                      'Historial de consultas',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 18,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ],

                ),

                SizedBox(height: 6),

                Text(

                  'Selecciona una publicación guardada para cargarla al instante',

                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),

                ),

              ],

            ),

          ),

          Expanded(

            child: _loadingHistorial

                ? const Center(child: CircularProgressIndicator(color: _fbBlue))

                : _historialList.isEmpty

                    ? Center(

                        child: Padding(

                          padding: const EdgeInsets.all(24.0),

                          child: Text(

                            'Todavía no hay publicaciones guardadas en el historial.',

                            textAlign: TextAlign.center,

                            style: TextStyle(color: _sTextColor),

                          ),

                        ),

                      )

                    : ListView.separated(

                        itemCount: _historialList.length,

                        separatorBuilder: (_, __) => const Divider(height: 1),

                        itemBuilder: (context, index) {

                          final item = _historialList[index];

                          final id = item['id'] as int;

                          return ListTile(

                            onTap: () => _seleccionarItemHistorial(id),

                            leading: const CircleAvatar(

                              backgroundColor: Color(0xFFE7F3FF),

                              child: Icon(Icons.analytics_outlined, color: _fbBlue),

                            ),

                            title: Text(

                              item['url_post'] ?? '',

                              maxLines: 1,

                              overflow: TextOverflow.ellipsis,

                              style: TextStyle(

                                fontSize: 13,

                                fontWeight: FontWeight.w600,

                                color: _pTextColor,

                              ),

                            ),

                            subtitle: Text(

                              'Reacciones: ${item['total_likes']} • Comentarios: ${item['total_comentarios']}\nFecha: ${item['fecha_analisis']}',

                              style: TextStyle(fontSize: 11, color: _sTextColor),

                            ),

                            isThreeLine: true,

                            trailing: IconButton(

                              tooltip: 'Eliminar registro',

                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),

                              onPressed: () => _eliminarItemHistorial(id),

                            ),

                          );

                        },

                      ),

          ),

        ],

      ),

    );

  }



  Widget _buildAnalysisInputCard() {

    final isDark = Theme.of(context).brightness == Brightness.dark;



    return Container(

      decoration: _analyticalCardDecoration(),

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),

                decoration: BoxDecoration(

                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFE7F3FF),

                  borderRadius: BorderRadius.circular(8),

                  border: Border.all(color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),

                ),

                child: Row(

                  children: [

                    Icon(Icons.facebook_rounded, color: isDark ? const Color(0xFF60A5FA) : _fbBlue, size: 18),

                    const SizedBox(width: 6),

                    Text(

                      'Módulo Facebook',

                      style: TextStyle(

                        fontSize: 12,

                        fontWeight: FontWeight.bold,

                        color: isDark ? const Color(0xFF93C5FD) : _fbBlue,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Text(

                  'Extracción completa de comentarios, reacciones por usuario y contexto IA',

                  style: TextStyle(

                    fontSize: 15.5,

                    fontWeight: FontWeight.bold,

                    color: _pTextColor,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          Row(

            children: [

              Expanded(

                child: TextField(

                  controller: _urlController,

                  style: TextStyle(

                    color: _pTextColor,

                    fontSize: 14.5,

                    fontWeight: FontWeight.w500,

                  ),

                  decoration: InputDecoration(

                    hintText: 'https://www.facebook.com/...',

                    hintStyle: TextStyle(color: _sTextColor.withValues(alpha: 0.7)),

                    labelText: 'Enlace de la publicación a analizar',

                    labelStyle: TextStyle(color: _sTextColor, fontWeight: FontWeight.w500),

                    prefixIcon: Icon(Icons.link_rounded, color: isDark ? const Color(0xFF60A5FA) : _fbBlue),

                    filled: true,

                    fillColor: _bgAnalyticalDyn,

                    enabledBorder: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: _borderDyn),

                    ),

                    focusedBorder: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(10),

                      borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : _fbBlue, width: 2.0),

                    ),

                  ),

                ),

              ),

              const SizedBox(width: 14),

              SizedBox(

                height: 52,

                child: ElevatedButton.icon(

                  onPressed: _isLoading ? null : _triggerAnalysis,

                  icon: const Icon(Icons.radar_rounded, size: 20),

                  label: const Text(

                    'Analizar publicación',

                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, letterSpacing: 0.2),

                  ),

                  style: ElevatedButton.styleFrom(

                    backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF1877F2),

                    foregroundColor: Colors.white,

                    elevation: isDark ? 3 : 1,

                    shadowColor: (isDark ? const Color(0xFF2563EB) : const Color(0xFF1877F2)).withValues(alpha: 0.4),

                    padding: const EdgeInsets.symmetric(horizontal: 22),

                    shape: RoundedRectangleBorder(

                      borderRadius: BorderRadius.circular(10),

                    ),

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 14),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            crossAxisAlignment: WrapCrossAlignment.center,

            children: [

              Text(

                'Prueba rápida:',

                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _sTextColor),

              ),

              ActionChip(

                avatar: Icon(Icons.rocket_launch_rounded, size: 14, color: isDark ? const Color(0xFF60A5FA) : _fbBlue),

                label: Text(

                  'Keynote GitHub (2.1k)',

                  style: TextStyle(

                    fontSize: 11.5,

                    fontWeight: FontWeight.w600,

                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),

                  ),

                ),

                backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),

                side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                onPressed: () {

                  setState(() {

                    _urlController.text = 'https://www.facebook.com/share/p/1DvEH1bXHc/';

                  });

                },

              ),

              ActionChip(

                avatar: Icon(Icons.forum_outlined, size: 14, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),

                label: Text(

                  'Post Comunidad (35)',

                  style: TextStyle(

                    fontSize: 11.5,

                    fontWeight: FontWeight.w600,

                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF4338CA),

                  ),

                ),

                backgroundColor: isDark ? const Color(0xFF312E81).withValues(alpha: 0.35) : const Color(0xFFEEF2FF),

                side: BorderSide(color: isDark ? const Color(0xFF6366F1) : const Color(0xFFC7D2FE)),

                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                onPressed: () {

                  setState(() {

                    _urlController.text = 'https://www.facebook.com/share/p/1AFE2hmxFW/';

                  });

                },

              ),

              if (_urlController.text.isNotEmpty)

                ActionChip(

                  avatar: const Icon(Icons.clear_rounded, size: 14, color: Color(0xFFEF4444)),

                  label: Text(

                    'Limpiar',

                    style: TextStyle(

                      fontSize: 11.5,

                      fontWeight: FontWeight.w600,

                      color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),

                    ),

                  ),

                  backgroundColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEF2F2),

                  side: BorderSide(color: isDark ? const Color(0xFFEF4444) : const Color(0xFFFECACA)),

                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),

                  onPressed: () {

                    setState(() {

                      _urlController.clear();

                    });

                  },

                ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildLoadingIndicator() {

    final int percentText = (_progressValue * 100).toInt();



    return Container(

      padding: const EdgeInsets.all(28.0),

      decoration: _analyticalCardDecoration(),

      child: Column(

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Expanded(

                child: Row(

                  children: [

                    const SizedBox(

                      width: 22,

                      height: 22,

                      child: CircularProgressIndicator(

                        strokeWidth: 3,

                        valueColor: AlwaysStoppedAnimation<Color>(_fbBlue),

                      ),

                    ),

                    const SizedBox(width: 14),

                    Expanded(

                      child: Text(

                        _loadingStageText,

                        style: TextStyle(

                          fontSize: 15,

                          fontWeight: FontWeight.bold,

                          color: _pTextColor,

                        ),

                      ),

                    ),

                  ],

                ),

              ),

              Text(

                '$percentText%',

                style: const TextStyle(

                  fontSize: 17,

                  fontWeight: FontWeight.bold,

                  color: _fbBlue,

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          ClipRRect(

            borderRadius: BorderRadius.circular(8),

            child: LinearProgressIndicator(

              value: _progressValue,

              minHeight: 10,

              backgroundColor: const Color(0xFFE2E8F0),

              valueColor: const AlwaysStoppedAnimation<Color>(_fbBlue),

            ),

          ),

          const SizedBox(height: 14),

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Text(

                'Tiempo transcurrido: ${_elapsedSeconds}s',

                style: TextStyle(fontSize: 13, color: _sTextColor),

              ),

              Text(

                'Tiempo máximo estimado: ~${_remainingSeconds}s',

                style: const TextStyle(

                  fontSize: 13,

                  fontWeight: FontWeight.w600,

                  color: _fbBlue,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _buildMetricsCards() {

    final int porcBots = _totalComentarios > 0

        ? ((_totalBots / _totalComentarios) * 100).round()

        : 0;



    return Row(

      children: [

        Expanded(

          child: _buildMetricCard(

            title: 'Reacciones totales',

            value: '$_likes',

            icon: Icons.thumb_up_alt_rounded,

            color: _fbBlue,

            badgeText: _likes == 0

                ? 'Sin reacciones registradas'

                : '$_reacPositivo% de aprobación • Clic para desglose',

            onTap: _mostrarModalReaccionesDetalladas,

          ),

        ),

        const SizedBox(width: 14),

        Expanded(

          child: _buildMetricCard(

            title: 'Veces compartido',

            value: '$_compartidos',

            icon: Icons.share_rounded,

            color: const Color(0xFF10B981),

            badgeText: 'Difusión • Clic para viralidad',

            onTap: _mostrarModalViralidad,

          ),

        ),

        const SizedBox(width: 14),

        Expanded(

          child: _buildMetricCard(

            title: 'Comentarios extraídos',

            value: '${_comments.length}',

            icon: Icons.forum_rounded,

            color: const Color(0xFF6366F1),

            badgeText: _comments.isEmpty

                ? 'Sin comentarios • Estado neutro'

                : (_totalComentarios > _comments.length

                    ? 'De $_totalComentarios en post • Clic tabla'

                    : '${_comments.length} analizados • Clic tabla'),

            onTap: _irAComentarios,

          ),

        ),

        if (_totalBots > 0) ...[

          const SizedBox(width: 14),

          Expanded(

            child: _buildMetricCard(

              title: 'Posibles bots detectados',

              value: '$_totalBots',

              icon: Icons.smart_toy_outlined,

              color: const Color(0xFFF59E0B),

              badgeText: '$porcBots% spam • Clic para filtrar',

              onTap: _filtrarBots,

            ),

          ),

        ],

      ],

    );

  }



  Widget _buildMetricCard({

    required String title,

    required String value,

    required IconData icon,

    required Color color,

    required String badgeText,

    VoidCallback? onTap,

  }) {

    return HoverScaleCard(

      scaleFactor: 1.03,

      translateY: -3.0,

      cursor: SystemMouseCursors.click,

      onTap: onTap,

      padding: const EdgeInsets.all(18.0),

      hoverDecoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.6),

        boxShadow: [

          BoxShadow(

            color: color.withValues(alpha: 0.16),

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

              color: color.withValues(alpha: 0.1),

              borderRadius: BorderRadius.circular(12),

            ),

            child: Icon(icon, size: 26, color: color),

          ),

          const SizedBox(width: 14),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: TextStyle(fontSize: 12.5, color: _sTextColor),

                ),

                const SizedBox(height: 4),

                Text(

                  value,

                  style: TextStyle(

                    fontSize: 23,

                    fontWeight: FontWeight.bold,

                    color: _pTextColor,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  badgeText,

                  style: TextStyle(

                    fontSize: 11.5,

                    color: color,

                    fontWeight: FontWeight.w600,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildContextAndKeywordsCard() {

    return HoverScaleCard(

      scaleFactor: 1.01,

      translateY: -2.0,

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.psychology_outlined, color: _fbBlue),

              SizedBox(width: 8),

              Text(

                'Contexto general utilizado por la IA y términos frecuentes',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: _pTextColor,

                ),

              ),

            ],

          ),

          const SizedBox(height: 12),

          Container(

            width: double.infinity,

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(

              color: _bgAnalyticalDyn,

              borderRadius: BorderRadius.circular(8),

            ),

            child: Text(

              '$_contextoPost ($_contextoMultimedia)',

              style: TextStyle(

                fontSize: 13.5,

                color: _pTextColor,

                height: 1.4,

              ),

            ),

          ),

          if (_palabrasFrecuentes.isNotEmpty) ...[

            const SizedBox(height: 14),

            Text(

              'Términos más repetidos en los comentarios:',

              style: TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w600,

                color: _sTextColor,

              ),

            ),

            const SizedBox(height: 8),

            Wrap(

              spacing: 8,

              runSpacing: 8,

              children: _palabrasFrecuentes.map((item) {

                final palabra = item['palabra'] ?? '';

                return HoverZoom(

                  scaleFactor: 1.08,

                  onTap: () {

                    _searchCommentController.text = palabra;

                    setState(() => _busquedaTexto = palabra);

                    _irAComentarios();

                    ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(

                        content: Text('Buscando comentarios con la palabra clave: "$palabra"'),

                        backgroundColor: _fbBlue,

                        duration: const Duration(seconds: 2),

                      ),

                    );

                  },

                  child: Chip(

                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : _bgAnalyticalDyn,

                    side: BorderSide(color: _borderDyn),

                    label: Text(

                      '${item['palabra']} (${item['frecuencia']})',

                      style: TextStyle(

                        color: _pTextColor,

                        fontWeight: FontWeight.w600,

                        fontSize: 12,

                      ),

                    ),

                  ),

                );

              }).toList(),

            ),

          ],

        ],

      ),

    );

  }



  Widget _buildSentimentChartCard() {

    return HoverScaleCard(

      scaleFactor: 1.015,

      translateY: -2.0,

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Row(

                children: [

                  Icon(Icons.pie_chart_outline_rounded, color: _fbBlue),

                  SizedBox(width: 8),

                  Text(

                    'Distribución de sentimientos en comentarios',

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.bold,

                      color: _pTextColor,

                    ),

                  ),

                ],

              ),

              HoverZoom(

                scaleFactor: 1.15,

                child: IconButton(

                  icon: Icon(Icons.refresh_rounded, size: 18, color: _sTextColor),

                  tooltip: 'Reanimar gráfico con fluidez',

                  onPressed: () {

                    _chartAnimController.reset();

                    _chartAnimController.forward();

                  },

                ),

              ),

            ],

          ),

          const SizedBox(height: 20),

          SizedBox(

            height: 230,

            child: Row(

              children: [

                Expanded(

                  child: AnimatedBuilder(

                    animation: _chartCurvedAnimation,

                    builder: (context, _) {

                      final animVal = _chartCurvedAnimation.value;

                      return Stack(

                        alignment: Alignment.center,

                        children: [

                          PieChart(

                            PieChartData(

                              pieTouchData: PieTouchData(

                                touchCallback: (FlTouchEvent event, pieTouchResponse) {

                                  setState(() {

                                    if (!event.isInterestedForInteractions ||

                                        pieTouchResponse == null ||

                                        pieTouchResponse.touchedSection == null) {

                                      _touchedIndex = -1;

                                      return;

                                    }

                                    _touchedIndex = pieTouchResponse

                                        .touchedSection!.touchedSectionIndex;

                                  });

                                },

                              ),

                              borderData: FlBorderData(show: false),

                              sectionsSpace: 3.2 * animVal,

                              centerSpaceRadius: 46,

                              startDegreeOffset: -90.0 + (360.0 * (1.0 - animVal)),

                              sections: _generatePieChartSections(animVal),

                            ),

                            swapAnimationDuration: const Duration(milliseconds: 260),

                            swapAnimationCurve: Curves.easeOutCubic,

                          ),

                          _buildDonutCenterHole(animVal),

                        ],

                      );

                    },

                  ),

                ),

                const SizedBox(width: 16),

                Column(

                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    _buildInteractiveLegendIndicator(

                      index: 0,

                      color: const Color(0xFF10B981),

                      title: 'Positivos',

                      percentage: _porcPositivo,

                    ),

                    const SizedBox(height: 12),

                    _buildInteractiveLegendIndicator(

                      index: 1,

                      color: const Color(0xFFE41E3F),

                      title: 'Negativos',

                      percentage: _porcNegativo,

                    ),

                    const SizedBox(height: 12),

                    _buildInteractiveLegendIndicator(

                      index: 2,

                      color: const Color(0xFF6366F1),

                      title: 'Neutros',

                      percentage: _porcNeutro,

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



  List<PieChartSectionData> _generatePieChartSections(double animVal) {

    final bool sinComentarios = _comments.isEmpty || (_porcPositivo == 0 && _porcNegativo == 0 && _porcNeutro == 0);

    final effectiveAnim = animVal.clamp(0.001, 1.0);

    final isDark = Theme.of(context).brightness == Brightness.dark;



    if (sinComentarios) {

      return [

        PieChartSectionData(

          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),

          value: 100.0 * effectiveAnim,

          title: '',

          radius: 46.0 + (6.0 * effectiveAnim),

          showTitle: false,

        ),

      ];

    }



    final valPos = _porcPositivo * effectiveAnim;

    final valNeg = _porcNegativo * effectiveAnim;

    final valNeu = _porcNeutro * effectiveAnim;



    return List.generate(3, (i) {

      final isTouched = i == _touchedIndex;

      final fontSize = isTouched ? 16.0 : 12.0;

      final radius = isTouched ? 68.0 : (44.0 + 8.0 * effectiveAnim);



      switch (i) {

        case 0:

          return PieChartSectionData(

            color: const Color(0xFF10B981),

            value: valPos <= 0 ? 0.0001 : valPos,

            title: valPos >= 5 ? '${(_porcPositivo * effectiveAnim).toInt()}%' : '',

            radius: radius,

            titleStyle: TextStyle(

              fontSize: fontSize,

              fontWeight: FontWeight.bold,

              color: Colors.white,

              shadows: isTouched

                  ? const [Shadow(color: Colors.black45, blurRadius: 6)]

                  : null,

            ),

          );

        case 1:

          return PieChartSectionData(

            color: const Color(0xFFE41E3F),

            value: valNeg <= 0 ? 0.0001 : valNeg,

            title: valNeg >= 5 ? '${(_porcNegativo * effectiveAnim).toInt()}%' : '',

            radius: radius,

            titleStyle: TextStyle(

              fontSize: fontSize,

              fontWeight: FontWeight.bold,

              color: Colors.white,

              shadows: isTouched

                  ? const [Shadow(color: Colors.black45, blurRadius: 6)]

                  : null,

            ),

          );

        case 2:

          return PieChartSectionData(

            color: const Color(0xFF6366F1),

            value: valNeu <= 0 ? 0.0001 : valNeu,

            title: valNeu >= 5 ? '${(_porcNeutro * effectiveAnim).toInt()}%' : '',

            radius: radius,

            titleStyle: TextStyle(

              fontSize: fontSize,

              fontWeight: FontWeight.bold,

              color: Colors.white,

              shadows: isTouched

                  ? const [Shadow(color: Colors.black45, blurRadius: 6)]

                  : null,

            ),

          );

        default:

          throw Error();

      }

    });

  }



  Widget _buildDonutCenterHole(double animVal) {

    final bool sinComentarios = _comments.isEmpty || (_porcPositivo == 0 && _porcNegativo == 0 && _porcNeutro == 0);

    final isDark = Theme.of(context).brightness == Brightness.dark;



    String label;

    String percentText;

    Color accentColor;

    IconData icon;



    if (sinComentarios) {

      label = 'Sin comentarios';

      percentText = '0';

      accentColor = _sTextColor;

      icon = Icons.chat_bubble_outline_rounded;

    } else if (_touchedIndex == 0) {

      label = 'Positivo';

      percentText = '${_porcPositivo.toInt()}%';

      accentColor = const Color(0xFF10B981);

      icon = Icons.sentiment_very_satisfied_rounded;

    } else if (_touchedIndex == 1) {

      label = 'Crítico';

      percentText = '${_porcNegativo.toInt()}%';

      accentColor = const Color(0xFFE41E3F);

      icon = Icons.sentiment_very_dissatisfied_rounded;

    } else if (_touchedIndex == 2) {

      label = 'Neutro';

      percentText = '${_porcNeutro.toInt()}%';

      accentColor = const Color(0xFF6366F1);

      icon = Icons.sentiment_neutral_rounded;

    } else {

      if (animVal < 0.95) {

        label = 'Cargando...';

        percentText = '${(animVal * 100).toInt()}%';

        accentColor = _fbBlue;

        icon = Icons.donut_large_rounded;

      } else {

        if (_porcPositivo >= _porcNegativo && _porcPositivo >= _porcNeutro && _porcPositivo > 0) {

          label = (_porcPositivo >= 50 && _porcNegativo == 0) ? 'Favorable' : 'Predomina +';

          percentText = '${_porcPositivo.toInt()}%';

          accentColor = const Color(0xFF10B981);

          icon = Icons.sentiment_very_satisfied_rounded;

        } else if (_porcNegativo >= _porcPositivo && _porcNegativo >= _porcNeutro && _porcNegativo > 0) {

          label = 'Predomina -';

          percentText = '${_porcNegativo.toInt()}%';

          accentColor = const Color(0xFFE41E3F);

          icon = Icons.sentiment_very_dissatisfied_rounded;

        } else if (_porcNeutro > 0) {

          label = 'Predomina =';

          percentText = '${_porcNeutro.toInt()}%';

          accentColor = const Color(0xFF6366F1);

          icon = Icons.sentiment_neutral_rounded;

        } else {

          label = 'Neutro';

          percentText = '0%';

          accentColor = _sTextColor;

          icon = Icons.chat_bubble_outline_rounded;

        }

      }

    }



    return GestureDetector(

      onTap: () {

        setState(() => _filtroSentimiento = 'Todos');

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('Filtro de comentarios restablecido a: Todos'),

            duration: Duration(seconds: 1),

          ),

        );

      },

      child: Container(

        width: 82,

        height: 82,

        decoration: BoxDecoration(

          color: isDark ? const Color(0xFF1E293B) : Colors.white,

        shape: BoxShape.circle,

        boxShadow: [

          BoxShadow(

            color: accentColor.withValues(alpha: 0.16),

            blurRadius: 10,

            spreadRadius: 2,

          ),

        ],

        border: Border.all(

          color: accentColor.withValues(alpha: 0.35),

          width: 1.8,

        ),

      ),

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Icon(icon, size: 20, color: accentColor),

          const SizedBox(height: 2),

          Text(

            percentText,

            style: TextStyle(

              fontSize: 15,

              fontWeight: FontWeight.bold,

              color: accentColor,

              height: 1.0,

            ),

          ),

          const SizedBox(height: 2),

          Text(

            label,

            style: TextStyle(

              fontSize: 10,

              fontWeight: FontWeight.w600,

              color: _sTextColor,

            ),

          ),

        ],

      ),

    ),

    );

  }



  Widget _buildInteractiveLegendIndicator({

    required int index,

    required Color color,

    required String title,

    required double percentage,

  }) {

    final isHovered = _touchedIndex == index;

    return MouseRegion(

      cursor: SystemMouseCursors.click,

      onEnter: (_) => setState(() => _touchedIndex = index),

      onExit: (_) => setState(() => _touchedIndex = -1),

      child: GestureDetector(

        onTap: () {

          setState(() => _filtroSentimiento = title);

          _irAComentarios();

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text('Filtrando comentarios por: '),

              backgroundColor: color,

              duration: const Duration(seconds: 2),

            ),

          );

        },

        child: AnimatedContainer(

        duration: const Duration(milliseconds: 180),

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

        decoration: BoxDecoration(

          color: isHovered ? color.withValues(alpha: 0.12) : Colors.transparent,

          borderRadius: BorderRadius.circular(8),

          border: Border.all(

            color: isHovered ? color.withValues(alpha: 0.4) : Colors.transparent,

          ),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            AnimatedContainer(

              duration: const Duration(milliseconds: 180),

              width: isHovered ? 16 : 12,

              height: isHovered ? 16 : 12,

              decoration: BoxDecoration(

                shape: BoxShape.circle,

                color: color,

                boxShadow: isHovered

                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6)]

                    : null,

              ),

            ),

            const SizedBox(width: 8),

            Text(

              '$title (${percentage.toInt()}%)',

              style: TextStyle(

                fontSize: 13,

                fontWeight: isHovered ? FontWeight.bold : FontWeight.w600,

                color: isHovered ? color : _pTextColor,

              ),

            ),

          ],

        ),

      ),

    ),

  );

}



  Widget _buildReactionsAndSummaryCard() {

    return HoverScaleCard(

      scaleFactor: 1.015,

      translateY: -2.0,

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Icon(Icons.auto_awesome_rounded, color: _fbBlue),

              SizedBox(width: 8),

              Text(

                'Balance de reacciones y resumen general',

                style: TextStyle(

                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: _pTextColor,

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          if (_reacPositivo == 0 && _reacNeutro == 0 && _reacNegativo == 0) ...[

            Container(

              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),

              decoration: BoxDecoration(

                color: (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

                borderRadius: BorderRadius.circular(8),

              ),

              child: Row(

                children: [

                  Icon(Icons.info_outline, size: 18, color: _sTextColor),

                  const SizedBox(width: 8),

                  Text(

                    'Estado Neutro • Sin reacciones registradas',

                    style: TextStyle(

                      fontSize: 12.5,

                      fontWeight: FontWeight.w500,

                      color: _sTextColor,

                    ),

                  ),

                ],

              ),

            ),

          ] else ...[

            Row(

              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [

                HoverZoom(

                  scaleFactor: 1.06,

                  child: Row(

                    children: [

                      const Icon(Icons.sentiment_satisfied_alt_rounded, color: Color(0xFF10B981), size: 18),

                      const SizedBox(width: 4),

                      Text(

                        'Positivas: $_reacPositivo%',

                        style: const TextStyle(

                          color: Color(0xFF10B981),

                          fontWeight: FontWeight.bold,

                          fontSize: 12.5,

                        ),

                      ),

                    ],

                  ),

                ),

                HoverZoom(

                  scaleFactor: 1.06,

                  child: Row(

                    children: [

                      const Icon(Icons.sentiment_neutral_rounded, color: Color(0xFF6366F1), size: 18),

                      const SizedBox(width: 4),

                      Text(

                        'Neutras: $_reacNeutro%',

                        style: const TextStyle(

                          color: Color(0xFF6366F1),

                          fontWeight: FontWeight.bold,

                          fontSize: 12.5,

                        ),

                      ),

                    ],

                  ),

                ),

                HoverZoom(

                  scaleFactor: 1.06,

                  child: Row(

                    children: [

                      const Icon(Icons.sentiment_very_dissatisfied_rounded, color: Color(0xFFE41E3F), size: 18),

                      const SizedBox(width: 4),

                      Text(

                        _meDivierteComoBurla

                            ? 'Negativas/burla: $_reacNegativo%'

                            : 'Negativas: $_reacNegativo%',

                        style: const TextStyle(

                          color: Color(0xFFE41E3F),

                          fontWeight: FontWeight.bold,

                          fontSize: 12.5,

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

            const SizedBox(height: 10),

            AnimatedBuilder(

              animation: _chartCurvedAnimation,

              builder: (context, _) {

                final anim = _chartCurvedAnimation.value;

                return ClipRRect(

                  borderRadius: BorderRadius.circular(6),

                  child: SizedBox(

                    height: 14,

                    child: Row(

                      children: [

                        if (_reacPositivo > 0)

                          Expanded(

                            flex: (_reacPositivo * anim).toInt().clamp(1, 100),

                            child: Tooltip(

                              message: 'Positivas: $_reacPositivo%',

                              child: HoverZoom(

                                scaleFactor: 1.05,

                                child: Container(color: const Color(0xFF10B981)),

                              ),

                            ),

                          ),

                        if (_reacNeutro > 0)

                          Expanded(

                            flex: (_reacNeutro * anim).toInt().clamp(1, 100),

                            child: Tooltip(

                              message: 'Neutras: $_reacNeutro%',

                              child: HoverZoom(

                                scaleFactor: 1.05,

                                child: Container(color: const Color(0xFF6366F1)),

                              ),

                            ),

                          ),

                        if (_reacNegativo > 0)

                          Expanded(

                            flex: (_reacNegativo * anim).toInt().clamp(1, 100),

                            child: Tooltip(

                              message: 'Negativas / Burla: $_reacNegativo%',

                              child: HoverZoom(

                                scaleFactor: 1.05,

                                child: Container(color: const Color(0xFFE41E3F)),

                              ),

                            ),

                          ),

                      ],

                    ),

                  ),

                );

              },

            ),

          ],

          const SizedBox(height: 18),

          const Divider(color: Color(0xFFE2E8F0)),

          const SizedBox(height: 10),

          Text(

            'Interpretación contextual con IA:',

            style: TextStyle(

              fontSize: 13,

              fontWeight: FontWeight.bold,

              color: _pTextColor,

            ),

          ),

          const SizedBox(height: 6),

          Text(

            _resumenIA,

            style: TextStyle(

              fontSize: 13.5,

              height: 1.5,

              color: _sTextColor,

            ),

          ),

        ],

      ),

    );

  }



Widget _buildReactionsTableCard() {

    final listaReacFiltrada = _reaccionesFiltradas;



    return Container(

      decoration: _analyticalCardDecoration(),

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Row(

                children: [

                  Icon(Icons.people_alt_outlined, color: _fbBlue),

                  SizedBox(width: 8),

                  Text(

                    'Listado de reacciones por usuario y sentimiento contextual',

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.bold,

                      color: _pTextColor,

                    ),

                  ),

                ],

              ),

              Text(

                'Mostrando ${listaReacFiltrada.length} reacciones registradas',

                style: TextStyle(fontSize: 12.5, color: _sTextColor),

              ),

            ],

          ),

          const SizedBox(height: 14),

          Wrap(

            spacing: 10,

            runSpacing: 10,

            children: [

              for (final filtro in ['Todos', 'Positivos', 'Negativos', 'Neutros'])

                ChoiceChip(

                  label: Text(filtro),

                  selected: _filtroReacciones == filtro,

                  selectedColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFE7F3FF),

                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),

                  side: BorderSide(

                    color: _filtroReacciones == filtro

                        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF38BDF8) : _fbBlue)

                        : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),

                  ),

                  labelStyle: TextStyle(

                    color: _filtroReacciones == filtro

                        ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : _fbBlue)

                        : _sTextColor,

                    fontWeight: FontWeight.w600,

                    fontSize: 13,

                  ),

                  onSelected: (_) {

                    setState(() {

                      _filtroReacciones = filtro;

                    });

                  },

                ),

            ],

          ),

          const SizedBox(height: 16),

          if (listaReacFiltrada.isEmpty)

            Padding(

              padding: EdgeInsets.symmetric(vertical: 20.0),

              child: Center(

                child: Text(

                  'No hay reacciones registradas para el filtro seleccionado.',

                  style: TextStyle(color: _sTextColor),

                ),

              ),

            )

          else

            ClipRRect(

              borderRadius: BorderRadius.circular(8),

              child: Container(

                decoration: BoxDecoration(

                  border: Border.all(color: const Color(0xFFE2E8F0)),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: SingleChildScrollView(

                  scrollDirection: Axis.horizontal,

                  child: DataTable(

                    headingRowColor: WidgetStateProperty.all(_bgAnalyticalDyn),

                    columns: [DataColumn(

                        label: Text(

                          'Usuario que reaccionó',

                          style: TextStyle(fontWeight: FontWeight.bold, color: _pTextColor),

                        ),

                      ),

                      DataColumn(

                        label: Text(

                          'Reacción',

                          style: TextStyle(fontWeight: FontWeight.bold, color: _pTextColor),

                        ),

                      ),

                      DataColumn(

                        label: Text(

                          'Interpretación contextual (IA)',

                          style: TextStyle(fontWeight: FontWeight.bold, color: _pTextColor),

                        ),

                      ),

                      DataColumn(

                        label: Text(

                          'Sentimiento IA',

                          style: TextStyle(fontWeight: FontWeight.bold, color: _pTextColor),

                        ),

                      ),

                    ],

                    rows: listaReacFiltrada.map((item) {

                      final username = (item['username'] ?? 'Usuario').toString();

                      final avatarUrl = (item['avatar_url'] ?? '').toString();

                      final nombreReac = (item['reaccion'] ?? 'Me gusta').toString();

                      final explicacion = (item['explicacion'] ?? '').toString();

                      final sentiment = (item['sentiment'] ?? 'Positivo').toString();



                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      Color badgeBg;

                      Color badgeText;

                      if (sentiment == 'Positivo') {

                        badgeBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFD1FAE5);

                        badgeText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);

                      } else if (sentiment == 'Negativo') {

                        badgeBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFFEBE8);

                        badgeText = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFE41E3F);

                      } else {

                        badgeBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

                        badgeText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

                      }



                      final colorIcono = _colorPorReaccion(nombreReac);



                      return DataRow(

                        onSelectChanged: (_) => _mostrarDetalleComentario(item),

                        cells: [

                          DataCell(

                            Row(

                              children: [

                                _buildUserAvatar(username, avatarUrl),

                                const SizedBox(width: 10),

                                Text(

                                  username,

                                  style: TextStyle(

                                    fontWeight: FontWeight.w600,

                                    fontSize: 13,

                                    color: _pTextColor,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          DataCell(

                            Row(

                              children: [

                                CircleAvatar(

                                  radius: 13,

                                  backgroundColor: colorIcono.withValues(alpha: 0.12),

                                  child: Icon(

                                    _iconoPorReaccion(nombreReac),

                                    size: 15,

                                    color: colorIcono,

                                  ),

                                ),

                                const SizedBox(width: 8),

                                Text(

                                  nombreReac,

                                  style: TextStyle(

                                    fontWeight: FontWeight.bold,

                                    fontSize: 13,

                                    color: colorIcono,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          DataCell(

                            SizedBox(

                              width: 390,

                              child: Text(

                                explicacion,

                                style: TextStyle(fontSize: 13, color: _sTextColor),

                                maxLines: 2,

                                overflow: TextOverflow.ellipsis,

                              ),

                            ),

                          ),

                          DataCell(

                            Container(

                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),

                              decoration: BoxDecoration(

                                color: badgeBg,

                                borderRadius: BorderRadius.circular(12),

                              ),

                              child: Text(

                                sentiment,

                                style: TextStyle(

                                  fontSize: 12,

                                  fontWeight: FontWeight.bold,

                                  color: badgeText,

                                ),

                              ),

                            ),

                          ),

                        ],

                      );

                    }).toList(),

                  ),

                ),

              ),

            ),

        ],

      ),

    );

  }



  Widget _buildCommentsTableCard() {

    final listaFiltrada = _comentariosFiltrados;

    final opcionesFiltro = [

      'Todos',

      'Positivos',

      'Negativos',

      'Neutros',

      if (_totalBots > 0) 'Posibles bots',

    ];



    return Container(

      decoration: _analyticalCardDecoration(),

      padding: const EdgeInsets.all(22.0),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(

            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [

              Row(

                children: [

                  Icon(Icons.forum_outlined, color: _fbBlue),

                  SizedBox(width: 8),

                  Text(

                    'Listado de comentarios analizados con IA',

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight: FontWeight.bold,

                      color: _pTextColor,

                    ),

                  ),

                ],

              ),

              Text(

                'Mostrando ${listaFiltrada.length} de ${_comments.length} comentarios',

                style: TextStyle(fontSize: 12.5, color: _sTextColor),

              ),

            ],

          ),

          const SizedBox(height: 16),

          Wrap(

            spacing: 10,

            runSpacing: 10,

            crossAxisAlignment: WrapCrossAlignment.center,

            children: [

              for (final filtro in opcionesFiltro)

                ChoiceChip(

                  label: Text(filtro),

                  selected: _filtroSentimiento == filtro,

                  selectedColor: filtro == 'Posibles bots'

                      ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))

                      : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFE7F3FF)),

                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),

                  side: BorderSide(

                    color: _filtroSentimiento == filtro

                        ? (filtro == 'Posibles bots'

                            ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFF59E0B) : const Color(0xFFD97706))

                            : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF38BDF8) : _fbBlue))

                        : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),

                  ),

                  labelStyle: TextStyle(

                    color: _filtroSentimiento == filtro

                        ? (filtro == 'Posibles bots'

                            ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))

                            : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF93C5FD) : _fbBlue))

                        : _sTextColor,

                    fontWeight: FontWeight.w600,

                    fontSize: 13,

                  ),

                  onSelected: (_) {

                    setState(() {

                      _filtroSentimiento = filtro;

                    });

                  },

                ),

              SizedBox(

                width: 260,

                height: 38,

                child: TextField(

                  controller: _searchCommentController,

                  onChanged: (val) {

                    setState(() {

                      _busquedaTexto = val.trim();

                    });

                  },

                  decoration: InputDecoration(

                    hintText: 'Buscar por usuario o texto...',

                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),

                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: _sTextColor),

                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),

                    filled: true,

                    fillColor: _bgAnalyticalDyn,

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(20),

                      borderSide: BorderSide.none,

                    ),

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          if (listaFiltrada.isEmpty)

            Padding(

              padding: EdgeInsets.symmetric(vertical: 28.0),

              child: Center(

                child: Text(

                  _comments.isEmpty

                      ? 'Esta publicación no cuenta con comentarios para mostrar.'

                      : 'No hay comentarios que coincidan con el filtro seleccionado.',

                  style: TextStyle(color: _sTextColor),

                ),

              ),

            )

          else

            ClipRRect(

              borderRadius: BorderRadius.circular(8),

              child: Container(

                decoration: BoxDecoration(

                  border: Border.all(color: const Color(0xFFE2E8F0)),

                  borderRadius: BorderRadius.circular(8),

                ),

                child: SingleChildScrollView(

                  scrollDirection: Axis.horizontal,

                  child: DataTable(

                    headingRowColor: WidgetStateProperty.all(_bgAnalyticalDyn),

                    columns: [

                      DataColumn(

                        label: Text(

                          'Usuario que comentó',

                          style: TextStyle(

                            fontWeight: FontWeight.bold,

                            color: _pTextColor,

                          ),

                        ),

                      ),

                      DataColumn(

                        label: Text(

                          'Comentario',

                          style: TextStyle(

                            fontWeight: FontWeight.bold,

                            color: _pTextColor,

                          ),

                        ),

                      ),

                      DataColumn(

                        label: Text(

                          'Sentimiento IA',

                          style: TextStyle(

                            fontWeight: FontWeight.bold,

                            color: _pTextColor,

                          ),

                        ),

                      ),

                      if (_totalBots > 0)

                        DataColumn(

                          label: Text(

                            'Comentarios repetidos',

                            style: TextStyle(

                              fontWeight: FontWeight.bold,

                              color: _pTextColor,

                            ),

                          ),

                        ),

                    ],

                    rows: listaFiltrada.map((item) {

                      final username = (item['username'] ?? 'Usuario').toString();

                      final avatarUrl = (item['avatar_url'] ?? '').toString();

                      final commentText = (item['comment'] ?? '').toString();

                      final sentiment = (item['sentiment'] ?? 'Neutro').toString();

                      final esBot = item['es_bot'] == true;

                      final motivoBot = (item['motivo_bot'] ?? 'Orgánico').toString();



                      final isDark = Theme.of(context).brightness == Brightness.dark;

                      Color badgeBg;

                      Color badgeText;

                      if (sentiment == 'Positivo') {

                        badgeBg = isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFD1FAE5);

                        badgeText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);

                      } else if (sentiment == 'Negativo') {

                        badgeBg = isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFFEBE8);

                        badgeText = isDark ? const Color(0xFFFCA5A5) : const Color(0xFFE41E3F);

                      } else {

                        badgeBg = isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

                        badgeText = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

                      }



                      return DataRow(

                        cells: [

                          DataCell(

                            Row(

                              children: [

                                _buildUserAvatar(username, avatarUrl),

                                const SizedBox(width: 10),

                                Text(

                                  username,

                                  style: TextStyle(

                                    fontWeight: FontWeight.w600,

                                    fontSize: 13,

                                    color: _pTextColor,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          DataCell(

                            SizedBox(

                              width: 450,

                              child: Text(

                                commentText,

                                style: TextStyle(

                                  fontSize: 13,

                                  color: _pTextColor,

                                ),

                                overflow: TextOverflow.ellipsis,

                                maxLines: 2,

                              ),

                            ),

                          ),

                          DataCell(

                            Container(

                              padding: const EdgeInsets.symmetric(

                                horizontal: 12,

                                vertical: 4,

                              ),

                              decoration: BoxDecoration(

                                color: badgeBg,

                                borderRadius: BorderRadius.circular(12),

                              ),

                              child: Text(

                                sentiment,

                                style: TextStyle(

                                  fontSize: 12,

                                  fontWeight: FontWeight.bold,

                                  color: badgeText,

                                ),

                              ),

                            ),

                          ),

                          if (_totalBots > 0)

                            DataCell(

                              esBot

                                  ? Container(

                                      padding: const EdgeInsets.symmetric(

                                        horizontal: 10,

                                        vertical: 4,

                                      ),

                                      decoration: BoxDecoration(

                                        color: const Color(0xFFFEF3C7),

                                        borderRadius: BorderRadius.circular(12),

                                        border: Border.all(color: const Color(0xFFF59E0B)),

                                      ),

                                      child: Text(

                                        motivoBot,

                                        style: const TextStyle(

                                          fontSize: 11.5,

                                          fontWeight: FontWeight.w600,

                                          color: Color(0xFFB45309),

                                        ),

                                      ),

                                    )

                                  : Text(

                                      'Orgánico',

                                      style: TextStyle(fontSize: 12, color: _sTextColor),

                                    ),

                            ),

                        ],

                      );

                    }).toList(),

                  ),

                ),

              ),

            ),

        ],

      ),

    );

  }

}