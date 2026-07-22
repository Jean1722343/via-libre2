import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/bloqueo.dart';
import '../../../services/api_service.dart';

class FeedPanel extends StatelessWidget {
  final List<Bloqueo> bloqueos;
  final String estadoFiltro; // 'activo' | 'programado' | 'finalizado'
  final Function(String) onFiltroChanged;
  final Function(Bloqueo) onCardTap;
  final Function(String, String) onConfirmar; // id, voto
  final Function(String)? onVerificar;
  final Function(String)? onFinalizar;
  final Function(String)? onEliminar;
  final bool cargando;

  const FeedPanel({
    super.key,
    required this.bloqueos,
    required this.estadoFiltro,
    required this.onFiltroChanged,
    required this.onCardTap,
    required this.onConfirmar,
    this.onVerificar,
    this.onFinalizar,
    this.onEliminar,
    required this.cargando,
  });

  String _formatTiempoRelativo(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final difference = DateTime.now().difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Hace unos segundos';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} h';
      } else {
        return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
      }
    } catch (e) {
      return '';
    }
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

  String _getEtiquetaForTipo(String tipo) {
    switch (tipo) {
      case 'manifestacion':
        return 'Manifestación';
      case 'obra':
        return 'Obra vial';
      case 'accidente':
        return 'Accidente';
      case 'conflicto':
        return 'Conflicto social';
      case 'derrumbe':
        return 'Derrumbe';
      default:
        return 'Otro incidente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF090E17).withOpacity(0.85) 
                : const Color(0xFFF6EFE1).withOpacity(0.88),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(
              color: isDark 
                  ? Colors.white.withOpacity(0.10) 
                  : const Color(0xFFBF5B34).withOpacity(0.18),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            children: [
              // Manija de Bottom Sheet
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 5),
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // Selector de Pestañas/Estados
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildTabButton(context, 'Activos', 'activo'),
                    const SizedBox(width: 8),
                    _buildTabButton(context, 'Programados', 'programado'),
                    const SizedBox(width: 8),
                    _buildTabButton(context, 'Finalizados', 'finalizado'),
                  ],
                ),
              ),

              // Lista de Bloqueos
              Expanded(
                child: cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFBF5B34),
                        ),
                      )
                    : bloqueos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_off,
                                  size: 48,
                                  color: isDark ? Colors.grey[700] : Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No hay reportes en este estado',
                                  style: TextStyle(
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                            itemCount: bloqueos.length,
                            itemBuilder: (context, index) {
                              final b = bloqueos[index];
                              return _buildReporteCard(context, b);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final active = estadoFiltro == value;
    
    return Expanded(
      child: InkWell(
        onTap: () => onFiltroChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFBF5B34) : (isDark ? const Color(0xFF131B26).withOpacity(0.5) : Colors.white.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: active ? const Color(0xFFBF5B34) : (isDark ? Colors.grey[800]! : const Color(0xFFE2D6C5)),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF78716C)),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReporteCard(BuildContext context, Bloqueo b) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tipoColor = _getColorForTipo(b.tipo);
    final tiempo = _formatTiempoRelativo(b.creadoEn);
    final usuario = ApiService.usuarioActual;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark 
            ? const Color(0xFF131B26).withOpacity(0.75) 
            : Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.06) 
              : const Color(0xFFBF5B34).withOpacity(0.12),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onCardTap(b),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fila Superior: Tipo, Badge de Verificación y Tiempo
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tipoColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          _getEtiquetaForTipo(b.tipo),
                          style: TextStyle(
                            color: tipoColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (b.verificado == true) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A8B71).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFF4A8B71).withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, size: 12, color: Color(0xFF4A8B71)),
                              SizedBox(width: 3),
                              Text(
                                'Verificado',
                                style: TextStyle(
                                  color: Color(0xFF4A8B71),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_top, size: 12, color: Color(0xFFF59E0B)),
                              SizedBox(width: 3),
                              Text(
                                'Por verificar',
                                style: TextStyle(
                                  color: Color(0xFFB45309),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        tiempo,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.grey,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),

                  // Fila Central: Municipio y Descripción
                  const SizedBox(height: 12),
                  if (b.municipio.isNotEmpty)
                    Text(
                      b.municipio,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                      ),
                    ),
                  if (b.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      b.descripcion,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xFF78716C),
                      ),
                    ),
                  ],

                  // Detalle de Autor si existe
                  if (b.autorNombre != null && b.autorNombre!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          b.autorRol == 'admin' ? Icons.shield : (b.autorRol == 'noticiero' ? Icons.newspaper : Icons.person_outline),
                          size: 13,
                          color: b.autorRol == 'admin' ? const Color(0xFF8B5CF6) : Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Reportado por: ${b.autorNombre}',
                          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],

                  // Detalle de Programado si aplica
                  if (b.estado == 'programado' && b.iniciaEn != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer, size: 14, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Inicia programado a las: ${DateFormat('dd/MM HH:mm').format(DateTime.parse(b.iniciaEn!).toLocal())}',
                              style: const TextStyle(
                                color: Color(0xFFB45309),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Ruta Alterna Sugerida
                  if (b.rutaAlternaTexto != null && b.rutaAlternaTexto!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.alt_route, size: 14, color: Color(0xFF4A8B71)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Alternativa: ${b.rutaAlternaTexto}',
                            style: const TextStyle(
                              color: Color(0xFF4A8B71),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Imagen si hay fotoUrl
                  if (b.fotoUrl != null && b.fotoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        b.fotoUrl!,
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 140,
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported, color: Colors.grey),
                        ),
                      ),
                    ),
                  ],

                  // Fila Inferior: Votos y Acciones de Confirmación / Moderación
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? Colors.grey[800] : const Color(0xFFE2D6C5)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      // Votos actuales
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF4A8B71)),
                          const SizedBox(width: 4),
                          Text(
                            'Sigue: ${b.confirmacionesSigue}',
                            style: const TextStyle(color: Color(0xFF4A8B71), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.remove_road_outlined, size: 16, color: Color(0xFFBF5B34)),
                          const SizedBox(width: 4),
                          Text(
                            'Liberado: ${b.confirmacionesLiberado}',
                            style: const TextStyle(color: Color(0xFFBF5B34), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Acciones para moderador / admin
                      if (usuario != null && usuario.esNoticieroOAdmin && b.verificado != true && onVerificar != null) ...[
                        InkWell(
                          onTap: () => onVerificar!(b.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF3B82F6)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_outlined, size: 12, color: Color(0xFF3B82F6)),
                                SizedBox(width: 2),
                                Text('Verificar', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],

                      if (usuario != null && usuario.esAdmin && onEliminar != null) ...[
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
                          onPressed: () => onEliminar!(b.id),
                          tooltip: 'Eliminar Reporte',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Botones de votar si no es finalizado
                      if (b.estado != 'finalizado') ...[
                        OutlinedButton(
                          onPressed: () => onConfirmar(b.id, 'liberado'),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFBF5B34)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text(
                            '¡Se liberó!',
                            style: TextStyle(color: Color(0xFFBF5B34), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: () => onConfirmar(b.id, 'sigue'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F5D4C),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text(
                            'Sigue ahí',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
