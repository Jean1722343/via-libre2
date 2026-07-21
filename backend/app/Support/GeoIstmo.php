<?php

namespace App\Support;

// Utilidades geográficas para el Istmo de Tehuantepec.
class GeoIstmo
{
    public static function dentroDelIstmo(float $lat, float $lng): bool
    {
        $b = config('vialibre.istmo_bbox');
        return $lat >= $b['minLat'] && $lat <= $b['maxLat']
            && $lng >= $b['minLng'] && $lng <= $b['maxLng'];
    }

    // Distancia mínima (en metros) de un punto a una polilínea (array de [lat,lng]).
    public static function distanciaAPolilinea(array $punto, array $linea): float
    {
        $min = INF;
        for ($i = 0; $i < count($linea) - 1; $i++) {
            $d = self::distanciaPuntoSegmento($punto, $linea[$i], $linea[$i + 1]);
            if ($d < $min) {
                $min = $d;
            }
        }
        return $min;
    }

    /**
     * Punto de paso para rodear un bloqueo: toma la dirección de la ruta cerca
     * del bloqueo y devuelve un punto desplazado perpendicularmente $metros
     * (el signo elige el lado). Sirve como waypoint para pedir una ruta alterna.
     *
     * @param array $punto ['lat'=>, 'lng'=>]  el bloqueo
     * @param array $linea polilínea [['lat'=>,'lng'=>], ...]
     */
    public static function desvioPerpendicular(array $punto, array $linea, float $metros): array
    {
        // Segmento de la ruta más cercano al bloqueo, para conocer su rumbo.
        $mejor = INF;
        $dir = ['x' => 1.0, 'y' => 0.0];
        for ($i = 0; $i < count($linea) - 1; $i++) {
            $d = self::distanciaPuntoSegmento($punto, $linea[$i], $linea[$i + 1]);
            if ($d < $mejor) {
                $mejor = $d;
                $dir = ['x' => $linea[$i + 1]['lng'] - $linea[$i]['lng'],
                        'y' => $linea[$i + 1]['lat'] - $linea[$i]['lat']];
            }
        }

        $mLat = 111320.0;
        $mLng = 111320.0 * cos(deg2rad($punto['lat']));

        // Rumbo en metros y su perpendicular unitaria.
        $vx = $dir['x'] * $mLng;
        $vy = $dir['y'] * $mLat;
        $largo = sqrt($vx * $vx + $vy * $vy) ?: 1.0;
        $px = -$vy / $largo; // perpendicular
        $py = $vx / $largo;

        // Desplazamiento en metros -> grados.
        $dLng = ($px * $metros) / $mLng;
        $dLat = ($py * $metros) / $mLat;

        return ['lat' => $punto['lat'] + $dLat, 'lng' => $punto['lng'] + $dLng];
    }

    // Proyección plana local (suficiente a la escala del Istmo). Metros.
    private static function distanciaPuntoSegmento(array $p, array $a, array $b): float
    {
        $mLat = 111320.0;
        $mLng = 111320.0 * cos(deg2rad($p['lat']));

        $px = $p['lng'] * $mLng; $py = $p['lat'] * $mLat;
        $ax = $a['lng'] * $mLng; $ay = $a['lat'] * $mLat;
        $bx = $b['lng'] * $mLng; $by = $b['lat'] * $mLat;

        $dx = $bx - $ax; $dy = $by - $ay;
        $largo2 = $dx * $dx + $dy * $dy;
        $t = $largo2 == 0.0 ? 0.0 : (($px - $ax) * $dx + ($py - $ay) * $dy) / $largo2;
        $t = max(0.0, min(1.0, $t));

        $cx = $ax + $t * $dx; $cy = $ay + $t * $dy;
        return sqrt(($px - $cx) ** 2 + ($py - $cy) ** 2);
    }
}
