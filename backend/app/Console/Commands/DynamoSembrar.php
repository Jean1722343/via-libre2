<?php

namespace App\Console\Commands;

use App\Support\DynamoBloqueos;
use Illuminate\Console\Command;
use Illuminate\Support\Str;

class DynamoSembrar extends Command
{
    protected $signature = 'dynamo:sembrar {--force : Sembrar aunque ya existan bloqueos}';
    protected $description = 'Carga bloqueos de ejemplo del Istmo de Tehuantepec.';

    private array $ejemplos = [
        ['tipo' => 'manifestacion', 'lat' => 16.4331, 'lng' => -95.0208, 'municipio' => 'Juchitán de Zaragoza', 'descripcion' => 'Bloqueo sobre la Transístmica por manifestación magisterial.', 'ruta_alterna_texto' => 'Toma la carretera a La Ventosa y reincorpórate en Ixtepec.'],
        ['tipo' => 'obra',          'lat' => 16.1662, 'lng' => -95.1994, 'municipio' => 'Salina Cruz', 'descripcion' => 'Repavimentación, un solo carril habilitado.'],
        ['tipo' => 'accidente',     'lat' => 16.3221, 'lng' => -95.2419, 'municipio' => 'Santo Domingo Tehuantepec', 'descripcion' => 'Volcadura de tráiler, tránsito lento.', 'ruta_alterna_texto' => 'Desvío por el libramiento sur de Tehuantepec.'],
        ['tipo' => 'conflicto',     'lat' => 16.5668, 'lng' => -95.0987, 'municipio' => 'Ciudad Ixtepec', 'descripcion' => 'Cierre carretero por conflicto agrario.'],
        ['tipo' => 'derrumbe',      'lat' => 16.8762, 'lng' => -95.0384, 'municipio' => 'Matías Romero', 'descripcion' => 'Deslave en la carretera federal 185.'],
        // Un cierre PROGRAMADO (arranca en unas horas).
        ['tipo' => 'obra',          'lat' => 16.5017, 'lng' => -95.0453, 'municipio' => 'El Espinal', 'descripcion' => 'Cierre programado por obra en el crucero principal.', 'estado' => 'programado', 'inicia_en_horas' => 3],
    ];

    public function handle(DynamoBloqueos $repo): int
    {
        if (!$this->option('force') && count($repo->listarActivos()) > 0) {
            $this->info('Ya hay bloqueos activos; se omite la siembra (usa --force para forzar).');
            return self::SUCCESS;
        }

        foreach ($this->ejemplos as $e) {
            $ahora = now();
            $estado = $e['estado'] ?? 'activo';
            $iniciaEn = isset($e['inicia_en_horas']) ? $ahora->copy()->addHours($e['inicia_en_horas']) : null;
            $expira = $estado === 'programado' && $iniciaEn
                ? $iniciaEn->timestamp + config('vialibre.programado_ventana_horas') * 3600
                : $ahora->timestamp + config('vialibre.ttl_horas') * 3600;

            $repo->guardar([
                'id' => (string) Str::uuid(),
                'estado' => $estado,
                'tipo' => $e['tipo'],
                'lat' => $e['lat'],
                'lng' => $e['lng'],
                'descripcion' => $e['descripcion'],
                'municipio' => $e['municipio'],
                'foto_url' => null,
                'inicia_en' => $iniciaEn?->toIso8601String(),
                'ruta_alterna_texto' => $e['ruta_alterna_texto'] ?? null,
                'verificado' => true,
                'autor_rol' => 'noticiero',
                'autor_nombre' => 'Vía Libre',
                'creado_en' => $ahora->toIso8601String(),
                'actualizado_en' => $ahora->toIso8601String(),
                'confirmaciones_sigue' => $estado === 'activo' ? random_int(0, 18) : 0,
                'confirmaciones_liberado' => 0,
                'expira_en' => $expira,
            ]);
            $this->line("  ✓ {$e['municipio']} ({$e['tipo']}, {$estado})");
        }

        $this->info(count($this->ejemplos) . ' bloqueos de ejemplo cargados.');
        return self::SUCCESS;
    }
}
