<?php

use App\Http\Controllers\AdminController;
use App\Http\Controllers\AuthController;
use App\Http\Controllers\FotoController;
use App\Http\Controllers\ReporteController;
use App\Http\Controllers\RutaController;
use Illuminate\Support\Facades\Route;

// API de Vía Libre Oaxaca. Prefijo /api (configurado en bootstrap/app.php).

// ── Autenticación (login propio con JWT) ─────────────────────────────────────
Route::middleware('throttle:20,1')->group(function () {
    Route::post('/auth/registro', [AuthController::class, 'registro']);
    Route::post('/auth/login', [AuthController::class, 'login']);
    Route::post('/auth/social', [AuthController::class, 'social']);
});
Route::get('/auth/yo', [AuthController::class, 'yo'])->middleware('auth.jwt');

// ── Lectura pública: sin login (el mapa refresca cada 30 s) ──────────────────
Route::get('/reportes/resumen', [ReporteController::class, 'resumen']);
Route::get('/reportes', [ReporteController::class, 'index']);
Route::get('/rutas', [RutaController::class, 'buscar']);
Route::get('/geocode', [RutaController::class, 'geocodificar']);

// ── Escritura: requiere sesión (JWT) + anti-spam por IP ──────────────────────
Route::middleware(['throttle:10,1', 'auth.jwt'])->group(function () {
    Route::post('/reportes', [ReporteController::class, 'store']);
    Route::post('/fotos/firma', [FotoController::class, 'firmar']);
});

Route::post('/reportes/{id}/confirmar', [ReporteController::class, 'confirmar'])
    ->middleware(['throttle:30,1', 'auth.jwt']);

// ── Moderación (noticiero / admin) ───────────────────────────────────────────
Route::middleware(['auth.jwt', 'rol:noticiero'])->group(function () {
    Route::post('/reportes/{id}/verificar', [ReporteController::class, 'verificar']);
});

Route::middleware(['auth.jwt', 'rol:admin'])->group(function () {
    Route::post('/reportes/{id}/finalizar', [ReporteController::class, 'finalizar']);
    Route::delete('/reportes/{id}', [ReporteController::class, 'eliminar']);
    Route::get('/admin/usuarios', [AdminController::class, 'usuarios']);
    Route::post('/admin/usuarios/{id}/rol', [AdminController::class, 'cambiarRol']);
});
