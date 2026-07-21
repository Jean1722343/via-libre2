# Vía Libre Oaxaca — Backend (Laravel + AWS)

API de alertas de bloqueos del Istmo de Tehuantepec. **Laravel** como framework,
**DynamoDB** como base de datos, **Amazon Location** para mapas/rutas y **SNS**
para alertas. Se desarrolla en local con **Docker** y se despliega en **AWS
Lambda con Bref**, provisionado por **Terraform** (con presupuesto de $10).

## Arquitectura

```
Frontend (Nuxt)
    │  HTTPS
    ▼
API Gateway ──► Lambda (Laravel + Bref) ──► DynamoDB        (bloqueos, TTL)
                                        ├──► Amazon Location (rutas + geocode)
                                        └──► SNS             (alertas)
```

### Endpoints (prefijo `/api`)

| Método | Ruta                          | Qué hace                                  |
|--------|-------------------------------|-------------------------------------------|
| GET    | `/api/reportes`               | Lista bloqueos activos (para el mapa)     |
| POST   | `/api/reportes`               | Registra un bloqueo                       |
| POST   | `/api/reportes/{id}/confirmar`| Vota `sigue` o `liberado`                 |
| GET    | `/api/rutas`                  | Ruta A→B + bloqueos sobre ella            |
| GET    | `/api/geocode?texto=`         | Nombre de lugar → coordenadas             |

---

## Desarrollo local (Docker) — sin AWS, sin costo

Requiere solo **Docker**. Levanta Laravel + DynamoDB Local y siembra datos del Istmo:

```bash
cd backend
docker compose up --build
```

- API en **http://localhost:8000/api**
- La primera vez instala dependencias y crea/siembra la tabla automáticamente.

Comandos útiles:

```bash
# Probar la API
curl http://localhost:8000/api/reportes

# Reejecutar la siembra
docker compose exec app php artisan dynamo:sembrar --force

# Ver logs
docker compose logs -f app

# Apagar
docker compose down
```

> Nota: `/api/rutas` y `/api/geocode` usan Amazon Location (AWS), así que en
> local devuelven error si no hay credenciales de AWS. El núcleo (reportes +
> mapa) funciona 100% en local con DynamoDB Local.

---

## Desplegar en AWS

Requiere: **AWS CLI** configurado (`aws configure`), **Docker** y **Terraform**.

```bash
cd backend
bash scripts/desplegar.sh
```

El script: crea el repositorio ECR, construye la imagen de Laravel con Bref, la
sube, y aplica el resto de la infraestructura (DynamoDB, Location, Cognito, SNS,
API Gateway y el presupuesto de $10). Al final imprime los valores para
`frontend/.env`.

| Output de Terraform | Variable en `frontend/.env`    |
|---------------------|--------------------------------|
| `api_url`           | `NUXT_PUBLIC_API_URL`          |
| `region`            | `NUXT_PUBLIC_AWS_REGION`       |
| `mapa_nombre`       | `NUXT_PUBLIC_MAP_NAME`         |
| `identity_pool_id`  | `NUXT_PUBLIC_IDENTITY_POOL_ID` |

Sembrar datos de ejemplo en AWS: `curl` los POST a `api_url/reportes`, o desde
un contenedor con las credenciales: `php artisan dynamo:sembrar --force`.

### Presupuesto de $10

`infra/budget.tf` crea un presupuesto mensual de **10 USD**. Para recibir avisos
al 80% y 100%, define tu correo en `infra/terraform.tfvars` (`email_alertas`).
El presupuesto **avisa**, no apaga recursos. Para no gastar: `terraform destroy`.

> ⚠️ El despliegue con Bref no está probado contra AWS en este equipo (no hay
> credenciales aquí). El código y la infraestructura están listos y validados
> (`terraform validate`), pero la primera vez conviene revisar el caché de
> Laravel en Lambda (ver la documentación de bref/laravel-bridge).

---

## Estructura

```
backend/
├── app/
│   ├── Http/Controllers/   ReporteController, RutaController
│   ├── Console/Commands/    dynamo:crear-tabla, dynamo:sembrar
│   └── Support/             DynamoBloqueos (repositorio), GeoIstmo
├── config/vialibre.php      Config del proyecto (tabla, región, Istmo bbox...)
├── routes/api.php           Endpoints
├── docker/                  Dockerfiles (local + bref) y entrypoint
├── docker-compose.yml       Entorno local (Laravel + DynamoDB Local)
├── scripts/desplegar.sh     Despliegue a AWS
└── infra/                   Terraform (DynamoDB, Lambda, Location, SNS, budget)
```
