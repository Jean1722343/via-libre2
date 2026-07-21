<?php

namespace App\Http\Controllers;

use App\Support\DynamoUsuarios;
use App\Support\Jwt;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class AuthController extends Controller
{
    public function __construct(private DynamoUsuarios $usuarios)
    {
    }

    // POST /api/auth/registro  { nombre, email, password }
    public function registro(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'nombre' => 'required|string|max:80',
            'email' => 'required|email|max:160',
            'password' => 'required|string|min:6|max:100',
        ]);

        $email = mb_strtolower(trim($datos['email']));
        if ($this->usuarios->buscarPorEmail($email)) {
            return response()->json(['error' => 'Ya existe una cuenta con ese correo.'], 409);
        }

        $usuario = [
            'id' => (string) Str::uuid(),
            'email' => $email,
            'password_hash' => Hash::make($datos['password']),
            'nombre' => trim($datos['nombre']),
            'rol' => 'usuario',
            'proveedor' => 'correo',
            'foto' => null,
            'creado_en' => now()->toIso8601String(),
        ];
        $this->usuarios->guardar($usuario);

        return response()->json($this->sesion($usuario), 201);
    }

    // POST /api/auth/login  { email, password }
    public function login(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'email' => 'required|email',
            'password' => 'required|string',
        ]);

        $usuario = $this->usuarios->buscarPorEmail(mb_strtolower(trim($datos['email'])));
        if (!$usuario || !isset($usuario['password_hash']) || !Hash::check($datos['password'], $usuario['password_hash'])) {
            return response()->json(['error' => 'Correo o contraseña incorrectos.'], 401);
        }

        return response()->json($this->sesion($usuario));
    }

    // POST /api/auth/social  { proveedor: google|facebook, token }
    // Verifica el token del proveedor y crea/recupera la cuenta. Dormido si el
    // proveedor no está configurado (sin Client ID / App ID).
    public function social(Request $request): JsonResponse
    {
        $datos = $request->validate([
            'proveedor' => 'required|in:google,facebook',
            'token' => 'required|string',
        ]);

        $perfil = $datos['proveedor'] === 'google'
            ? $this->verificarGoogle($datos['token'])
            : $this->verificarFacebook($datos['token']);

        if ($perfil instanceof JsonResponse) {
            return $perfil; // error ya formateado
        }

        $usuario = $this->usuarios->buscarPorEmail($perfil['email']);
        if (!$usuario) {
            $usuario = [
                'id' => (string) Str::uuid(),
                'email' => $perfil['email'],
                'password_hash' => null,
                'nombre' => $perfil['nombre'],
                'rol' => 'usuario',
                'proveedor' => $datos['proveedor'],
                'foto' => $perfil['foto'],
                'creado_en' => now()->toIso8601String(),
            ];
            $this->usuarios->guardar($usuario);
        }

        return response()->json($this->sesion($usuario));
    }

    // GET /api/auth/yo  (auth.jwt)  -> rehidrata la sesión del token
    public function yo(Request $request): JsonResponse
    {
        $u = $request->attributes->get('usuario');
        $fresco = $this->usuarios->buscarPorId($u['id']) ?? $u;
        return response()->json(['usuario' => $this->publico($fresco)]);
    }

    /** Verifica un ID token de Google. @return array|JsonResponse */
    private function verificarGoogle(string $token)
    {
        $clientId = config('vialibre.google_client_id');
        if (!$clientId) {
            return response()->json(['error' => 'El login con Google no está configurado.'], 501);
        }

        try {
            $r = Http::timeout(5)->get('https://oauth2.googleapis.com/tokeninfo', ['id_token' => $token]);
        } catch (\Throwable $e) {
            return response()->json(['error' => 'No se pudo verificar tu sesión de Google.'], 401);
        }
        if (!$r->ok() || ($r->json('aud') !== $clientId)) {
            return response()->json(['error' => 'Sesión de Google inválida.'], 401);
        }

        return [
            'email' => mb_strtolower((string) $r->json('email')),
            'nombre' => (string) ($r->json('name') ?? 'Usuario'),
            'foto' => $r->json('picture'),
        ];
    }

    /** Verifica un access token de Facebook. @return array|JsonResponse */
    private function verificarFacebook(string $token)
    {
        $appId = config('vialibre.facebook.app_id');
        $appSecret = config('vialibre.facebook.app_secret');
        if (!$appId || !$appSecret) {
            return response()->json(['error' => 'El login con Facebook no está configurado.'], 501);
        }

        try {
            $r = Http::timeout(5)->get('https://graph.facebook.com/me', [
                'fields' => 'id,name,email,picture',
                'access_token' => $token,
            ]);
        } catch (\Throwable $e) {
            return response()->json(['error' => 'No se pudo verificar tu sesión de Facebook.'], 401);
        }
        if (!$r->ok() || !$r->json('id')) {
            return response()->json(['error' => 'Sesión de Facebook inválida.'], 401);
        }

        $email = $r->json('email') ?: ('fb_' . $r->json('id') . '@facebook.local');
        return [
            'email' => mb_strtolower((string) $email),
            'nombre' => (string) ($r->json('name') ?? 'Usuario'),
            'foto' => $r->json('picture.data.url'),
        ];
    }

    /** Respuesta estándar de sesión: token + usuario público. */
    private function sesion(array $usuario): array
    {
        return [
            'token' => Jwt::emitir($usuario),
            'usuario' => $this->publico($usuario),
        ];
    }

    /** Usuario sin datos sensibles (para el frontend). */
    private function publico(array $usuario): array
    {
        return [
            'id' => $usuario['id'],
            'email' => $usuario['email'],
            'nombre' => $usuario['nombre'] ?? '',
            'rol' => $usuario['rol'] ?? 'usuario',
            'foto' => $usuario['foto'] ?? null,
            'proveedor' => $usuario['proveedor'] ?? 'correo',
        ];
    }
}
