<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;

// Restringe una ruta a ciertos roles. Uso: ->middleware('rol:admin') o
// ->middleware('rol:admin,noticiero'). El admin siempre pasa (tiene todos los poderes).
// Debe ir DESPUÉS de 'auth.jwt' (que adjunta el usuario).
class ExigirRol
{
    public function handle(Request $request, Closure $next, string ...$roles)
    {
        $usuario = $request->attributes->get('usuario');
        $rol = $usuario['rol'] ?? null;

        if ($rol !== 'admin' && !in_array($rol, $roles, true)) {
            return response()->json(['error' => 'No tienes permiso para esta acción.'], 403);
        }

        return $next($request);
    }
}
