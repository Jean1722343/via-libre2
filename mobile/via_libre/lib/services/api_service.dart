import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bloqueo.dart';

class ApiService {
  static const String baseUrl = 'https://3s0f6i00j3.execute-api.us-east-1.amazonaws.com/api';
  
  // Flag global para indicar estado sin conexión
  static bool isOffline = false;

  // Obtener lista de bloqueos por estado con caché local fallback
  Future<List<Bloqueo>> listarBloqueos(String estado) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reportes?estado=$estado'),
      ).timeout(const Duration(seconds: 4));
      
      if (response.statusCode == 200) {
        isOffline = false;
        // Guardar en caché local
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cache_bloqueos_$estado', response.body);
        
        final data = jsonDecode(response.body);
        final list = data['bloqueos'] as List<dynamic>? ?? [];
        return list.map((item) => Bloqueo.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      isOffline = true;
    }

    // Fallback a caché local si la llamada falla o hay excepción
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

  // Obtener resumen de conteo por estado con caché local fallback
  Future<Map<String, int>> resumen() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reportes/resumen'),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        isOffline = false;
        // Guardar en caché local
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

    // Fallback a caché local si la llamada falla o hay excepción
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'voto': voto}),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        isOffline = false;
        return Bloqueo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
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
      
      // 1. Obtener URL firmada
      final responseFirma = await http.post(
        Uri.parse('$baseUrl/fotos/firma'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tipo': mimeType}),
      ).timeout(const Duration(seconds: 5));
      
      if (responseFirma.statusCode != 200) return null;
      
      final dataFirma = jsonDecode(responseFirma.body);
      final String urlSubida = dataFirma['url_subida'] as String;
      final String urlPublica = dataFirma['url_publica'] as String;
      
      // 2. Subir directamente a S3
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
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201) {
        isOffline = false;
        return Bloqueo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
    } catch (e) {
      isOffline = true;
    }
    return null;
  }
}
