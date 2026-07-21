<?php

namespace Tests\Feature;

use App\Support\DynamoBloqueos;
use App\Support\Jwt;
use Mockery\MockInterface;
use Tests\TestCase;

class ReportesTest extends TestCase
{
    /** Cabecera Authorization con un JWT recién emitido para el rol dado. */
    private function auth(string $rol = 'usuario'): array
    {
        $token = Jwt::emitir([
            'id' => "user-$rol",
            'rol' => $rol,
            'nombre' => ucfirst($rol),
            'email' => "$rol@vialibre.mx",
        ]);
        return ['Authorization' => "Bearer $token"];
    }

    public function test_lista_bloqueos_activos(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('listarPorEstado')->with('activo')->once()->andReturn([
                ['id' => 'a', 'tipo' => 'obra', 'lat' => 16.4, 'lng' => -95.0, 'estado' => 'activo'],
            ]);
        });

        $this->getJson('/api/reportes')
            ->assertOk()
            ->assertJson(['estado' => 'activo', 'total' => 1])
            ->assertJsonCount(1, 'bloqueos');
    }

    public function test_lista_filtra_por_estado(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('listarPorEstado')->with('programado')->once()->andReturn([]);
        });

        $this->getJson('/api/reportes?estado=programado')
            ->assertOk()
            ->assertJson(['estado' => 'programado', 'total' => 0]);
    }

    public function test_lista_filtra_por_verificado(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('listarPorEstado')->with('activo')->once()->andReturn([
                ['id' => 'a', 'estado' => 'activo', 'lat' => 16.4, 'lng' => -95.0, 'verificado' => true],
                ['id' => 'b', 'estado' => 'activo', 'lat' => 16.4, 'lng' => -95.0, 'verificado' => false],
            ]);
        });

        $this->getJson('/api/reportes?verificado=1')
            ->assertOk()
            ->assertJson(['total' => 1])
            ->assertJsonPath('bloqueos.0.id', 'a');
    }

    public function test_resumen_cuenta_por_estado(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('listarPorEstado')->with('activo')->once()->andReturn([[], []]);
            $m->shouldReceive('listarPorEstado')->with('programado')->once()->andReturn([[]]);
            $m->shouldReceive('listarPorEstado')->with('finalizado')->once()->andReturn([]);
        });

        $this->getJson('/api/reportes/resumen')
            ->assertOk()
            ->assertJson(['activos' => 2, 'programados' => 1, 'finalizados' => 0]);
    }

    public function test_reportar_sin_sesion_da_401(): void
    {
        $this->postJson('/api/reportes', [
            'tipo' => 'obra', 'lat' => 16.4331, 'lng' => -95.0208,
        ])->assertStatus(401);
    }

    public function test_crea_un_bloqueo_programado(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('guardar')->once();
        });

        $this->postJson('/api/reportes', [
            'tipo' => 'obra',
            'lat' => 16.5017,
            'lng' => -95.0453,
            'estado' => 'programado',
            'inicia_en' => now()->addHours(3)->toIso8601String(),
            'ruta_alterna_texto' => 'Toma el libramiento',
        ], $this->auth('noticiero'))
            ->assertCreated()
            ->assertJson(['estado' => 'programado', 'ruta_alterna_texto' => 'Toma el libramiento'])
            ->assertJsonPath('inicia_en', fn ($v) => !empty($v));
    }

    public function test_reporte_de_usuario_queda_por_verificar(): void
    {
        $this->mock(DynamoBloqueos::class, fn (MockInterface $m) => $m->shouldReceive('guardar')->once());

        $this->postJson('/api/reportes', [
            'tipo' => 'obra', 'lat' => 16.4331, 'lng' => -95.0208,
        ], $this->auth('usuario'))
            ->assertCreated()
            ->assertJson(['verificado' => false, 'autor_rol' => 'usuario']);
    }

    public function test_reporte_de_noticiero_sale_verificado(): void
    {
        $this->mock(DynamoBloqueos::class, fn (MockInterface $m) => $m->shouldReceive('guardar')->once());

        $this->postJson('/api/reportes', [
            'tipo' => 'obra', 'lat' => 16.4331, 'lng' => -95.0208,
        ], $this->auth('noticiero'))
            ->assertCreated()
            ->assertJson(['verificado' => true, 'autor_rol' => 'noticiero']);
    }

    public function test_programado_exige_hora_de_inicio(): void
    {
        $this->postJson('/api/reportes', [
            'tipo' => 'obra',
            'lat' => 16.5017,
            'lng' => -95.0453,
            'estado' => 'programado',
        ], $this->auth())->assertStatus(422)->assertJsonValidationErrorFor('inicia_en');
    }

    public function test_crea_un_bloqueo_valido(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('guardar')->once();
        });

        $this->postJson('/api/reportes', [
            'tipo' => 'manifestacion',
            'lat' => 16.4331,
            'lng' => -95.0208,
            'descripcion' => 'Bloqueo de prueba',
            'municipio' => 'Juchitán',
        ], $this->auth())
            ->assertCreated()
            ->assertJson([
                'estado' => 'activo',
                'tipo' => 'manifestacion',
                'confirmaciones_sigue' => 0,
            ])
            ->assertJsonStructure(['id', 'expira_en', 'creado_en']);
    }

    public function test_rechaza_tipo_invalido(): void
    {
        $this->postJson('/api/reportes', [
            'tipo' => 'zombies',
            'lat' => 16.4331,
            'lng' => -95.0208,
        ], $this->auth())->assertStatus(422)->assertJsonValidationErrorFor('tipo');
    }

    public function test_rechaza_ubicacion_fuera_del_istmo(): void
    {
        $this->postJson('/api/reportes', [
            'tipo' => 'obra',
            'lat' => 19.4326, // CDMX
            'lng' => -99.1332,
        ], $this->auth())->assertStatus(422)->assertJsonPath('error', fn ($e) => str_contains($e, 'Istmo'));
    }

    public function test_confirmar_reporte_inexistente_da_404(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('existe')->once()->andReturn(false);
        });

        $this->postJson('/api/reportes/no-existe/confirmar', ['voto' => 'sigue'], $this->auth())
            ->assertStatus(404);
    }

    public function test_confirmar_sigue_extiende_el_reporte(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('existe')->once()->andReturn(true);
            $m->shouldReceive('confirmarSigue')->once()->andReturn([
                'id' => 'x', 'confirmaciones_sigue' => 1, 'estado' => 'activo',
            ]);
        });

        $this->postJson('/api/reportes/x/confirmar', ['voto' => 'sigue'], $this->auth())
            ->assertOk()
            ->assertJson(['confirmaciones_sigue' => 1]);
    }

    public function test_confirmar_con_voto_invalido_da_422(): void
    {
        $this->postJson('/api/reportes/x/confirmar', ['voto' => 'tal-vez'], $this->auth())
            ->assertStatus(422)->assertJsonValidationErrorFor('voto');
    }

    public function test_admin_puede_verificar(): void
    {
        $this->mock(DynamoBloqueos::class, function (MockInterface $m) {
            $m->shouldReceive('existe')->once()->andReturn(true);
            $m->shouldReceive('verificar')->once()->andReturn(['id' => 'x', 'verificado' => true]);
        });

        $this->postJson('/api/reportes/x/verificar', [], $this->auth('admin'))
            ->assertOk()->assertJson(['verificado' => true]);
    }

    public function test_usuario_no_puede_verificar(): void
    {
        $this->postJson('/api/reportes/x/verificar', [], $this->auth('usuario'))
            ->assertStatus(403);
    }

    public function test_solo_admin_puede_borrar(): void
    {
        $this->postJson('/api/reportes/x/finalizar', [], $this->auth('noticiero'))->assertStatus(403);
        $this->deleteJson('/api/reportes/x', [], $this->auth('usuario'))->assertStatus(403);
    }

    public function test_anti_spam_bloquea_tras_muchos_reportes(): void
    {
        // El límite es 10/min por IP; el request 11 debe recibir 429.
        // Usamos payloads inválidos (422): el throttle actúa ANTES del controlador.
        $auth = $this->auth();
        for ($i = 0; $i < 10; $i++) {
            $this->postJson('/api/reportes', [], $auth)->assertStatus(422);
        }
        $this->postJson('/api/reportes', [], $auth)->assertStatus(429);
    }
}
