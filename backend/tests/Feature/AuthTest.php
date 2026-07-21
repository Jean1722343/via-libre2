<?php

namespace Tests\Feature;

use App\Support\DynamoUsuarios;
use App\Support\Jwt;
use Illuminate\Support\Facades\Hash;
use Mockery\MockInterface;
use Tests\TestCase;

class AuthTest extends TestCase
{
    public function test_registro_crea_usuario_y_devuelve_token(): void
    {
        $this->mock(DynamoUsuarios::class, function (MockInterface $m) {
            $m->shouldReceive('buscarPorEmail')->once()->andReturn(null);
            $m->shouldReceive('guardar')->once();
        });

        $this->postJson('/api/auth/registro', [
            'nombre' => 'Ana', 'email' => 'ana@vialibre.mx', 'password' => 'secreto123',
        ])
            ->assertCreated()
            ->assertJsonStructure(['token', 'usuario' => ['id', 'email', 'nombre', 'rol']])
            ->assertJsonPath('usuario.rol', 'usuario')
            ->assertJsonMissingPath('usuario.password_hash');
    }

    public function test_registro_rechaza_email_duplicado(): void
    {
        $this->mock(DynamoUsuarios::class, function (MockInterface $m) {
            $m->shouldReceive('buscarPorEmail')->once()->andReturn(['id' => 'x', 'email' => 'ana@vialibre.mx']);
        });

        $this->postJson('/api/auth/registro', [
            'nombre' => 'Ana', 'email' => 'ana@vialibre.mx', 'password' => 'secreto123',
        ])->assertStatus(409);
    }

    public function test_login_correcto_devuelve_token(): void
    {
        $this->mock(DynamoUsuarios::class, function (MockInterface $m) {
            $m->shouldReceive('buscarPorEmail')->once()->andReturn([
                'id' => 'x', 'email' => 'ana@vialibre.mx', 'nombre' => 'Ana', 'rol' => 'usuario',
                'password_hash' => Hash::make('secreto123'),
            ]);
        });

        $this->postJson('/api/auth/login', ['email' => 'ana@vialibre.mx', 'password' => 'secreto123'])
            ->assertOk()
            ->assertJsonStructure(['token', 'usuario']);
    }

    public function test_login_con_password_incorrecta_da_401(): void
    {
        $this->mock(DynamoUsuarios::class, function (MockInterface $m) {
            $m->shouldReceive('buscarPorEmail')->once()->andReturn([
                'id' => 'x', 'email' => 'ana@vialibre.mx', 'password_hash' => Hash::make('otra-cosa'),
            ]);
        });

        $this->postJson('/api/auth/login', ['email' => 'ana@vialibre.mx', 'password' => 'secreto123'])
            ->assertStatus(401);
    }

    public function test_yo_requiere_token(): void
    {
        $this->getJson('/api/auth/yo')->assertStatus(401);
    }

    public function test_yo_devuelve_el_usuario_del_token(): void
    {
        $this->mock(DynamoUsuarios::class, function (MockInterface $m) {
            $m->shouldReceive('buscarPorId')->once()->andReturn([
                'id' => 'x', 'email' => 'ana@vialibre.mx', 'nombre' => 'Ana', 'rol' => 'noticiero',
            ]);
        });

        $token = Jwt::emitir(['id' => 'x', 'rol' => 'noticiero', 'nombre' => 'Ana', 'email' => 'ana@vialibre.mx']);

        $this->getJson('/api/auth/yo', ['Authorization' => "Bearer $token"])
            ->assertOk()
            ->assertJsonPath('usuario.rol', 'noticiero');
    }

    public function test_social_dormido_sin_configurar(): void
    {
        // Sin GOOGLE_CLIENT_ID configurado, el login social responde 501.
        $this->postJson('/api/auth/social', ['proveedor' => 'google', 'token' => 'x'])
            ->assertStatus(501);
    }
}
