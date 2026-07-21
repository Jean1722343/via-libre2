<?php

namespace App\Support;

use Aws\DynamoDb\DynamoDbClient;
use Aws\DynamoDb\Marshaler;

// Repositorio de usuarios sobre DynamoDB (sin Eloquent, con el SDK de AWS).
// Tabla: PK `id` (uuid) + GSI `email-index` (HASH `email`) para el login.
class DynamoUsuarios
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
        $this->tabla = $cfg['usuarios_tabla'];
    }

    public function guardar(array $usuario): void
    {
        $this->cliente->putItem([
            'TableName' => $this->tabla,
            'Item' => $this->marshaler->marshalItem($usuario),
        ]);
    }

    /** @return array<string, mixed>|null */
    public function buscarPorEmail(string $email): ?array
    {
        $res = $this->cliente->query([
            'TableName' => $this->tabla,
            'IndexName' => 'email-index',
            'KeyConditionExpression' => 'email = :e',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([':e' => mb_strtolower($email)]),
            'Limit' => 1,
        ]);

        $items = $res['Items'] ?? [];
        return $items ? $this->marshaler->unmarshalItem($items[0]) : null;
    }

    /** @return array<string, mixed>|null */
    public function buscarPorId(string $id): ?array
    {
        $res = $this->cliente->getItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
        ]);
        return isset($res['Item']) ? $this->marshaler->unmarshalItem($res['Item']) : null;
    }

    /** @return array<int, array> Todos los usuarios (para el panel admin). */
    public function listar(): array
    {
        $res = $this->cliente->scan(['TableName' => $this->tabla]);
        $items = array_map(fn ($i) => $this->marshaler->unmarshalItem($i), $res['Items'] ?? []);

        // No exponer el hash de contraseña.
        foreach ($items as &$u) {
            unset($u['password_hash']);
        }
        usort($items, fn ($a, $b) => ($b['creado_en'] ?? '') <=> ($a['creado_en'] ?? ''));
        return $items;
    }

    public function actualizarRol(string $id, string $rol): ?array
    {
        $res = $this->cliente->updateItem([
            'TableName' => $this->tabla,
            'Key' => $this->marshaler->marshalItem(['id' => $id]),
            'UpdateExpression' => 'SET rol = :r',
            'ConditionExpression' => 'attribute_exists(id)',
            'ExpressionAttributeValues' => $this->marshaler->marshalItem([':r' => $rol]),
            'ReturnValues' => 'ALL_NEW',
        ]);
        $u = $this->marshaler->unmarshalItem($res['Attributes']);
        unset($u['password_hash']);
        return $u;
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
                ['AttributeName' => 'email', 'AttributeType' => 'S'],
            ],
            'KeySchema' => [
                ['AttributeName' => 'id', 'KeyType' => 'HASH'],
            ],
            'GlobalSecondaryIndexes' => [[
                'IndexName' => 'email-index',
                'KeySchema' => [
                    ['AttributeName' => 'email', 'KeyType' => 'HASH'],
                ],
                'Projection' => ['ProjectionType' => 'ALL'],
            ]],
        ]);

        $this->cliente->waitUntil('TableExists', ['TableName' => $this->tabla]);
        return true;
    }
}
