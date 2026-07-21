import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/bloqueo.dart';

class MapWidget extends StatefulWidget {
  final MapController mapController;
  final LatLng userLocation;
  final List<Bloqueo> bloqueos;
  final List<LatLng>? rutaDirecta;
  final List<LatLng>? rutaAlterna;
  final bool modoReporte;
  final LatLng? posicionSeleccionadaReporte;
  final Function(LatLng) onMapClick;
  final Function(Bloqueo) onBloqueoTap;
  final Function(Bloqueo) onBloqueoLongPress;
  final String estiloMapa; // 'standard' | 'satelite' | 'oscuro' | 'topografico' | 'retro'

  const MapWidget({
    super.key,
    required this.mapController,
    required this.userLocation,
    required this.bloqueos,
    this.rutaDirecta,
    this.rutaAlterna,
    required this.modoReporte,
    this.posicionSeleccionadaReporte,
    required this.onMapClick,
    required this.onBloqueoTap,
    required this.onBloqueoLongPress,
    required this.estiloMapa,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Controlador para el punto guía viajante de la ruta
  late AnimationController _routeTravelerController;
  
  StreamSubscription? _mapEventSubscription;
  double _mapRotation = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseController.repeat();

    _routeTravelerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    // Suscribir a los eventos del mapa para rastrear la rotación en tiempo real
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapEventSubscription = widget.mapController.mapEventStream.listen((event) {
        if (mounted) {
          setState(() {
            _mapRotation = widget.mapController.camera.rotation;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _routeTravelerController.dispose();
    _mapEventSubscription?.cancel();
    super.dispose();
  }

  Color _getColorForTipo(String tipo) {
    switch (tipo) {
      case 'manifestacion':
        return const Color(0xFFDC2626);
      case 'obra':
        return const Color(0xFFF59E0B);
      case 'accidente':
        return const Color(0xFFEA580C);
      case 'conflicto':
        return const Color(0xFFB91C1C);
      case 'derrumbe':
        return const Color(0xFF78716C);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getIconForTipo(String tipo) {
    switch (tipo) {
      case 'manifestacion':
        return Icons.campaign;
      case 'obra':
        return Icons.construction;
      case 'accidente':
        return Icons.car_crash;
      case 'conflicto':
        return Icons.local_fire_department;
      case 'derrumbe':
        return Icons.terrain;
      default:
        return Icons.warning;
    }
  }

  // Algoritmo manual de agrupamiento (Clustering) de pines por proximidad (menos de 8 km)
  List<List<Bloqueo>> _generarClusters(List<Bloqueo> bloqueos) {
    final List<List<Bloqueo>> clusters = [];
    const double maxDistanciaKm = 8.0;

    for (final bloqueo in bloqueos) {
      bool agrupado = false;
      for (final cluster in clusters) {
        final primeraReferencia = cluster.first;
        final double distanciaMts = Geolocator.distanceBetween(
          bloqueo.lat,
          bloqueo.lng,
          primeraReferencia.lat,
          primeraReferencia.lng,
        );
        
        if ((distanciaMts / 1000.0) < maxDistanciaKm) {
          cluster.add(bloqueo);
          agrupado = true;
          break;
        }
      }
      
      if (!agrupado) {
        clusters.add([bloqueo]);
      }
    }
    return clusters;
  }

  String _getTileUrl() {
    switch (widget.estiloMapa) {
      case 'satelite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'oscuro':
        return 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
      case 'topografico':
        return 'https://tile.opentopomap.org/{z}/{x}/{y}.png';
      case 'retro':
        return 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case 'standard':
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
  }

  // Interpola puntos para posicionar el viajero a lo largo del trayecto
  LatLng? _obtenerPuntoViajero(List<LatLng> ruta, double progress) {
    if (ruta.isEmpty) return null;
    final int totalPuntos = ruta.length;
    final double indexExacto = (totalPuntos - 1) * progress;
    final int indexPiso = indexExacto.floor();
    final int indexTecho = math.min(indexPiso + 1, totalPuntos - 1);
    final double t = indexExacto - indexPiso;
    
    final p1 = ruta[indexPiso];
    final p2 = ruta[indexTecho];
    
    final lat = p1.latitude + (p2.latitude - p1.latitude) * t;
    final lng = p1.longitude + (p2.longitude - p1.longitude) * t;
    
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final List<Marker> markers = [];
    final List<List<Bloqueo>> clusters = _generarClusters(widget.bloqueos);

    for (final cluster in clusters) {
      if (cluster.length == 1) {
        final bloqueo = cluster.first;
        final color = _getColorForTipo(bloqueo.tipo);
        markers.add(
          Marker(
            point: LatLng(bloqueo.lat, bloqueo.lng),
            width: 60,
            height: 60,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () => widget.onBloqueoTap(bloqueo),
              onLongPress: () => widget.onBloqueoLongPress(bloqueo),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anillo de pulso/radar dinámico WAOS (dos ondas concéntricas)
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: (1.0 - _pulseAnimation.value) * 0.7,
                            child: Transform.scale(
                              scale: 1.0 + _pulseAnimation.value * 1.7,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.35),
                                ),
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: (1.0 - ((_pulseAnimation.value + 0.5) % 1.0)) * 0.4,
                            child: Transform.scale(
                              scale: 1.0 + ((_pulseAnimation.value + 0.5) % 1.0) * 1.3,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color.withOpacity(0.25),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  Transform.rotate(
                    angle: -math.pi / 4,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.95),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(2),
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 17,
                    child: Icon(
                      _getIconForTipo(bloqueo.tipo),
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else {
        final referencia = cluster.first;
        markers.add(
          Marker(
            point: LatLng(referencia.lat, referencia.lng),
            width: 55,
            height: 55,
            alignment: Alignment.center,
            child: GestureDetector(
              onTap: () {
                widget.mapController.move(
                  LatLng(referencia.lat, referencia.lng), 
                  widget.mapController.camera.zoom + 2
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5B34).withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFBF5B34),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${cluster.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // Marcador del usuario actual con pulso
    markers.add(
      Marker(
        point: widget.userLocation,
        width: 65,
        height: 65,
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: 1.0 - _pulseAnimation.value,
                  child: Transform.scale(
                    scale: 1.0 + _pulseAnimation.value * 1.6,
                    child: Container(
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.withOpacity(0.4),
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Indicador viajante en ruta activa (Pulsante cian)
    if (widget.rutaDirecta != null && widget.rutaDirecta!.isNotEmpty) {
      final viajeroPoint = _obtenerPuntoViajero(widget.rutaDirecta!, _routeTravelerController.value);
      if (viajeroPoint != null) {
        markers.add(
          Marker(
            point: viajeroPoint,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Opacity(
                      opacity: 1.0 - _pulseAnimation.value,
                      child: Transform.scale(
                        scale: 1.0 + _pulseAnimation.value * 1.8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.cyanAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent,
                            blurRadius: 10,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      }
    }

    if (widget.modoReporte && widget.posicionSeleccionadaReporte != null) {
      markers.add(
        Marker(
          point: widget.posicionSeleccionadaReporte!,
          width: 55,
          height: 55,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFFBF5B34),
                size: 38,
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFBF5B34),
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: const Text(
                  'Bloqueo aquí',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: widget.mapController,
          options: MapOptions(
            initialCenter: widget.userLocation,
            initialZoom: 12.0,
            minZoom: 5.0,
            maxZoom: 18.0,
            onTap: (tapPosition, point) {
              widget.onMapClick(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: _getTileUrl(),
              userAgentPackageName: 'mx.vialibre.app',
            ),
            PolylineLayer(
              polylines: [
                if (widget.rutaDirecta != null && widget.rutaDirecta!.isNotEmpty)
                  Polyline(
                    points: widget.rutaDirecta!,
                    strokeWidth: 6.0,
                    color: Colors.blue.withOpacity(0.85),
                  ),
                if (widget.rutaAlterna != null && widget.rutaAlterna!.isNotEmpty)
                  Polyline(
                    points: widget.rutaAlterna!,
                    strokeWidth: 6.0,
                    color: const Color(0xFF2F5D4C).withOpacity(0.85),
                    isDotted: true,
                  ),
              ],
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        
        // BRÚJULA DINÁMICA FLOTANTE
        if (_mapRotation != 0.0)
          Positioned(
            top: 100,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'compass_fab',
              onPressed: () {
                widget.mapController.rotate(0.0);
                HapticFeedback.lightImpact();
              },
              backgroundColor: Colors.white.withOpacity(0.95),
              foregroundColor: const Color(0xFF2F5D4C),
              child: Transform.rotate(
                angle: -_mapRotation * math.pi / 180,
                child: const Icon(Icons.navigation, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
