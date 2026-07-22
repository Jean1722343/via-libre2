import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AuthModal extends StatefulWidget {
  final VoidCallback onLoginExitoso;

  const AuthModal({
    super.key,
    required this.onLoginExitoso,
  });

  static Future<void> show(BuildContext context, {required VoidCallback onLoginExitoso}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AuthModal(onLoginExitoso: onLoginExitoso),
      ),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  bool _esLogin = true;
  bool _cargando = false;
  String? _errorMsg;

  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _usarCuentaDemoAdmin() {
    setState(() {
      _esLogin = true;
      _emailCtrl.text = 'admin@vialibre.mx';
      _passCtrl.text = 'ViaLibre.Admin2026';
      _errorMsg = null;
    });
  }

  Future<void> _procesarAuth() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final nombre = _nombreCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty || (!_esLogin && nombre.isEmpty)) {
      setState(() => _errorMsg = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _cargando = true;
      _errorMsg = null;
    });

    final api = ApiService();
    final Map<String, dynamic> res;

    if (_esLogin) {
      res = await api.login(email, pass);
    } else {
      res = await api.registro(nombre, email, pass);
    }

    if (!mounted) return;

    setState(() => _cargando = false);

    if (res['exito'] == true) {
      Navigator.pop(context);
      widget.onLoginExitoso();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _esLogin ? '¡Bienvenido de nuevo, ${ApiService.usuarioActual?.nombre}!' : '¡Cuenta creada con éxito!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2F5D4C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      setState(() => _errorMsg = res['mensaje'] ?? 'Ocurrió un error inesperado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark 
                ? const Color(0xFF090E17).withOpacity(0.92) 
                : const Color(0xFFF6EFE1).withOpacity(0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFBF5B34).withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Encabezado
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBF5B34).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_outline,
                        color: Color(0xFFBF5B34),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _esLogin ? 'Iniciar Sesión' : 'Crear Cuenta',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF2F5D4C),
                          ),
                        ),
                        Text(
                          'Vía Libre Oaxaca',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Selector de pestañas
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF131B26) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _esLogin = true;
                            _errorMsg = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _esLogin ? const Color(0xFFBF5B34) : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Text(
                              'Ingresar',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _esLogin ? Colors.white : (isDark ? Colors.white60 : Colors.grey[700]),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _esLogin = false;
                            _errorMsg = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_esLogin ? const Color(0xFFBF5B34) : Colors.transparent,
                              borderRadius: BorderRadius.circular(26),
                            ),
                            child: Text(
                              'Registrarse',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_esLogin ? Colors.white : (isDark ? Colors.white60 : Colors.grey[700]),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Mensaje de Error si hay
                if (_errorMsg != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMsg!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Campo Nombre (Solo si no es login)
                if (!_esLogin) ...[
                  TextField(
                    controller: _nombreCtrl,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Nombre Completo',
                      labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                      prefixIcon: Icon(Icons.person_outline, color: isDark ? Colors.white60 : Colors.grey[600]),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF131B26) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Campo Email
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                    prefixIcon: Icon(Icons.email_outlined, color: isDark ? Colors.white60 : Colors.grey[600]),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131B26) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),

                // Campo Password
                TextField(
                  controller: _passCtrl,
                  obscureText: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    labelStyle: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                    prefixIcon: Icon(Icons.lock_outline, color: isDark ? Colors.white60 : Colors.grey[600]),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF131B26) : Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 20),

                // Botón Acción Principal
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _procesarAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F5D4C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                    child: _cargando
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _esLogin ? 'Entrar a Vía Libre' : 'Crear mi Cuenta',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 14),

                // Botón Demo Admin
                OutlinedButton.icon(
                  onPressed: _usarCuentaDemoAdmin,
                  icon: const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF8B5CF6)),
                  label: const Text(
                    '🔑 Llenar con Cuenta Admin Demo',
                    style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF8B5CF6)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
