import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/bloqueo.dart';
import '../../../services/api_service.dart';

class RoutePanel extends StatefulWidget {
  final Function(ResultadoRuta?) onRutaCalculada;
  final Function(int) onRutaSeleccionada; // 0 for directa, 1 for alternativa
  final Function() onCerrar;

  const RoutePanel({
    super.key,
    required this.onRutaCalculada,
    required this.onRutaSeleccionada,
    required this.onCerrar,
  });

  @override
  State<RoutePanel> createState() => _RoutePanelState();
}

class _RoutePanelState extends State<RoutePanel> {
  final ApiService _apiService = ApiService();
  
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  
  Lugar? _origenSeleccionado;
  Lugar? _destinoSeleccionado;
  
  List<Lugar> _sugerencias = [];
  bool _esSugerenciaParaOrigen = true;
  bool _calculandoRuta = false;
  
  Timer? _debounce;
  ResultadoRuta? _resultadoRuta;
  int _indiceRutaActiva = 0;

  @override
  void dispose() {
    _origenController.dispose();
    _destinoController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query, bool isOrigen) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.trim().length < 3) {
        setState(() {
          _sugerencias = [];
        });
        return;
      }
      
      setState(() {
        _esSugerenciaParaOrigen = isOrigen;
      });
      
      final results = await _apiService.geocodificar(query);
      
      setState(() {
        _sugerencias = results;
      });
    });
  }

  Future<void> _calcularRuta() async {
    if (_origenSeleccionado == null || _destinoSeleccionado == null) return;
    
    setState(() {
      _calculandoRuta = true;
      _resultadoRuta = null;
    });

    final origen = Coordenada(lat: _origenSeleccionado!.lat, lng: _origenSeleccionado!.lng);
    final destino = Coordenada(lat: _destinoSeleccionado!.lat, lng: _destinoSeleccionado!.lng);

    final resultado = await _apiService.buscarRuta(origen, destino);

    setState(() {
      _calculandoRuta = false;
      _resultadoRuta = resultado;
      _indiceRutaActiva = 0;
    });

    widget.onRutaCalculada(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila del título y botón cerrar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¿Mi ruta está libre?',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                ),
              ),
              IconButton(
                onPressed: () {
                  widget.onRutaCalculada(null);
                  widget.onCerrar();
                },
                icon: const Icon(Icons.close, color: Colors.grey),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Campo Origen
          TextField(
            controller: _origenController,
            onChanged: (val) => _onSearchChanged(val, true),
            decoration: InputDecoration(
              hintText: 'Buscar origen (ej. Tehuantepec)',
              prefixIcon: const Icon(Icons.circle, color: Colors.green, size: 12),
              suffixIcon: _origenController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _origenController.clear();
                        setState(() {
                          _origenSeleccionado = null;
                          _sugerencias = [];
                          _resultadoRuta = null;
                        });
                        widget.onRutaCalculada(null);
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),

          // Campo Destino
          TextField(
            controller: _destinoController,
            onChanged: (val) => _onSearchChanged(val, false),
            decoration: InputDecoration(
              hintText: 'Buscar destino (ej. Salina Cruz)',
              prefixIcon: const Icon(Icons.location_on, color: Colors.red, size: 14),
              suffixIcon: _destinoController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _destinoController.clear();
                        setState(() {
                          _destinoSeleccionado = null;
                          _sugerencias = [];
                          _resultadoRuta = null;
                        });
                        widget.onRutaCalculada(null);
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),

          // Lista de Sugerencias
          if (_sugerencias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sugerencias.length,
                itemBuilder: (context, index) {
                  final lugar = _sugerencias[index];
                  return ListTile(
                    title: Text(lugar.etiqueta, style: const TextStyle(fontSize: 13)),
                    dense: true,
                    onTap: () {
                      setState(() {
                        if (_esSugerenciaParaOrigen) {
                          _origenSeleccionado = lugar;
                          _origenController.text = lugar.etiqueta;
                        } else {
                          _destinoSeleccionado = lugar;
                          _destinoController.text = lugar.etiqueta;
                        }
                        _sugerencias = [];
                      });
                      
                      // Si ambos están seleccionados, calcular ruta
                      if (_origenSeleccionado != null && _destinoSeleccionado != null) {
                        _calcularRuta();
                      }
                    },
                  );
                },
              ),
            ),
          ],

          // Cargador
          if (_calculandoRuta) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFBF5B34)),
            ),
          ],

          // Resultados de Ruta
          if (_resultadoRuta != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Rutas disponibles:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white70 : const Color(0xFF78716C)),
            ),
            const SizedBox(height: 8),
            
            // Tarjeta Ruta Directa
            _buildRouteOptionCard(
              context: context,
              title: 'Ruta Directa',
              opt: _resultadoRuta!.directa,
              index: 0,
            ),
            
            // Tarjetas de Rutas Alternativas
            ...List.generate(_resultadoRuta!.alternativas.length, (idx) {
              final alt = _resultadoRuta!.alternativas[idx];
              return _buildRouteOptionCard(
                context: context,
                title: 'Ruta Alterna Sugerida ${idx + 1}',
                opt: alt,
                index: idx + 1,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildRouteOptionCard({
    required BuildContext context,
    required String title,
    required OpcionRuta opt,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = _indiceRutaActiva == index;
    final colorRuta = opt.libre ? (isDark ? const Color(0xFF4A8B71) : const Color(0xFF2F5D4C)) : const Color(0xFFBF5B34);
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _indiceRutaActiva = index;
        });
        widget.onRutaSeleccionada(index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? colorRuta.withOpacity(0.08) : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]),
          border: Border.all(
            color: active ? colorRuta : (isDark ? Colors.grey[800]! : Colors.grey[300]!),
            width: active ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: active ? colorRuta : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${opt.distanciaKm} km · ${opt.duracionMin} min',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            
            // Indicador libre/bloqueos
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: opt.libre ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    opt.libre ? Icons.check_circle : Icons.warning,
                    color: opt.libre ? Colors.green : Colors.red,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    opt.libre
                        ? 'Libre'
                        : '${opt.bloqueosEnRuta.length} bloqueo(s)',
                    style: TextStyle(
                      color: opt.libre ? Colors.green : Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
