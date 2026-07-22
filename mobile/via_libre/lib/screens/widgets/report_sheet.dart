import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import 'auth_modal.dart';

class ReportSheet extends StatefulWidget {
  final LatLng posicion;
  final Function(Map<String, dynamic>) onEnviar;
  final VoidCallback onCancelar;

  const ReportSheet({
    super.key,
    required this.posicion,
    required this.onEnviar,
    required this.onCancelar,
  });

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final _formKey = GlobalKey<FormState>();
  
  String _tipoSeleccionado = 'manifestacion';
  String _estadoSeleccionado = 'activo';
  DateTime? _iniciaEn;
  
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _municipioController = TextEditingController();
  final TextEditingController _rutaAlternaController = TextEditingController();
  
  XFile? _fotoAdjunta;
  final ImagePicker _picker = ImagePicker();
  bool _subiendo = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    _municipioController.dispose();
    _rutaAlternaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto(ImageSource source) async {
    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo != null) {
        setState(() {
          _fotoAdjunta = photo;
        });
      }
    } catch (e) {
      // Ignorar
    }
  }

  Future<void> _seleccionarHoraInicio() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _iniciaEn = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _enviar() {
    if (ApiService.usuarioActual == null) {
      AuthModal.show(context, onLoginExitoso: () {
        setState(() {});
      });
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _subiendo = true;
    });

    final datos = {
      'tipo': _tipoSeleccionado,
      'estado': _estadoSeleccionado,
      'lat': widget.posicion.latitude,
      'lng': widget.posicion.longitude,
      'descripcion': _descripcionController.text.trim(),
      'municipio': _municipioController.text.trim(),
      'ruta_alterna_texto': _rutaAlternaController.text.trim(),
      'inicia_en': _iniciaEn?.toIso8601String(),
      'foto_archivo': _fotoAdjunta,
    };

    widget.onEnviar(datos);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final usuario = ApiService.usuarioActual;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090E17) : const Color(0xFFF6EFE1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reportar Bloqueo',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancelar,
                    icon: Icon(Icons.close, color: isDark ? Colors.white60 : Colors.grey[600]),
                  ),
                ],
              ),
              Divider(color: isDark ? Colors.grey[800] : const Color(0xFFE2D6C5)),
              const SizedBox(height: 8),

              // Banner Informativo de Autenticación / Rol
              if (usuario == null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBF5B34).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBF5B34).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline, color: Color(0xFFBF5B34), size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Inicia sesión para enviar tu reporte al mapa de Vía Libre.',
                          style: TextStyle(color: Color(0xFFBF5B34), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => AuthModal.show(context, onLoginExitoso: () => setState(() {})),
                        child: const Text('Ingresar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: usuario.rolColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: usuario.rolColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(usuario.rolIcono, color: usuario.rolColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          usuario.esNoticieroOAdmin
                              ? '⚡ Como ${usuario.rolEtiqueta}, tu reporte aparecerá VERIFICADO al instante.'
                              : 'ℹ️ Tu reporte requerirá 2 confirmaciones comunitarias para marcarse como Verificado.',
                          style: TextStyle(color: usuario.rolColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Coordenadas informativas
              Text(
                'Ubicación seleccionada: ${widget.posicion.latitude.toStringAsFixed(5)}, ${widget.posicion.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Campo de Selección de Tipo
              Text('Tipo de Bloqueo', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _tipoSeleccionado,
                dropdownColor: isDark ? const Color(0xFF131B26) : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'manifestacion', child: Text('🔊 Manifestación')),
                  DropdownMenuItem(value: 'obra', child: Text('🚧 Obra vial')),
                  DropdownMenuItem(value: 'accidente', child: Text('💥 Accidente')),
                  DropdownMenuItem(value: 'conflicto', child: Text('⚠️ Conflicto social')),
                  DropdownMenuItem(value: 'derrumbe', child: Text('🪨 Derrumbe')),
                  DropdownMenuItem(value: 'otro', child: Text('❓ Otro')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _tipoSeleccionado = val);
                },
              ),
              const SizedBox(height: 12),

              // Campo de Estado (Activo vs Programado)
              Text('Estado del Incidente', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('Activo Ahora', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      value: 'activo',
                      groupValue: _estadoSeleccionado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _estadoSeleccionado = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text('Programado', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                      value: 'programado',
                      groupValue: _estadoSeleccionado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _estadoSeleccionado = val);
                      },
                    ),
                  ),
                ],
              ),

              // Selector de Hora de Inicio (Solo si es programado)
              if (_estadoSeleccionado == 'programado') ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: _seleccionarHoraInicio,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _iniciaEn == null
                              ? 'Seleccionar fecha y hora de inicio'
                              : 'Inicia: ${DateFormat('dd/MM/yyyy HH:mm').format(_iniciaEn!)}',
                          style: TextStyle(
                            color: _iniciaEn == null ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        const Icon(Icons.calendar_today, size: 18),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Campo Municipio
              TextFormField(
                controller: _municipioController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Municipio / Ciudad (ej. Juchitán, Tehuantepec)',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa el municipio';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo Descripción
              TextFormField(
                controller: _descripcionController,
                maxLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Detalles adicionales (punto de referencia, motivo...)',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),

              // Campo Ruta Alterna Sugerida
              TextFormField(
                controller: _rutaAlternaController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Ruta alterna sugerida (opcional)',
                  labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 14),

              // Adjuntar Foto
              Text('Fotografía de evidencia (opcional)', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              if (_fotoAdjunta != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_fotoAdjunta!.path),
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => setState(() => _fotoAdjunta = null),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _seleccionarFoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Cámara'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _seleccionarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),

              // Botones Acción
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancelar,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _subiendo ? null : _enviar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F5D4C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _subiendo
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(usuario == null ? 'Ingresar y Publicar' : 'Publicar Reporte'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
