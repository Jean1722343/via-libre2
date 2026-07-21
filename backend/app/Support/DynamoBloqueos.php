<?php

namespace App\Support;

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;

// Repositorio de bloqueos sobre DynamoDB (sin Eloquent, con el SDK de AWS).
class DynamoBloqueos
{
    private DynamoDbClient $cliente;
    private Marshaler $marshaler;
    private string $tabla;

    public function __construct()
    {
        $cfg = config('vialibre');
        $args = ['region' => $cfg['region'], 'version' => 'latest'];

        // En local (DynamoDB Local) se usa un endpoint y credenciales ficticias.
        if (!empty($cfg['endpoint'])) {
            $args['endpoint'] = $cfg['endpoint'];
            $args['credentials'] = ['key' => 'local', 'secret' => 'local'];
        }

        $this->cliente = new DynamoDbClient($args);
        $this->marshaler = new Marshaler();
        $this->tabla = $cfg['tabla'];
    }

    public function guardar(array $item): void
    {
        $this->cliente->putItem([
            'TableName' => $this->tabla,
            'Item' => $this->marshaler->marshalItem($item),
        ]);
    }

    /** @return array<int, array> Bloqueos de un estado (no caducados), recientes primero. */
    public function listarPorEstado(string $estado): array
    {
        $res = $this->cliente->query([
            'TableName' => $this->tabla,
            'IndexName' => 'activos-index',
            'KeyConditionExpression' => 'estado = :e',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([':e' => $estado]),
            'ScanIndexForward' => false,
        ]);

        $ahora = time();
        $items = array_map(fn ($i) => $this->marshaler->unmarshalItem($i), $res['Items'] ?? []);

        return array_values(array_filter($items, fn ($b) => ($b['expira_en'] ?? 0) > $ahora));
    }

    /** @return array<int, array> Atajo para los bloqueos activos. */
    public function listarActivos(): array
    {
        return $this->listarPorEstado('activo');
    }

    public function existe(string $id): bool
    {
        $res = $this->cliente->getItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
        ]);
        return isset($res['Item']);
    }

    /**
     * Suma un voto "sigue ahí" y empuja el TTL hacia adelante. Si el reporte aún
     * no está verificado y alcanza el umbral de confirmaciones, la comunidad lo
     * verifica (verificado = true).
     */
    public function confirmarSigue(string $id, int $extensionSeg, int $umbral = PHP_INT_MAX): array
    {
        $res = $this->cliente->updateItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
            'UpdateExpression' => 'SET confirmaciones_sigue = confirmaciones_sigue + :uno, expira_en = :nuevo, actualizado_en = :t',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([
                ':uno' => 1,
                ':nuevo' => time() + $extensionSeg,
                ':t' => now()->toIso8601String(),
            ]),
            'ReturnValues' => 'ALL_NEW',
        ]);
        $item = $this->marshaler->unmarshalItem($res['Attributes']);

        if (empty($item['verificado']) && ($item['confirmaciones_sigue'] ?? 0) >= $umbral) {
            $item = $this->verificar($id);
        }

        return $item;
    }

    /** Marca un reporte como verificado (comunidad al umbral, o admin/noticiero). */
    public function verificar(string $id): array
    {
        $res = $this->cliente->updateItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
            'UpdateExpression' => 'SET verificado = :v, actualizado_en = :t',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([
                ':v' => true,
                ':t' => now()->toIso8601String(),
            ]),
            'ReturnValues' => 'ALL_NEW',
        ]);
        return $this->marshaler->unmarshalItem($res['Attributes']);
    }

    /** Cierra un reporte como "finalizado" (moderación admin). */
    public function finalizar(string $id): array
    {
        $res = $this->cliente->updateItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
            'UpdateExpression' => 'SET estado = :fin, expira_en = :hasta, actualizado_en = :t',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([
                ':fin' => 'finalizado',
                ':hasta' => time() + config('vialibre.finalizado_ttl_horas') * 3600,
                ':t' => now()->toIso8601String(),
            ]),
            'ReturnValues' => 'ALL_NEW',
        ]);
        return $this->marshaler->unmarshalItem($res['Attributes']);
    }

    /** Borra un reporte (moderación admin). */
    public function eliminar(string $id): void
    {
        $this->cliente->deleteItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
        ]);
    }

    /** Suma un voto "liberado"; si llega al umbral, cierra el reporte. */
    public function confirmarLiberado(string $id, int $umbral): array
    {
        $res = $this->cliente->updateItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
            'UpdateExpression' => 'SET confirmaciones_liberado = confirmaciones_liberado + :uno, actualizado_en = :t',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([
                ':uno' => 1,
                ':t' => now()->toIso8601String(),
            ]),
            'ReturnValues' => 'ALL_NEW',
        ]);
        $item = $this->marshaler->unmarshalItem($res['Attributes']);

        $enCurso = in_array($item['estado'] ?? '', ['activo', 'programado'], true);
        if (($item['confirmaciones_liberado'] ?? 0) >= $umbral && $enCurso) {
            $res = $this->cliente->updateItem([
                'TableName' => $this->tabla,
                'Key' => $this->marshaler->marshalItem(['id' => $id]),
                'UpdateExpression' => 'SET estado = :fin, expira_en = :hasta',
                'ExpressionAttributeValues' => $this->marshaler->marshalItem([
                    ':fin' => 'finalizado',
                    ':hasta' => time() + config('vialibre.finalizado_ttl_horas') * 3600,
                ]),
                'ReturnValues' => 'ALL_NEW',
            ]);
            $item = $this->marshaler->unmarshalItem($res['Attributes']);
        }

        return $item;
    }

    /** Crea la tabla (para desarrollo local con DynamoDB Local). */
    public function crearTablaSiNoExiste(): bool
    {
        $existentes = $this->cliente->listTables()['TableNames'] ?? [];
        if (in_array($this->tabla, $existentes, true)) {
            return false;
        }

        $this->cliente->createTable([
            'TableName' => $this->tabla,
            'BillingMode' => 'PAY_PER_REQUEST',
            'AttributeDefinitions' => [
                ['AttributeName' => 'id', 'AttributeType' => 'S'],
                ['AttributeName' => 'estado', 'AttributeType' => 'S'],
                ['AttributeName' => 'creado_en', 'AttributeType' => 'S'],
            ],
            'KeySchema' => [
                ['AttributeName' => 'id', 'KeyType' => 'HASH'],
            ],
            'GlobalSecondaryIndexes' => [[
                'IndexName' => 'activos-index',
                'KeySchema' => [
                    ['AttributeName' => 'estado', 'KeyType' => 'HASH'],
                    ['AttributeName' => 'creado_en', 'KeyType' => 'RANGE'],
                ],
                'Projection' => ['ProjectionType' => 'ALL'],
            ]],
        ]);

        $this->cliente->waitUntil('TableExists', ['TableName' => $this->tabla]);
        return true;
    }
}
