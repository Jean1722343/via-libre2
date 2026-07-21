<?php

namespace App\Console\Commands;

use App\Support\DynamoBloqueos;
use App\Support\DynamoUsuarios;
use Illuminate\Console\Command;

class DynamoCrearTabla extends Command
{
    protected $signature = 'dynamo:crear-tabla';
    protected $description = 'Crea las tablas de bloqueos y usuarios en DynamoDB (útil con DynamoDB Local).';

    public function handle(DynamoBloqueos $bloqueos, DynamoUsuarios $usuarios): int
    {
        $this->info('Creando tabla de bloqueos...');
        $b = $bloqueos->crearTablaSiNoExiste();
        $this->info($b ? '✓ Tabla de bloqueos creada.' : 'La tabla de bloqueos ya existía.');

        $this->info('Creando tabla de usuarios...');
        $u = $usuarios->crearTablaSiNoExiste();
        $this->info($u ? '✓ Tabla de usuarios creada.' : 'La tabla de usuarios ya existía.');

        return self::SUCCESS;
    }
}
