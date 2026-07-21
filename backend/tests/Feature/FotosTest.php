<?php

namespace Tests\Feature;

use App\Support\Jwt;
use Tests\TestCase;

class FotosTest extends TestCase
{
    /** Cabecera con un JWT válido (la firma de fotos exige sesión). */
    private function auth(): array
    {
        return ['Authorization' => 'Bearer ' . Jwt::emitir([
            'id' => 'u1', 'rol' => 'usuario', 'nombre' => 'Ana', 'email' => 'ana@vialibre.mx',
        ])];
    }

    public function test_sin_bucket_configurado_responde_no_disponible(): void
    {
        config(['vialibre.fotos.bucket' => null]);

        $this->postJson('/api/fotos/firma', ['tipo' => 'image/jpeg'], $this->auth())
            ->assertStatus(501);
    }

    public function test_rechaza_tipo_de_archivo_no_permitido(): void
    {
        config(['vialibre.fotos.bucket' => 'un-bucket']);

        $this->postJson('/api/fotos/firma', ['tipo' => 'application/pdf'], $this->auth())
            ->assertStatus(422)->assertJsonValidationErrorFor('tipo');
    }

    public function test_sin_sesion_da_401(): void
    {
        $this->postJson('/api/fotos/firma', ['tipo' => 'image/jpeg'])
            ->assertStatus(401);
    }
}
