<?php

namespace App\Http\Middleware;

use App\Support\Jwt;
use Closure;
use Illuminate\Http\Request;

// Exige un JWT válido (Authorization: Bearer ...) y adjunta el usuario a la
// petición. Reemplaza al antiguo gate de Google en las rutas de escritura.
class Autenticar
{
    public function handle(Request $request, Closure $next)
    {
        $token = $request->bearerToken();
        if (!$token) {
            return response()->json(['error' => 'Inicia sesión para continuar.'], 401);
        }

        $claims = Jwt::verificar($token);
        if (!$claims || empty($claims['sub'])) {
            return response()->json(['error' => 'Tu sesión expiró o no es válida. Vuelve a entrar.'], 401);
        }

        $request->attributes->set('usuario', [
            'id' => $claims['sub'],
            'rol' => $claims['rol'] ?? 'usuario',
            'nombre' => $claims['nombre'] ?? '',
            'email' => $claims['email'] ?? '',
            'foto' => $claims['foto'] ?? null,
        ]);

        return $next($request);
    }
}
