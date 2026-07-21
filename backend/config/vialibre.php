<?php

// Configuración específica de Vía Libre Oaxaca.
return [
    // DynamoDB
    'tabla'    => env('DYNAMO_TABLA', 'via-libre-bloqueos'),
    'region'   => env('AWS_DEFAULT_REGION', 'us-east-1'),
    // En local apunta a DynamoDB Local (docker). En AWS se deja vacío.
    'endpoint' => env('DYNAMO_ENDPOINT', null),

    // Horas de vigencia por defecto de un reporte ACTIVO sin confirmaciones.
    'ttl_horas' => (int) env('TTL_HORAS', 2),
    // Un reporte "finalizado" sigue visible (pestaña Finalizados) estas horas.
    'finalizado_ttl_horas' => (int) env('FINALIZADO_TTL_HORAS', 2),
    // Un reporte "programado" vive hasta su inicio + esta ventana.
    'programado_ventana_horas' => (int) env('PROGRAMADO_VENTANA_HORAS', 6),

    // Amazon Location Service
    'location' => [
        'calculadora'    => env('LOCATION_CALCULADORA', 'via-libre-dev-rutas'),
        'indice_lugares' => env('LOCATION_INDICE', 'via-libre-dev-lugares'),
    ],

    // SNS (opcional): ARN del tópico de alertas.
    'sns_topico' => env('SNS_TOPICO', null),

    // ── Usuarios, roles y autenticación propia (JWT) ─────────────────────────
    // Tabla de usuarios en DynamoDB.
    'usuarios_tabla' => env('USUARIOS_TABLA', 'via-libre-usuarios'),
    // Secreto para firmar los JWT (HS256). En AWS llega por variable de entorno.
    'jwt_secret' => env('JWT_SECRET', env('APP_KEY', 'via-libre-secreto-dev')),
    // Días de vigencia del token de sesión.
    'jwt_dias' => (int) env('JWT_DIAS', 7),
    // Roles válidos, de menor a mayor poder.
    'roles' => ['usuario', 'noticiero', 'admin'],
    // Confirmaciones "sigue ahí" necesarias para que un reporte de un usuario
    // normal pase a "verificado" por la comunidad.
    'verificaciones_umbral' => (int) env('VERIFICACIONES_UMBRAL', 2),
    // Credenciales de la cuenta admin que crea el comando usuarios:crear-admin.
    'admin' => [
        'email'    => env('ADMIN_EMAIL', 'admin@vialibre.mx'),
        'password' => env('ADMIN_PASSWORD', 'ViaLibre.Admin2026'),
        'nombre'   => env('ADMIN_NOMBRE', 'Administrador'),
    ],

    // Login con Google: Client ID (Web) para verificar el ID token. Vacío = dormido.
    'google_client_id' => env('GOOGLE_CLIENT_ID', null),

    // Login con Facebook: App ID/Secret para verificar el access token. Vacío = dormido.
    'facebook' => [
        'app_id'     => env('FACEBOOK_APP_ID', null),
        'app_secret' => env('FACEBOOK_APP_SECRET', null),
    ],

    // S3 para fotos de los bloqueos (opcional). Si no hay bucket, la app sigue
    // funcionando pero sin subida de imágenes.
    'fotos' => [
        'bucket' => env('FOTOS_BUCKET', null),
        // Segundos de validez de la URL firmada de subida.
        'firma_ttl' => (int) env('FOTOS_FIRMA_TTL', 300),
        // Tamaño máximo aceptado en el firmado (bytes). 5 MB por defecto.
        'max_bytes' => (int) env('FOTOS_MAX_BYTES', 5 * 1024 * 1024),
    ],

    // Caja aproximada del Istmo de Tehuantepec para validar coordenadas.
    'istmo_bbox' => [
        'minLat' => 15.6, 'maxLat' => 17.7,
        'minLng' => -96.3, 'maxLng' => -94.0,
    ],

    // Tipos de bloqueo válidos.
    'tipos' => ['manifestacion', 'obra', 'accidente', 'conflicto', 'derrumbe', 'otro'],

    // Estados de un reporte. "activo" y "programado" se crean; "finalizado" lo
    // marca la comunidad al confirmar que ya se liberó.
    'estados' => ['activo', 'programado', 'finalizado'],
];
