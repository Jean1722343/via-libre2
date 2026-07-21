<?php

namespace App\Http\Controllers;

use App\Support\DynamoUsuarios;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

// Acciones exclusivas del admin sobre las cuentas. Las rutas ya están protegidas
// con auth.jwt + rol:admin, así que aquí solo va la lógica.
class AdminController extends Controller
{
    public function __construct(private DynamoUsuarios $usuarios)
    {
    }

    // GET /api/admin/usuarios
    public function usuarios(): JsonResponse
    {
        return response()->json(['usuarios' => $this->usuarios->listar()]);
    }

    // POST /api/admin/usuarios/{id}/rol   { rol }
    public function cambiarRol(Request $request, string $id): JsonResponse
    {
        $rol = $request->validate([
            'rol' => 'required|in:' . implode(',', config('vialibre.roles')),
        ])['rol'];

        if (!$this->usuarios->buscarPorId($id)) {
            return response()->json(['error' => 'No existe ese usuario.'], 404);
        }

        return response()->json(['usuario' => $this->usuarios->actualizarRol($id, $rol)]);
    }
}
