<?php

namespace App\Http\Controllers;

use Aws\S3\S3Client;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

// Genera una URL firmada para que el frontend suba la foto DIRECTO a S3
// (sin pasar el archivo por Lambda, que tiene límite de payload y timeout).
class FotoController extends Controller
{
    private const TIPOS_OK = [
        'image/jpeg' => 'jpg',
        'image/png'  => 'png',
        'image/webp' => 'webp',
    ];

    // POST /api/fotos/firma   body: { tipo: "image/jpeg" }
    public function firmar(Request $request): JsonResponse
    {
        $bucket = config('vialibre.fotos.bucket');
        if (!$bucket) {
            return response()->json(
                ['error' => 'La subida de fotos no está configurada (falta FOTOS_BUCKET).'],
                501
            );
        }

        $tipo = $request->validate([
            'tipo' => 'required|string|in:' . implode(',', array_keys(self::TIPOS_OK)),
        ])['tipo'];

        $region = config('vialibre.region');
        $clave  = 'bloqueos/' . date('Y/m/d') . '/' . Str::uuid() . '.' . self::TIPOS_OK[$tipo];

        $s3 = new S3Client(['region' => $region, 'version' => 'latest']);

        // URL firmada de PUT: solo sirve para subir ESE objeto con ESE content-type.
        $comando = $s3->getCommand('PutObject', [
            'Bucket'      => $bucket,
            'Key'         => $clave,
            'ContentType' => $tipo,
        ]);
        $ttl = config('vialibre.fotos.firma_ttl');
        $peticion = $s3->createPresignedRequest($comando, "+{$ttl} seconds");

        return response()->json([
            'url_subida'  => (string) $peticion->getUri(),
            'url_publica' => "https://{$bucket}.s3.{$region}.amazonaws.com/{$clave}",
            'content_type' => $tipo,
            'expira_seg'  => $ttl,
            'max_bytes'   => config('vialibre.fotos.max_bytes'),
        ]);
    }
}
