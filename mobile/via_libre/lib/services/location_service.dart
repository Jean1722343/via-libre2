import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationService {
  // Centro por defecto en el Istmo de Tehuantepec (Juchitán de Zaragoza, Oaxaca)
  static const LatLng centroIstmoDefault = LatLng(16.4349, -95.0197);

  // Obtener posición actual del usuario
  Future<LatLng> obtenerPosicionActual() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Verificar si los servicios de ubicación están habilitados
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return centroIstmoDefault;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return centroIstmoDefault;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return centroIstmoDefault;
      }

      // Obtener posición
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      return centroIstmoDefault;
    }
  }

  // Escuchar cambios de ubicación (para alertas en tiempo real)
  Stream<Position> obtenerStreamUbicacion() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    );
  }
}
