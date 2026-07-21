<?php

namespace App\Http\Controllers;

use App\Support\DynamoBloqueos;
use App\Support\GeoIstmo;
use Aws\LocationService\LocationServiceClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class RutaController extends Controller
{
    private const UMBRAL_METROS = 300;

    public function __construct(private DynamoBloqueos $repo)
    {
    }

    // GET /api/geocode?texto=...
    public function geocodificar(Request $request): JsonResponse
    {
        $texto = trim((string) $request->query('texto', ''));
        if (mb_strlen($texto) < 3) {
            return response()->json(['error' => 'Envía ?texto= con al menos 3 caracteres.'], 422);
        }

        $r = $this->location()->searchPlaceIndexForText([
            'IndexName' => config('vialibre.location.indice_lugares'),
            'Text' => $texto,
            'MaxResults' => 5,
            'FilterCountries' => ['MEX'],
            'BiasPosition' => [-95.2, 16.5],
        ]);

        $resultados = array_map(fn ($x) => [
            'etiqueta' => $x['Place']['Label'] ?? null,
            'lng' => $x['Place']['Geometry']['Point'][0] ?? null,
            'lat' => $x['Place']['Geometry']['Point'][1] ?? null,
        ], $r['Results'] ?? []);

        return response()->json(['resultados' => $resultados]);
    }

    // GET /api/rutas?origenLat&origenLng&destinoLat&destinoLng
    // Devuelve la ruta directa y, si cruza bloqueos, hasta 2 alternas que los
    // rodean (estilo Waze: el frontend las muestra como opciones seleccionables).
    public function buscar(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'origenLat' => 'required|numeric',
            'origenLng' => 'required|numeric',
            'destinoLat' => 'required|numeric',
            'destinoLng' => 'required|numeric',
        ]);

        $origen  = [(float) $datos['origenLng'], (float) $datos['origenLat']];
        $destino = [(float) $datos['destinoLng'], (float) $datos['destinoLat']];

        $ruta = $this->calcularRuta($origen, $destino);
        $activos = $this->repo->listarActivos();
        $enRuta = $this->bloqueosSobre($ruta['linea'], $activos);

        $directa = [
            'libre' => count($enRuta) === 0,
            'resumen' => $ruta['resumen'],
            'geometria' => $ruta['linea'],
            'bloqueos_en_ruta' => $enRuta,
        ];

        // Si la directa tiene bloqueos, buscamos alternas que los rodeen.
        $alternativas = $enRuta === []
            ? []
            : $this->alternativas($origen, $destino, $ruta['linea'], $enRuta, $activos);

        return response()->json([
            'origen' => ['lat' => $origen[1], 'lng' => $origen[0]],
            'destino' => ['lat' => $destino[1], 'lng' => $destino[0]],
            'directa' => $directa,
            'alternativas' => $alternativas,
        ]);
    }

    /** Llama a Amazon Location y devuelve la polilínea [lng,lat] + resumen. */
    private function calcularRuta(array $origen, array $destino, array $waypoints = []): array
    {
        $params = [
            'CalculatorName' => config('vialibre.location.calculadora'),
            'DeparturePosition' => $origen,
            'DestinationPosition' => $destino,
            'TravelMode' => 'Car',
            'IncludeLegGeometry' => true,
        ];
        if ($waypoints !== []) {
            $params['WaypointPositions'] = $waypoints;
        }

        $ruta = $this->location()->calculateRoute($params);

        $linea = [];
        foreach ($ruta['Legs'] ?? [] as $leg) {
            foreach ($leg['Geometry']['LineString'] ?? [] as $p) {
                $linea[] = ['lng' => $p[0], 'lat' => $p[1]];
            }
        }

        return [
            'linea' => $linea,
            'resumen' => [
                'distancia_km' => round($ruta['Summary']['Distance'] ?? 0, 1),
                'duracion_min' => (int) round(($ruta['Summary']['DurationSeconds'] ?? 0) / 60),
            ],
        ];
    }

    /** Bloqueos activos a <= UMBRAL_METROS de la polilínea, más cercanos primero. */
    private function bloqueosSobre(array $linea, array $activos): array
    {
        $enRuta = [];
        foreach ($activos as $b) {
            $dist = GeoIstmo::distanciaAPolilinea(['lat' => $b['lat'], 'lng' => $b['lng']], $linea);
            if ($dist <= self::UMBRAL_METROS) {
                $b['distancia_a_ruta'] = (int) round($dist);
                $enRuta[] = $b;
            }
        }
        usort($enRuta, fn ($a, $b) => $a['distancia_a_ruta'] <=> $b['distancia_a_ruta']);
        return $enRuta;
    }

    /**
     * Calcula rutas que rodean los bloqueos añadiendo un punto de paso desplazado
     * perpendicularmente cerca del bloqueo más cercano. Prueba varias distancias a
     * ambos lados, descarta las que no mejoran, deduplica y devuelve hasta 2
     * (rankeadas por menos bloqueos y, a igualdad, menor duración).
     *
     * @return array<int, array> alternativas [{libre, resumen, geometria, bloqueos_en_ruta}]
     */
    private function alternativas(array $origen, array $destino, array $linea, array $enRuta, array $activos): array
    {
        $baseBloqueos = count($enRuta);
        $candidatas = [];
        $vistas = [];
        $intentos = 0;

        // Pivotes para el desvío: el bloqueo más cercano a la ruta y el que cae más
        // cerca de la mitad del trayecto (rodearlo suele abrir un camino paralelo).
        foreach ($this->pivotes($linea, $enRuta) as $bloqueo) {
            foreach ([2500.0, 5000.0, 8000.0] as $metros) {
                foreach ([1, -1] as $lado) {
                    if ($intentos >= 10) {
                        break 3; // cota dura para no agotar el timeout de Lambda
                    }
                    $intentos++;
                    try {
                        $wp = GeoIstmo::desvioPerpendicular($bloqueo, $linea, $metros * $lado);
                        if (!GeoIstmo::dentroDelIstmo($wp['lat'], $wp['lng'])) {
                            continue;
                        }
                        $alt = $this->calcularRuta($origen, $destino, [[$wp['lng'], $wp['lat']]]);
                        $bloqueosAlt = $this->bloqueosSobre($alt['linea'], $activos);

                        // Solo las que mejoran (menos bloqueos que la directa).
                        if (count($bloqueosAlt) >= $baseBloqueos) {
                            continue;
                        }

                        // Deduplicar rutas casi idénticas (misma distancia + nº de bloqueos).
                        $firma = round($alt['resumen']['distancia_km'], 1) . ':' . count($bloqueosAlt);
                        if (isset($vistas[$firma])) {
                            continue;
                        }
                        $vistas[$firma] = true;

                        $candidatas[] = [
                            'libre' => count($bloqueosAlt) === 0,
                            'resumen' => $alt['resumen'],
                            'geometria' => $alt['linea'],
                            'bloqueos_en_ruta' => $bloqueosAlt,
                        ];
                    } catch (\Throwable $e) {
                        report($e); // una candidata falló: seguimos con las demás
                    }
                }
            }
        }

        // Ranking: menos bloqueos primero; a igualdad, la más rápida.
        usort($candidatas, fn ($a, $b) =>
            count($a['bloqueos_en_ruta']) <=> count($b['bloqueos_en_ruta'])
                ?: $a['resumen']['duracion_min'] <=> $b['resumen']['duracion_min']);

        return array_slice($candidatas, 0, 2);
    }

    /** Bloqueos a usar como pivote del desvío: el más cercano a la ruta y el del medio. */
    private function pivotes(array $linea, array $enRuta): array
    {
        $pivotes = [$enRuta[0]];
        if (count($enRuta) > 1 && !empty($linea)) {
            $medio = $linea[intdiv(count($linea), 2)];
            $delMedio = null;
            $mejor = INF;
            foreach ($enRuta as $b) {
                $d = GeoIstmo::distanciaAPolilinea(['lat' => $b['lat'], 'lng' => $b['lng']], [$medio, $medio]);
                if ($d < $mejor) {
                    $mejor = $d;
                    $delMedio = $b;
                }
            }
            if ($delMedio && $delMedio['id'] !== $enRuta[0]['id']) {
                $pivotes[] = $delMedio;
            }
        }
        return $pivotes;
    }

    private function location(): LocationServiceClient
    {
        return new LocationServiceClient([
            'region' => config('vialibre.region'),
            'version' => 'latest',
        ]);
    }
}
