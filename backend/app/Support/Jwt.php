<?php

namespace App\Support;

// Emisión y verificación de los tokens de sesión (JWT HS256) SIN dependencias
// externas. El backend es la única autoridad: firma con `vialibre.jwt_secret` y
// valida (firma + expiración) en cada petición de escritura.
class Jwt
{
    private static function secreto(): string
    {
        return (string) config('vialibre.jwt_secret');
    }

    private static function b64(string $bin): string
    {
        return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
    }

    private static function b64decode(string $txt): string
    {
        return base64_decode(strtr($txt, '-_', '+/')) ?: '';
    }

    private static function firma(string $cuerpo): string
    {
        return self::b64(hash_hmac('sha256', $cuerpo, self::secreto(), true));
    }

    /** Genera un token para un usuario ya autenticado. */
    public static function emitir(array $usuario): string
    {
        $ahora = time();
        $header = self::b64(json_encode(['typ' => 'JWT', 'alg' => 'HS256']));
        $payload = self::b64(json_encode([
            'sub'    => $usuario['id'],
            'rol'    => $usuario['rol'] ?? 'usuario',
            'nombre' => $usuario['nombre'] ?? '',
            'email'  => $usuario['email'] ?? '',
            'foto'   => $usuario['foto'] ?? null,
            'iat'    => $ahora,
            'exp'    => $ahora + config('vialibre.jwt_dias') * 86400,
        ]));

        return "$header.$payload." . self::firma("$header.$payload");
    }

    /**
     * Verifica firma y expiración; devuelve los claims o null si es inválido.
     * @return array<string, mixed>|null
     */
    public static function verificar(string $token): ?array
    {
        $partes = explode('.', $token);
        if (count($partes) !== 3) {
            return null;
        }
        [$header, $payload, $firma] = $partes;

        // Firma (comparación en tiempo constante).
        if (!hash_equals(self::firma("$header.$payload"), $firma)) {
            return null;
        }

        $claims = json_decode(self::b64decode($payload), true);
        if (!is_array($claims)) {
            return null;
        }
        // Expiración.
        if (($claims['exp'] ?? 0) < time()) {
            return null;
        }

        return $claims;
    }
}
