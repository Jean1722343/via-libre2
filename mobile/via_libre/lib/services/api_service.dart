import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bloqueo.dart';
import '../models/usuario.dart';

class ApiService {
  static const String baseUrl = 'https://3s0f6i00j3.execute-api.us-east-1.amazonaws.com/api';
  
  // Flag global para indicar estado sin conexión
  static bool isOffline = false;

  // Estado de Autenticación Global
  static String? token;
  static Usuario? usuarioActual;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // Rehidratar sesión guardada al abrir la aplicación
  static Future<bool> rehidratarSesion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
      final userJson = prefs.getString('auth_usuario');
      
      if (userJson != null) {
        usuarioActual = Usuario.fromJson(jsonDecode(userJson));
      }

      if (token != null && token!.isNotEmpty) {
        // Validar token fresco con el backend
        final yo = await ApiService().obtenerYo();
        if (yo != null) {
          usuarioActual = yo;
          return true;
        }
      }
    } catch (_) {}
    return usuarioActual != null;
  }

  // Guardar datos de sesión localmente
  static Future<void> _guardarSesion(String tokenString, Usuario usuarioObj) async {
    token = tokenString;
    usuarioActual = usuarioObj;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', tokenString);
    await prefs.setString('auth_usuario', jsonEncode(usuarioObj.toJson()));
  }

  // Iniciar Sesión (Login)
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['token'] != null) {
        isOffline = false;
        final usuario = Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
        await _guardarSesion(data['token'] as String, usuario);
        return {'exito': true, 'usuario': usuario};
      } else {
        return {'exito': false, 'mensaje': data['mensaje'] ?? 'Credenciales incorrectas'};
      }
    } catch (e) {
      isOffline = true;
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor'};
    }
  }

  // Registro de nuevo usuario
  Future<Map<String, dynamic>> registro(String nombre, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/registro'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nombre': nombre, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 6));

      final data = jsonDecode(response.body);
      if ((response.statusCode == 200 || response.statusCode == 201) && data['token'] != null) {
        isOffline = false;
        final usuario = Usuario.fromJson(data['usuario'] as Map<String, dynamic>);
        await _guardarSesion(data['token'] as String, usuario);
        return {'exito': true, 'usuario': usuario};
      } else {
        return {'exito': false, 'mensaje': data['mensaje'] ?? 'No se pudo crear la cuenta'};
      }
    } catch (e) {
      isOffline = true;
      return {'exito': false, 'mensaje': 'Error de conexión con el servidor'};
    }
  }

  // Obtener perfil actual (/auth/yo)
  Future<Usuario?> obtenerYo() async {
    if (token == null || token!.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/yo'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        isOffline = false;
        final data = jsonDecode(response.body);
        final userObj = data['usuario'] ?? data;
        final usuario = Usuario.fromJson(userObj as Map<String, dynamic>);
        usuarioActual = usuario;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_usuario', jsonEncode(usuario.toJson()));
        return usuario;
      }
    } catch (e) {
      isOffline = true;
    }
    return usuarioActual;
  }

  // Cerrar sesión
  static Future<void> logout() async {
    token = null;
    usuarioActual = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_usuario');
  }

  // Obtener lista de bloqueos por estado con caché local fallback
  Future<List<Bloqueo>> listarBloqueos(String estado) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reportes?estado=$estado'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        isOffline = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_bloqueos_$estado', response.body);
        
        final data = jsonDecode(response.body);
        final list = data['bloqueos'] as List<dynamic>? ?? [];
        return list.map((item) => Bloqueo.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      isOffline = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_bloqueos_$estado');
      if (cached != null) {
        final data = jsonDecode(cached);
        final list = data['bloqueos'] as List<dynamic>? ?? [];
        return list.map((item) => Bloqueo.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return [];
  }

  // Obtener resumen de conteo por estado
  Future<Map<String, int>> resumen() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reportes/resumen'),
        headers: _headers,
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        isOffline = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_resumen', response.body);

        final Map<String, dynamic> data = jsonDecode(response.body);
        return {
          'activos': data['activos'] as int? ?? 0,
          'programados': data['programados'] as int? ?? 0,
          'finalizados': data['finalizados'] as int? ?? 0,
        };
      }
    } catch (e) {
      isOffline = true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cache_resumen');
      if (cached != null) {
        final Map<String, dynamic> data = jsonDecode(cached);
        return {
          'activos': data['activos'] as int? ?? 0,
          'programados': data['programados'] as int? ?? 0,
          'finalizados': data['finalizados'] as int? ?? 0,
        };
      }
    } catch (_) {}

    return {'activos': 0, 'programados': 0, 'finalizados': 0};
  }

  // Confirmar un reporte (sigue / liberado)
  Future<Bloqueo?> confirmar(String id, String voto) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reportes/$id/confirmar'),
        headers: _headers,
        body: jsonEncode({'voto': voto}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        isOffline = false;
        final data = jsonDecode(response.body);
        final bloqueoObj = data['bloqueo'] ?? data;
        return Bloqueo.fromJson(bloqueoObj as Map<String, dynamic>);
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
  }

  // --- MÉTODOS DE MODERACIÓN PARA NOTICIERO Y ADMIN ---

  // Verificar un reporte (Noticiero / Admin)
  Future<bool> verificarReporte(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reportes/$id/verificar'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Finalizar un reporte (Admin)
  Future<bool> finalizarReporte(String id) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reportes/$id/finalizar'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Eliminar un reporte (Admin)
  Future<bool> eliminarReporte(String id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/reportes/$id'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // Listar usuarios (Admin)
  Future<List<Usuario>> listarUsuarios() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/usuarios'),
        headers: _headers,
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['usuarios'] as List<dynamic>? ?? [];
        return list.map((u) => Usuario.fromJson(u as Map<String, dynamic>)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Cambiar rol de usuario (Admin)
  Future<bool> cambiarRolUsuario(String id, String nuevoRol) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/usuarios/$id/rol'),
        headers: _headers,
        body: jsonEncode({'rol': nuevoRol}),
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // Geocodificar texto a coordenadas
  Future<List<Lugar>> geocodificar(String texto) async {
    if (texto.trim().length < 3) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/geocode?texto=${Uri.encodeComponent(texto)}'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        isOffline = false;
        final data = jsonDecode(response.body);
        final list = data['resultados'] as List<dynamic>? ?? [];
        return list.map((item) => Lugar.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      isOffline = true;
    }
    return [];
  }

  // Buscar ruta y alternativas
  Future<ResultadoRuta?> buscarRuta(Coordenada origen, Coordenada destino) async {
    try {
      final url = '$baseUrl/rutas?origenLat=${origen.lat}&origenLng=${origen.lng}&destinoLat=${destino.lat}&destinoLng=${destino.lng}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        isOffline = false;
        return ResultadoRuta.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
  }

  // Subir foto a S3 usando URL firmada del backend
  Future<String?> subirFoto(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = file.mimeType ?? 'image/jpeg';
      
      final responseFirma = await http.post(
        Uri.parse('$baseUrl/fotos/firma'),
        headers: _headers,
        body: jsonEncode({'tipo': mimeType}),
      ).timeout(const Duration(seconds: 5));
      
      if (responseFirma.statusCode != 200) return null;
      
      final dataFirma = jsonDecode(responseFirma.body);
      final String urlSubida = dataFirma['url_subida'] as String;
      final String urlPublica = dataFirma['url_publica'] as String;
      
      final responseSubida = await http.put(
        Uri.parse(urlSubida),
        headers: {'Content-Type': mimeType},
        body: bytes,
      ).timeout(const Duration(seconds: 8));
      
      if (responseSubida.statusCode == 200) {
        isOffline = false;
        return urlPublica;
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
  }

  // Crear un nuevo reporte de bloqueo
  Future<Bloqueo?> crearBloqueo({
    required String tipo,
    required double lat,
    required double lng,
    String? descripcion,
    String? municipio,
    String? fotoUrl,
    String? estado,
    String? iniciaEn,
    String? rutaAlternaTexto,
  }) async {
    try {
      final body = {
        'tipo': tipo,
        'lat': lat,
        'lng': lng,
        if (descripcion != null) 'descripcion': descripcion,
        if (municipio != null) 'municipio': municipio,
        if (fotoUrl != null) 'foto_url': fotoUrl,
        if (estado != null) 'estado': estado,
        if (iniciaEn != null) 'inicia_en': iniciaEn,
        if (rutaAlternaTexto != null) 'ruta_alterna_texto': rutaAlternaTexto,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/reportes'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        isOffline = false;
        final data = jsonDecode(response.body);
        final bloqueoObj = data['bloqueo'] ?? data;
        return Bloqueo.fromJson(bloqueoObj as Map<String, dynamic>);
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
  }
}
