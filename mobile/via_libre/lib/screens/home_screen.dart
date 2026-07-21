import 'dart:async';
import 'dart:math' as math;
import 'dart:ui'; // Necesario para ImageFilter (glassmorphism)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart'; // Para distancias y velocidad
import 'package:flutter_tts/flutter_tts.dart'; // Para alertas de voz locales
import 'package:latlong2/latlong.dart';
import '../main.dart';
import '../models/bloqueo.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'widgets/map_widget.dart';
import 'widgets/feed_panel.dart';
import 'widgets/route_panel.dart';
import 'widgets/report_sheet.dart';
import 'widgets/interactive_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FlutterTts _flutterTts = FlutterTts();

  LatLng _userLocation = LocationService.centroIstmoDefault;
  List<Bloqueo> _bloqueos = [];
  Map<String, int> _conteos = {'activos': 0, 'programados': 0, 'finalizados': 0};
  
  bool _cargando = false;
  String _estadoFiltro = 'activo';
  
  bool _modoReporte = false;
  LatLng? _posicionSeleccionadaReporte;
  
  bool _panelBuscarRuta = false;
  ResultadoRuta? _resultadoRuta;
  List<LatLng>? _rutaDirectaGeometria;
  List<LatLng>? _rutaAlternaGeometria;

  // Parámetros de velocidad, capas, alarmas y filtros
  double _velocidadKmh = 0.0;
  String? _estiloMapaManualmenteSeleccionado;
  DateTime? _lastAlertSoundTime;

  final Map<String, bool> _tiposFiltroSeleccionados = {
    'manifestacion': true,
    'obra': true,
    'accidente': true,
    'conflicto': true,
    'derrumbe': true,
  };
  double? _distanciaFiltroMaxKm;

  List<Bloqueo> get _bloqueosFiltrados {
    return _bloqueos.where((b) {
      if (_tiposFiltroSeleccionados[b.tipo] != true) return false;
      if (_distanciaFiltroMaxKm != null) {
        final double distMts = Geolocator.distanceBetween(
          _userLocation.latitude,
          _userLocation.longitude,
          b.lat,
          b.lng,
        );
        if ((distMts / 1000.0) > _distanciaFiltroMaxKm!) return false;
      }
      return true;
    }).toList();
  }

  // Historial de alertas de voz realizadas por proximidad
  final Set<String> _bloqueosAdvertidos = {};

  // Tooltip flotante para clic sostenido
  Bloqueo? _bloqueoConTooltipActivo;
  Timer? _tooltipTimer;

  StreamSubscription? _locationSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
    _cargarDatos();
    
    // Timer para refrescar datos cada 30 segundos
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _cargarDatos());
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _refreshTimer?.cancel();
    _tooltipTimer?.cancel();
    _mapController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _inicializarUbicacion() async {
    final pos = await _locationService.obtenerPosicionActual();
    setState(() {
      _userLocation = pos;
    });
    _mapController.move(_userLocation, 12.0);

    // Escuchar actualizaciones de GPS en segundo plano
    _locationSubscription = _locationService.obtenerStreamUbicacion().listen((position) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _velocidadKmh = position.speed * 3.6; // m/s a km/h
        });
        _checarAlertasProximidad();
        _checarExcesoVelocidad();
      }
    });
  }

  // Verifica distancias locales y gatilla Text-To-Speech si está a menos de 3.0 km
  void _checarAlertasProximidad() {
    if (_bloqueos.isEmpty) return;
    
    for (final b in _bloqueos) {
      if (b.estado != 'activo') continue;
      if (_bloqueosAdvertidos.contains(b.id)) continue;
      
      final double distMts = Geolocator.distanceBetween(
        _userLocation.latitude,
        _userLocation.longitude,
        b.lat,
        b.lng,
      );
      
      if (distMts < 3000.0) { // 3 Kilómetros
        _bloqueosAdvertidos.add(b.id);
        _reproducirAlertaVoz(b);
        break; // Reproducir una sola alerta consecutiva
      }
    }
  }

  Future<void> _reproducirAlertaVoz(Bloqueo b) async {
    try {
      final tipoEs = b.tipo == 'manifestacion'
          ? 'una manifestación'
          : b.tipo == 'obra'
              ? 'obras de pavimentación'
              : b.tipo == 'accidente'
                  ? 'un accidente vial'
                  : b.tipo == 'derrumbe'
                      ? 'un derrumbe de escombros'
                      : 'un bloqueo social';
      final texto = 'Alerta: se detecta $tipoEs a menos de tres kilómetros, en el municipio de ${b.municipio.isNotEmpty ? b.municipio : 'la zona'}.';
      
      await _flutterTts.setLanguage("es-MX");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.speak(texto);
    } catch (_) {}
  }

  Future<void> _cargarDatos() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
    });

    try {
      final list = await _apiService.listarBloqueos(_estadoFiltro);
      final summary = await _apiService.resumen();
      
      if (mounted) {
        setState(() {
          _bloqueos = list;
          _conteos = summary;
        });
        
        if (ApiService.isOffline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Sin conexión a internet. Mostrando datos locales (Caché).'),
              backgroundColor: Color(0xFFBF5B34),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al conectar con la API de AWS')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _onFiltroChanged(String nuevoFiltro) {
    setState(() {
      _estadoFiltro = nuevoFiltro;
    });
    _cargarDatos();
  }

  void _onConfirmar(String id, String voto) async {
    // Sonido háptico medio al votar
    HapticFeedback.mediumImpact();
    final actualizado = await _apiService.confirmar(id, voto);
    if (actualizado != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              voto == 'sigue'
                  ? 'Confirmación registrada: Sigue ahí.'
                  : 'Reportado como liberado.',
            ),
            backgroundColor: voto == 'sigue' ? const Color(0xFF2F5D4C) : const Color(0xFFBF5B34),
          ),
        );
        _cargarDatos();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo registrar tu confirmación.')),
        );
      }
    }
  }

  void _onMapClick(LatLng point) {
    if (_modoReporte) {
      setState(() {
        _posicionSeleccionadaReporte = point;
      });
    }
  }

  void _mostrarTooltip(Bloqueo b) {
    _tooltipTimer?.cancel();
    HapticFeedback.selectionClick(); // Vibración rápida al sostener marcador
    setState(() {
      _bloqueoConTooltipActivo = b;
    });
    _tooltipTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _bloqueoConTooltipActivo = null;
        });
      }
    });
  }

  void _onBloqueoTap(Bloqueo b) {
    _mapController.move(LatLng(b.lat, b.lng), 14.0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5B34).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      b.tipo.toUpperCase(),
                      style: const TextStyle(color: Color(0xFFBF5B34), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    b.verificado == true ? '✓ Verificado' : 'Por verificar',
                    style: TextStyle(
                      color: b.verificado == true ? const Color(0xFF4A8B71) : Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                b.municipio.isNotEmpty ? b.municipio : 'Incidente reportado',
                style: const TextStyle(fontFamily: 'Playfair Display', fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (b.descripcion.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(b.descripcion, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
              ],
              if (b.rutaAlternaTexto != null && b.rutaAlternaTexto!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Desvío sugerido: ${b.rutaAlternaTexto}',
                  style: const TextStyle(color: Color(0xFF4A8B71), fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  InteractiveButton(
                    onPressed: () => _onConfirmar(b.id, 'liberado'),
                    child: OutlinedButton.icon(
                      onPressed: null, // Controlado por InteractiveButton
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFBF5B34)),
                      ),
                      icon: const Icon(Icons.remove_road, color: Color(0xFFBF5B34)),
                      label: const Text('Ya se liberó', style: TextStyle(color: Color(0xFFBF5B34))),
                    ),
                  ),
                  InteractiveButton(
                    onPressed: () => _onConfirmar(b.id, 'sigue'),
                    child: ElevatedButton.icon(
                      onPressed: null, // Controlado por InteractiveButton
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F5D4C)),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Sigue ahí', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _enviarReporte(Map<String, dynamic> datos) async {
    // Háptico medio al enviar
    HapticFeedback.mediumImpact();
    final imageFile = datos['foto'];
    String? fotoUrl;
    
    if (imageFile != null) {
      fotoUrl = await _apiService.subirFoto(imageFile);
    }

    final result = await _apiService.crearBloqueo(
      tipo: datos['tipo'],
      lat: datos['lat'],
      lng: datos['lng'],
      descripcion: datos['descripcion'],
      municipio: datos['municipio'],
      fotoUrl: fotoUrl,
      estado: datos['estado'],
      iniciaEn: datos['inicia_en'],
      rutaAlternaTexto: datos['ruta_alterna_texto'],
    );

    if (result != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Reporte enviado con éxito! Gracias por informar.')),
        );
        setState(() {
          _modoReporte = false;
          _posicionSeleccionadaReporte = null;
        });
        _cargarDatos();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar el reporte.')),
        );
      }
    }
  }

  void _onRutaCalculada(ResultadoRuta? resultado) {
    setState(() {
      _resultadoRuta = resultado;
      if (resultado == null) {
        _rutaDirectaGeometria = null;
        _rutaAlternaGeometria = null;
      } else {
        _rutaDirectaGeometria = resultado.directa.geometria
            .map((c) => LatLng(c.lat, c.lng))
            .toList();
        if (resultado.alternativas.isNotEmpty) {
          _rutaAlternaGeometria = resultado.alternativas[0].geometria
              .map((c) => LatLng(c.lat, c.lng))
              .toList();
        }
      }
    });

    if (resultado != null) {
      // Enfocar la cámara en la ruta
      _mapController.move(LatLng(resultado.origen.lat, resultado.origen.lng), 11.0);
    }
  }

  void _onRutaSeleccionada(int index) {
    if (_resultadoRuta == null) return;
    setState(() {
      if (index == 0) {
        _rutaDirectaGeometria = _resultadoRuta!.directa.geometria
            .map((c) => LatLng(c.lat, c.lng))
            .toList();
        _rutaAlternaGeometria = null;
      } else {
        _rutaDirectaGeometria = null;
        _rutaAlternaGeometria = _resultadoRuta!.alternativas[index - 1].geometria
            .map((c) => LatLng(c.lat, c.lng))
            .toList();
      }
    });
  }

  Widget _buildDrawer() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090E17) : const Color(0xFF2F5D4C),
              image: DecorationImage(
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(isDark ? 0.70 : 0.45),
                  BlendMode.darken,
                ),
                image: const NetworkImage(
                  'https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?q=80&w=600&auto=format&fit=crop',
                ),
              ),
            ),
            currentAccountPicture: Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white24,
              ),
              padding: const EdgeInsets.all(4),
              child: const CircleAvatar(
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
                ),
              ),
            ),
            accountName: const Text(
              'Usuario Demo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
            accountEmail: const Text(
              'istmo.vecino@vialibre.mx',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          ListTile(
            leading: Icon(Icons.person, color: isDark ? Colors.white70 : const Color(0xFF78716C)),
            title: const Text('Mi Cuenta'),
            subtitle: const Text('Configurar perfil y reputación'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sección de Cuenta (Próximamente disponible)')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings, color: isDark ? Colors.white70 : const Color(0xFF78716C)),
            title: const Text('Configuración'),
            subtitle: const Text('Radio de alertas, URL del API'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sección de Configuración (Próximamente disponible)')),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.bar_chart, color: isDark ? Colors.white70 : const Color(0xFF78716C)),
            title: const Text('Estadísticas Semanales'),
            subtitle: const Text('Resumen histórico de bloqueos por día'),
            onTap: () {
              Navigator.pop(context);
              _mostrarEstadisticasSemanales();
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Modo Oscuro'),
            subtitle: const Text('Cambiar apariencia visual'),
            value: isDark,
            activeColor: const Color(0xFFBF5B34),
            secondary: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode,
              color: isDark ? const Color(0xFFBF5B34) : Colors.amber,
            ),
            onChanged: (val) {
              ViaLibreApp.of(context).toggleTheme(val);
              setState(() {
                _estiloMapaManualmenteSeleccionado = val ? 'oscuro' : 'standard';
              });
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Vía Libre Oaxaca v1.0.0',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSelectorCapas() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final estiloActual = _estiloMapaManualmenteSeleccionado ?? (isDark ? 'oscuro' : 'standard');

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget itemCapa(String id, String titulo, IconData icono, String desc) {
              final active = estiloActual == id;
              final colorIcono = active ? const Color(0xFFBF5B34) : (isDark ? Colors.white70 : const Color(0xFF2F5D4C));
              
              return InkWell(
                onTap: () {
                  setState(() {
                    _estiloMapaManualmenteSeleccionado = id;
                  });
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: active 
                        ? const Color(0xFFBF5B34).withOpacity(0.08) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active 
                          ? const Color(0xFFBF5B34) 
                          : (isDark ? Colors.grey[800]! : const Color(0xFFE2D6C5)),
                      width: active ? 1.8 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: active ? const Color(0xFFBF5B34).withOpacity(0.15) : (isDark ? Colors.white10 : Colors.grey[100]),
                        ),
                        child: Icon(icono, color: colorIcono, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              titulo,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: active ? const Color(0xFFBF5B34) : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (active)
                        const Icon(Icons.check_circle, color: Color(0xFFBF5B34), size: 20),
                    ],
                  ),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      'Selecciona el estilo del mapa',
                      style: TextStyle(
                        fontFamily: 'Playfair Display',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  itemCapa('standard', 'Estándar (Callejero)', Icons.map_outlined, 'Diseño clásico ideal para navegar por calles.'),
                  itemCapa('satelite', 'Satélite (Foto Aérea)', Icons.satellite_outlined, 'Detalle fotográfico real del terreno.'),
                  itemCapa('oscuro', 'Modo Oscuro (Noche)', Icons.dark_mode_outlined, 'Esquema de alto contraste ideal para conducir de noche.'),
                  itemCapa('topografico', 'Relieve (Topográfico)', Icons.terrain_outlined, 'Mapas de elevación, montañas y curvas de nivel.'),
                  itemCapa('retro', 'Retro (Aventura)', Icons.explore_outlined, 'Tonalidades cálidas y suaves de estilo clásico.'),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _checarExcesoVelocidad() {
    if (_velocidadKmh > 90.0) {
      final now = DateTime.now();
      if (_lastAlertSoundTime == null || now.difference(_lastAlertSoundTime!) > const Duration(seconds: 3)) {
        _lastAlertSoundTime = now;
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.heavyImpact();
      }
    }
  }

  void _mostrarFiltrosAvanzados() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final double valorSlider = _distanciaFiltroMaxKm ?? 100.0;

            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros del Mapa',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _distanciaFiltroMaxKm == null 
                        ? 'Distancia: Mostrar Todos' 
                        : 'Distancia máxima: ${_distanciaFiltroMaxKm!.toStringAsFixed(0)} km',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: valorSlider,
                    min: 5.0,
                    max: 100.0,
                    divisions: 19,
                    activeColor: const Color(0xFFBF5B34),
                    inactiveColor: isDark ? Colors.grey[800] : Colors.grey[300],
                    onChanged: (val) {
                      setModalState(() {
                        setState(() {
                          _distanciaFiltroMaxKm = val == 100.0 ? null : val;
                        });
                      });
                    },
                  ),
                  const Divider(),
                  const Text(
                    'Tipos de Incidentes',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _tiposFiltroSeleccionados.keys.map((tipo) {
                      final seleccionado = _tiposFiltroSeleccionados[tipo] ?? false;
                      final String nombreLabel = tipo == 'manifestacion' 
                          ? 'Manifestación' 
                          : tipo == 'obra' 
                              ? 'Obra vial' 
                              : tipo == 'accidente' 
                                  ? 'Accidente' 
                                  : tipo == 'derrumbe' 
                                      ? 'Derrumbe' 
                                      : 'Conflicto';
                      return FilterChip(
                        selected: seleccionado,
                        label: Text(nombreLabel),
                        selectedColor: const Color(0xFFBF5B34).withOpacity(0.2),
                        checkmarkColor: const Color(0xFFBF5B34),
                        onSelected: (val) {
                          setModalState(() {
                            setState(() {
                              _tiposFiltroSeleccionados[tipo] = val;
                            });
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBF5B34)),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Aplicar Filtros', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarEstadisticasSemanales() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Map<int, int> conteoDias = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0};
    for (final b in _bloqueos) {
      final dt = DateTime.tryParse(b.creadoEn);
      if (dt != null) {
        final day = dt.toLocal().weekday;
        conteoDias[day] = (conteoDias[day] ?? 0) + 1;
      }
    }

    int maxVal = 0;
    for (final v in conteoDias.values) {
      if (v > maxVal) maxVal = v;
    }

    final List<String> nombresDias = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.cardTheme.color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Estadísticas Semanales',
            style: TextStyle(fontFamily: 'Playfair Display', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bloqueos totales en caché local: ${_bloqueos.length}',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
              ),
              const SizedBox(height: 24),
              Container(
                height: 160,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final day = index + 1;
                    final total = conteoDias[day] ?? 0;
                    final double height = maxVal == 0 ? 0.0 : (total / maxVal) * 110;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (total > 0)
                          Text(
                            '$total',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFBF5B34)),
                          ),
                        const SizedBox(height: 4),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          width: 18,
                          height: math.max(height, 4.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: const LinearGradient(
                              colors: [Color(0xFFBF5B34), Color(0xFFEA580C)],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nombresDias[index],
                          style: TextStyle(
                            fontSize: 11, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white60 : Colors.grey[700]
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Resumen de días con mayor incidencia vial en Oaxaca.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar', style: TextStyle(color: Color(0xFFBF5B34), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Stack(
          children: [
            // MAPA (FONDO)
            MapWidget(
              mapController: _mapController,
              userLocation: _userLocation,
              bloqueos: _bloqueosFiltrados,
              rutaDirecta: _rutaDirectaGeometria,
              rutaAlterna: _rutaAlternaGeometria,
              modoReporte: _modoReporte,
              posicionSeleccionadaReporte: _posicionSeleccionadaReporte,
              onMapClick: _onMapClick,
              onBloqueoTap: _onBloqueoTap,
              onBloqueoLongPress: _mostrarTooltip,
              estiloMapa: _estiloMapaManualmenteSeleccionado ?? (isDark ? 'oscuro' : 'standard'),
            ),

            // CABECERA SUPERIOR (FLOTANTE CON EFECTO GLASSMORPHISM)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? const Color(0xFF090E17).withOpacity(0.80) 
                              : Colors.white.withOpacity(0.82),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isDark 
                                ? Colors.white.withOpacity(0.12) 
                                : const Color(0xFFBF5B34).withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            InteractiveButton(
                              onPressed: () {
                                _scaffoldKey.currentState?.openDrawer();
                              },
                              child: IconButton(
                                icon: Icon(Icons.menu, color: isDark ? Colors.white70 : const Color(0xFF2F5D4C)),
                                onPressed: null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Vía Libre',
                              style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                              ),
                            ),
                            const SizedBox(width: 8),
                            
                            // Badge que coincide de forma coherente con el filtro activo actual
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFBF5B34),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _estadoFiltro == 'activo'
                                    ? '${_conteos['activos']} activos'
                                    : _estadoFiltro == 'programado'
                                        ? '${_conteos['programados']} prog.'
                                        : '${_conteos['finalizados']} fin.',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Spacer(),
                            
                            // Botón de alternancia de Capas del Mapa (Selector modal)
                            InteractiveButton(
                              onPressed: _mostrarSelectorCapas,
                              child: IconButton(
                                icon: Icon(
                                  Icons.layers,
                                  color: isDark ? Colors.white70 : const Color(0xFF2F5D4C),
                                ),
                                onPressed: null, // Controlado por InteractiveButton
                              ),
                            ),
                            const SizedBox(width: 4),

                            // Botón de Filtros Avanzados
                            InteractiveButton(
                              onPressed: _mostrarFiltrosAvanzados,
                              child: IconButton(
                                icon: Icon(
                                  Icons.tune,
                                  color: isDark ? Colors.white70 : const Color(0xFF2F5D4C),
                                ),
                                onPressed: null, // Controlado por InteractiveButton
                              ),
                            ),
                            const SizedBox(width: 4),
                            
                            InteractiveButton(
                              onPressed: () {
                                setState(() {
                                  _panelBuscarRuta = !_panelBuscarRuta;
                                });
                              },
                              child: IconButton(
                                icon: Icon(
                                  _panelBuscarRuta ? Icons.alt_route : Icons.search,
                                  color: isDark ? Colors.white70 : const Color(0xFF2F5D4C),
                                ),
                                onPressed: null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (ApiService.isOffline) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBF5B34).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Modo offline (Datos locales)',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // TOOLTIP FLOTANTE CON ANIMACIÓN DE ENTRADA ELÁSTICA Y GLASSMORPHISM
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              top: _bloqueoConTooltipActivo != null ? 86 : -130,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _bloqueoConTooltipActivo != null ? 1.0 : 0.0,
                child: _bloqueoConTooltipActivo == null
                    ? const SizedBox.shrink()
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? const Color(0xFF090E17).withOpacity(0.80) 
                                  : Colors.white.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFBF5B34).withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info, color: Color(0xFFBF5B34), size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _bloqueoConTooltipActivo!.municipio.isNotEmpty 
                                            ? _bloqueoConTooltipActivo!.municipio 
                                            : 'Incidente Reportado',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _bloqueoConTooltipActivo!.descripcion.isNotEmpty
                                            ? _bloqueoConTooltipActivo!.descripcion
                                            : 'Sin descripción adicional.',
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.touch_app, color: Colors.grey, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),

            // BUSCADOR DE RUTA FLOTANTE
            if (_panelBuscarRuta)
              Positioned(
                top: 86,
                left: 16,
                right: 16,
                child: RoutePanel(
                  onRutaCalculada: _onRutaCalculada,
                  onRutaSeleccionada: _onRutaSeleccionada,
                  onCerrar: () {
                    setState(() {
                      _panelBuscarRuta = false;
                    });
                  },
                ),
              ),

            // VELOCÍMETRO DIGITAL EN VIVO (ESQUINA INFERIOR IZQUIERDA)
            if (!_modoReporte)
              Positioned(
                bottom: 260,
                left: 16,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? const Color(0xFF090E17).withOpacity(0.78) 
                            : Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _velocidadKmh > 90.0 
                              ? const Color(0xFFDC2626) 
                              : (isDark 
                                  ? Colors.white.withOpacity(0.12) 
                                  : const Color(0xFFBF5B34).withOpacity(0.22)),
                          width: _velocidadKmh > 90.0 ? 2.2 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _velocidadKmh > 90.0 
                                ? const Color(0xFFDC2626).withOpacity(0.35) 
                                : Colors.black.withOpacity(0.1),
                            blurRadius: _velocidadKmh > 90.0 ? 12 : 6,
                            spreadRadius: _velocidadKmh > 90.0 ? 2 : 0,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.speed,
                                color: _velocidadKmh > 90
                                    ? const Color(0xFFDC2626)
                                    : (isDark ? Colors.white70 : const Color(0xFF2F5D4C)),
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_velocidadKmh.toStringAsFixed(0)} km/h',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                                ),
                              ),
                            ],
                          ),
                          if (_velocidadKmh < 5.0 && _bloqueos.any((b) => b.estado == 'activo')) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'Tránsito detenido',
                              style: TextStyle(color: Color(0xFFBF5B34), fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // BOTÓN GPS Y FAB DE REPORTAR
            if (!_modoReporte)
              Positioned(
                bottom: 260,
                right: 16,
                child: Column(
                  children: [
                    InteractiveButton(
                      onPressed: () {
                        _mapController.move(_userLocation, 14.0);
                      },
                      child: FloatingActionButton.small(
                        heroTag: 'gps_fab',
                        onPressed: null,
                        backgroundColor: theme.cardTheme.color,
                        foregroundColor: isDark ? Colors.white70 : const Color(0xFF2F5D4C),
                        child: const Icon(Icons.my_location),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InteractiveButton(
                      onPressed: () {
                        setState(() {
                          _modoReporte = true;
                          _posicionSeleccionadaReporte = null;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Toca el mapa para seleccionar la ubicación del bloqueo'),
                            duration: Duration(seconds: 4),
                          ),
                        );
                      },
                      child: const FloatingActionButton(
                        heroTag: 'report_fab',
                        onPressed: null,
                        backgroundColor: Color(0xFFBF5B34),
                        foregroundColor: Colors.white,
                        child: Icon(Icons.add, size: 28),
                      ),
                    ),
                  ],
                ),
              ),

            // DRAGGABLE SCROLLABLE SHEET: FEED DE REPORTES
            if (!_modoReporte)
              DraggableScrollableSheet(
                initialChildSize: 0.22,
                minChildSize: 0.10,
                maxChildSize: 0.85,
                builder: (context, scrollController) {
                  return SingleChildScrollView(
                    controller: scrollController,
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.85,
                      child: FeedPanel(
                        bloqueos: _bloqueosFiltrados,
                        estadoFiltro: _estadoFiltro,
                        onFiltroChanged: _onFiltroChanged,
                        onCardTap: (b) {
                          _mapController.move(LatLng(b.lat, b.lng), 13.0);
                        },
                        onConfirmar: _onConfirmar,
                        cargando: _cargando,
                      ),
                    ),
                  );
                },
              ),

            // FORMULARIO DE REPORTAR (SI SE ENTRA A MODO REPORTAR)
            if (_modoReporte)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _posicionSeleccionadaReporte == null
                    ? Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '📍 Toca el mapa para ubicar el bloqueo',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _modoReporte = false;
                                });
                              },
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBF5B34)),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    : ReportSheet(
                        posicion: _posicionSeleccionadaReporte!,
                        onEnviar: _enviarReporte,
                        onCancelar: () {
                          setState(() {
                            _modoReporte = false;
                            _posicionSeleccionadaReporte = null;
                          });
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
