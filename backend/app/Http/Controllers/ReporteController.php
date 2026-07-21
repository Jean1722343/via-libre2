<?php

namespace App\Http\Controllers;

use App\Support\DynamoBloqueos;
use App\Support\GeoIstmo;
use Aws\Sns\SnsClient;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

class ReporteController extends Controller
{
    public function __construct(private DynamoBloqueos $repo)
    {
    }

    // GET /api/reportes  (?estado=activo|programado|finalizado, ?verificado=1|0|all,
    //                     ?bbox=minLng,minLat,maxLng,maxLat)
    public function index(Request $request): JsonResponse
    {
        $estado = $request->query('estado', 'activo');
        if (!in_array($estado, config('vialibre.estados'), true)) {
            $estado = 'activo';
        }

        $bloqueos = $this->repo->listarPorEstado($estado);

        // Filtro de verificación (por defecto se devuelven todos: los "por verificar"
        // deben verse para que la comunidad los confirme).
        $verificado = $request->query('verificado', 'all');
        if ($verificado === '1') {
            $bloqueos = array_values(array_filter($bloqueos, fn ($b) => !empty($b['verificado'])));
        } elseif ($verificado === '0') {
            $bloqueos = array_values(array_filter($bloqueos, fn ($b) => empty($b['verificado'])));
        }

        if ($bbox = $request->query('bbox')) {
            [$minLng, $minLat, $maxLng, $maxLat] = array_map('floatval', explode(',', $bbox));
            $bloqueos = array_values(array_filter($bloqueos, fn ($b) =>
                $b['lng'] >= $minLng && $b['lng'] <= $maxLng &&
                $b['lat'] >= $minLat && $b['lat'] <= $maxLat));
        }

        return response()->json(['estado' => $estado, 'total' => count($bloqueos), 'bloqueos' => $bloqueos]);
    }

    // GET /api/reportes/resumen  -> conteos por estado (para los stat-dots del landing)
    public function resumen(): JsonResponse
    {
        return response()->json([
            'activos'     => count($this->repo->listarPorEstado('activo')),
            'programados' => count($this->repo->listarPorEstado('programado')),
            'finalizados' => count($this->repo->listarPorEstado('finalizado')),
        ]);
    }

    // POST /api/reportes
    public function store(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'tipo' => 'required|string|in:' . implode(',', config('vialibre.tipos')),
            'lat' => 'required|numeric',
            'lng' => 'required|numeric',
            'descripcion' => 'nullable|string|max:280',
            'municipio' => 'nullable|string|max:120',
            'foto_url' => 'nullable|url',
            'estado' => 'nullable|in:activo,programado',
            'inicia_en' => 'nullable|date|required_if:estado,programado',
            'ruta_alterna_texto' => 'nullable|string|max:160',
        ]);

        if (!GeoIstmo::dentroDelIstmo((float) $datos['lat'], (float) $datos['lng'])) {
            return response()->json(
                ['error' => 'La ubicación está fuera del Istmo de Tehuantepec.'], 422
            );
        }

        $usuario = $request->attributes->get('usuario'); // lo pone el middleware auth.jwt
        $rol = $usuario['rol'] ?? 'usuario';
        $ahora = now();
        $estado = $datos['estado'] ?? 'activo';
        $iniciaEn = isset($datos['inicia_en']) ? \Illuminate\Support\Carbon::parse($datos['inicia_en']) : null;

        // Vigencia según el estado: un programado vive hasta su inicio + ventana.
        $expira = $estado === 'programado' && $iniciaEn
            ? $iniciaEn->timestamp + config('vialibre.programado_ventana_horas') * 3600
            : $ahora->timestamp + config('vialibre.ttl_horas') * 3600;

        // Los reportes de noticiero/admin salen verificados; los de un usuario
        // normal quedan "por verificar" hasta que la comunidad los confirme.
        $verificado = in_array($rol, ['noticiero', 'admin'], true);

        $item = [
            'id' => (string) Str::uuid(),
            'estado' => $estado,
            'tipo' => $datos['tipo'],
            'lat' => (float) $datos['lat'],
            'lng' => (float) $datos['lng'],
            'descripcion' => $datos['descripcion'] ?? '',
            'municipio' => $datos['municipio'] ?? '',
            'foto_url' => $datos['foto_url'] ?? null,
            'inicia_en' => $iniciaEn?->toIso8601String(),
            'ruta_alterna_texto' => $datos['ruta_alterna_texto'] ?? null,
            'verificado' => $verificado,
            'autor_id' => $usuario['id'] ?? null,
            'autor_rol' => $rol,
            'autor_nombre' => $usuario['nombre'] ?? null,
            'autor_foto' => $usuario['foto'] ?? null,
            'creado_en' => $ahora->toIso8601String(),
            'actualizado_en' => $ahora->toIso8601String(),
            'confirmaciones_sigue' => 0,
            'confirmaciones_liberado' => 0,
            'expira_en' => $expira,
        ];

        $this->repo->guardar($item);
        $this->notificar($item);

        return response()->json($item, 201);
    }

    // POST /api/reportes/{id}/confirmar   body: { voto: "sigue" | "liberado" }
    public function confirmar(Request $request, string $id): JsonResponse
    {
        $voto = $request->validate([
            'voto' => 'required|in:sigue,liberado',
        ])['voto'];

        if (!$this->repo->existe($id)) {
            return response()->json(['error' => 'No existe un reporte con ese id.'], 404);
        }

        $actualizado = $voto === 'sigue'
            ? $this->repo->confirmarSigue($id, 45 * 60, config('vialibre.verificaciones_umbral'))
            : $this->repo->confirmarLiberado($id, 2);

        return response()->json($actualizado);
    }

    // POST /api/reportes/{id}/verificar   (rol: admin, noticiero)
    public function verificar(string $id): JsonResponse
    {
        if (!$this->repo->existe($id)) {
            return response()->json(['error' => 'No existe un reporte con ese id.'], 404);
        }
        return response()->json($this->repo->verificar($id));
    }

    // POST /api/reportes/{id}/finalizar   (rol: admin)
    public function finalizar(string $id): JsonResponse
    {
        if (!$this->repo->existe($id)) {
            return response()->json(['error' => 'No existe un reporte con ese id.'], 404);
        }
        return response()->json($this->repo->finalizar($id));
    }

    // DELETE /api/reportes/{id}   (rol: admin)
    public function eliminar(string $id): JsonResponse
    {
        if (!$this->repo->existe($id)) {
            return response()->json(['error' => 'No existe un reporte con ese id.'], 404);
        }
        $this->repo->eliminar($id);
        return response()->json(['ok' => true]);
    }

    private function notificar(array $item): void
    {
        $arn = config('vialibre.sns_topico');
        if (!$arn) {
            return;
        }
        try {
            $sns = new SnsClient(['region' => config('vialibre.region'), 'version' => 'latest']);
            $sns->publish([
                'TopicArn' => $arn,
                'Subject' => 'Nuevo bloqueo en el Istmo',
                'Message' => "Bloqueo ({$item['tipo']}) en " . ($item['municipio'] ?: 'el Istmo') .
                    ": " . ($item['descripcion'] ?: 'sin descripción') .
                    "\nUbicación: {$item['lat']}, {$item['lng']}",
            ]);
        } catch (\Throwable $e) {
            report($e); // best-effort: no bloquea la respuesta
        }
    }
}
