import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

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
      // Ignorar o registrar
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
      'foto': _fotoAdjunta,
    };

    widget.onEnviar(datos);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
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
                  const Text(
                    'Reportar Bloqueo',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F5D4C),
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onCancelar,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Coordenadas informativas
              Text(
                'Ubicación seleccionada: ${widget.posicion.latitude.toStringAsFixed(5)}, ${widget.posicion.longitude.toStringAsFixed(5)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 12),

              // Campo de Selección de Tipo
              const Text('Tipo de Bloqueo', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _tipoSeleccionado,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'manifestacion', child: Text('🔊 Manifestación')),
                  DropdownMenuItem(value: 'obra', child: Text('🚧 Obra vial')),
                  DropdownMenuItem(value: 'accidente', child: Text('💥 Accidente')),
                  DropdownMenuItem(value: 'conflicto', child: Text('🔥 Conflicto social')),
                  DropdownMenuItem(value: 'derrumbe', child: Text('🪨 Derrumbe')),
                  DropdownMenuItem(value: 'otro', child: Text('⚠️ Otro')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _tipoSeleccionado = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Estado: Activo / Programado
              const Text('Vigencia del Reporte', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Activo ahora', style: TextStyle(fontSize: 13)),
                      value: 'activo',
                      groupValue: _estadoSeleccionado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _estadoSeleccionado = val!;
                          _iniciaEn = null;
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Programado', style: TextStyle(fontSize: 13)),
                      value: 'programado',
                      groupValue: _estadoSeleccionado,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setState(() {
                          _estadoSeleccionado = val!;
                        });
                      },
                    ),
                  ),
                ],
              ),

              // Selector de Hora de Inicio (Solo si es Programado)
              if (_estadoSeleccionado == 'programado') ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: _seleccionarHoraInicio,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[400]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFFBF5B34)),
                        const SizedBox(width: 8),
                        Text(
                          _iniciaEn == null
                              ? 'Seleccionar fecha y hora de inicio'
                              : 'Inicia el: ${DateFormat('dd/MM/yyyy HH:mm').format(_iniciaEn!)}',
                          style: TextStyle(
                            color: _iniciaEn == null ? Colors.grey[600] : Colors.black,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Municipio
              const Text('Municipio', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _municipioController,
                validator: (val) => val == null || val.isEmpty ? 'Especifica el municipio' : null,
                decoration: InputDecoration(
                  hintText: 'Ej. Santo Domingo Tehuantepec',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Descripción
              const Text('Detalles / Qué está pasando', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descripcionController,
                maxLines: 2,
                maxLength: 280,
                decoration: InputDecoration(
                  hintText: 'Ej. Pobladores bloquean la entrada al puente caracol',
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),

              // Ruta Alterna Sugerida
              const Text('Ruta Alterna Sugerida (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _rutaAlternaController,
                decoration: InputDecoration(
                  hintText: 'Ej. Desvío por el libramiento de peaje',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),

              // Foto adjunta
              const Text('Foto del incidente (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_fotoAdjunta != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_fotoAdjunta!.path),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _fotoAdjunta = null;
                          });
                        },
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, color: Colors.white, size: 18),
                        ),
                      ),
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
                        label: const Text('Tomar Foto'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBF5B34)),
                          foregroundColor: const Color(0xFFBF5B34),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _seleccionarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2F5D4C)),
                          foregroundColor: const Color(0xFF2F5D4C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // Acciones
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _subiendo ? null : widget.onCancelar,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _subiendo
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Enviar Reporte'),
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
