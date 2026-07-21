<?php

namespace App\Console\Commands;

use App\Support\DynamoUsuarios;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class CrearAdmin extends Command
{
    protected $signature = 'usuarios:crear-admin
        {--email= : Correo del admin (por defecto config vialibre.admin.email)}
        {--password= : Contraseña (por defecto config vialibre.admin.password)}
        {--force : Restablecer la contraseña si el admin ya existe}';

    protected $description = 'Crea (o restablece) la cuenta administradora.';

    public function handle(DynamoUsuarios $usuarios): int
    {
        $email = mb_strtolower($this->option('email') ?: config('vialibre.admin.email'));
        $password = $this->option('password') ?: config('vialibre.admin.password');
        $nombre = config('vialibre.admin.nombre');

        $existente = $usuarios->buscarPorEmail($email);
        if ($existente && !$this->option('force')) {
            // Aseguramos que tenga rol admin, pero no tocamos la contraseña.
            if (($existente['rol'] ?? '') !== 'admin') {
                $usuarios->actualizarRol($existente['id'], 'admin');
                $this->info("El usuario {$email} ya existía; se le asignó el rol admin.");
            } else {
                $this->info("El admin {$email} ya existe (usa --force para restablecer la contraseña).");
            }
            return self::SUCCESS;
        }

        $usuarios->guardar([
            'id' => $existente['id'] ?? (string) Str::uuid(),
            'email' => $email,
            'password_hash' => Hash::make($password),
            'nombre' => $existente['nombre'] ?? $nombre,
            'rol' => 'admin',
            'proveedor' => 'correo',
            'foto' => $existente['foto'] ?? null,
            'creado_en' => $existente['creado_en'] ?? now()->toIso8601String(),
        ]);

        $this->info('✓ Cuenta admin lista:');
        $this->line("  Correo:     {$email}");
        $this->line("  Contraseña: {$password}");
        $this->warn('  Cambia la contraseña tras el primer acceso.');

        return self::SUCCESS;
    }
}
