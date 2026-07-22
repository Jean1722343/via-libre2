import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'widgets/auth_modal.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onSessionChanged;

  const ProfileScreen({
    super.key,
    required this.onSessionChanged,
  });

  static void show(BuildContext context, {required VoidCallback onSessionChanged}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileScreen(onSessionChanged: onSessionChanged),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _cargando = false;

  void _cerrarSesion() async {
    setState(() => _cargando = true);
    await ApiService.logout();
    if (!mounted) return;
    setState(() => _cargando = false);
    widget.onSessionChanged();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Has cerrado sesión correctamente.'),
          ],
        ),
        backgroundColor: const Color(0xFFBF5B34),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final usuario = ApiService.usuarioActual;

    if (usuario == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF090E17).withOpacity(0.92) : Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_circle_outlined, size: 64, color: Color(0xFFBF5B34)),
                const SizedBox(height: 16),
                Text(
                  'No has iniciado sesión',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión para que tus reportes aparezcan vinculados a tu perfil y moderar el mapa.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    AuthModal.show(context, onLoginExitoso: widget.onSessionChanged);
                  },
                  icon: const Icon(Icons.login),
                  label: const Text('Iniciar Sesión / Registrarse', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F5D4C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final rolColor = usuario.rolColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090E17) : const Color(0xFFF6EFE1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Cabecera con Degradado Obsidian & Neón
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rolColor.withOpacity(0.35),
                      isDark ? const Color(0xFF090E17) : const Color(0xFF2F5D4C),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    // Manija
                    Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white38,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Avatar con Anillo Neón Glowing
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: rolColor, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: rolColor.withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: isDark ? const Color(0xFF131B26) : Colors.white,
                        backgroundImage: usuario.foto != null && usuario.foto!.isNotEmpty
                            ? NetworkImage(usuario.foto!)
                            : null,
                        child: usuario.foto == null || usuario.foto!.isEmpty
                            ? Icon(Icons.person, size: 48, color: rolColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nombre del Usuario
                    Text(
                      usuario.nombre,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    // Email del Usuario
                    Text(
                      usuario.email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Badge Distintivo de Rol
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: rolColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: rolColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(usuario.rolIcono, size: 16, color: rolColor),
                          const SizedBox(width: 6),
                          Text(
                            usuario.rolEtiqueta.toUpperCase(),
                            style: TextStyle(
                              color: rolColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Cuerpo con Estadísticas y Datos
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila de Estadísticas en Tarjetas Glassmorphic
                    Row(
                      children: [
                        _buildStatCard(
                          context,
                          titulo: 'Verificación',
                          valor: usuario.esNoticieroOAdmin ? 'Instantánea' : 'Comunidad',
                          icono: Icons.verified_outlined,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          context,
                          titulo: 'Rol AWS',
                          valor: usuario.rol.toUpperCase(),
                          icono: Icons.shield_outlined,
                          color: rolColor,
                        ),
                        const SizedBox(width: 12),
                        _buildStatCard(
                          context,
                          titulo: 'Estado',
                          valor: 'JWT Activo',
                          icono: Icons.cloud_done_outlined,
                          color: const Color(0xFF3B82F6),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Detalles de la Cuenta
                    Text(
                      'Información de la Cuenta',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildInfoTile(
                      context,
                      label: 'ID de Usuario',
                      val: usuario.id.isNotEmpty ? usuario.id : 'Generado por AWS DynamoDB',
                      icon: Icons.key_outlined,
                    ),
                    _buildInfoTile(
                      context,
                      label: 'Proveedor de Autenticación',
                      val: usuario.proveedor ?? 'Local (Laravel JWT)',
                      icon: Icons.security_outlined,
                    ),
                    _buildInfoTile(
                      context,
                      label: 'Permiso de Publicación',
                      val: usuario.esNoticieroOAdmin 
                          ? 'Publicación directa sin filtro previo' 
                          : 'Requiere 2 confirmaciones "Sigue ahí"',
                      icon: Icons.rule_outlined,
                    ),
                    const SizedBox(height: 24),

                    // Botón para Administradores si aplica
                    if (usuario.esAdmin) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.admin_panel_settings, color: Color(0xFF8B5CF6), size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Panel de Administrador Activo',
                                    style: TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Tienes permisos para verificar, finalizar y moderar cualquier reporte en el mapa.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Botón de Cerrar Sesión
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _cargando ? null : _cerrarSesion,
                        icon: const Icon(Icons.logout, color: Colors.white),
                        label: const Text('Cerrar Sesión', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {required String titulo, required String valor, required IconData icono, required Color color}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B26) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              valor,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context, {required String label, required String val, required IconData icon}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B26).withOpacity(0.6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFBF5B34)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.grey[600]),
                ),
                Text(
                  val,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
