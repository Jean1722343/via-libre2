# Documentación — Vía Libre Oaxaca

Guía completa del proyecto: qué resuelve, arquitectura, usuarios y roles, modelo de
datos, frontend, backend, ruteo, despliegue y cómo mejorarlo.

> **App en vivo:** https://d1ilx5zlud9ze3.cloudfront.net
> **API:** https://3s0f6i00j3.execute-api.us-east-1.amazonaws.com/api
> **Cuenta AWS:** 417191459458 · región us-east-1 · budget $10

---

## 1. Qué resuelve

En el **Istmo de Tehuantepec** los bloqueos carreteros (manifestaciones, obras,
accidentes, conflictos, derrumbes) y los **cierres programados** (desfiles,
Guelaguetza, eventos) detienen el tránsito, muchas veces sin aviso. Hoy la gente se
entera tarde, por grupos de WhatsApp revueltos, sin ubicación exacta ni forma de
saber si el bloqueo **sigue activo** o si es **de fiar**.

**Vía Libre Oaxaca** convierte ese reporte informal en un **dato vivo y confiable**:
con ubicación en el mapa, estado (activo / programado / finalizado), vigencia real
(caduca solo), **verificación** (por la comunidad o por un noticiero oficial) y un
**ruteo tipo Waze** que recalcula rutas para esquivar los bloqueos.

---

## 2. Arquitectura (todo en AWS)

```
┌──────────────────────────────┐        ┌────────────────────────────────────────┐
│  FRONTEND (Nuxt SPA estático) │  HTTPS │            BACKEND (Laravel)            │
│  S3 + CloudFront              │ ─────► │  API Gateway → Lambda (Bref, contenedor) │
│  • Landing /                  │  JWT   │        ├──► DynamoDB  bloqueos + usuarios │
│  • App de mapa /mapa          │ ◄───── │        ├──► Amazon Location (rutas/geo)  │
│  • Panel admin /admin         │  JSON  │        ├──► S3 (fotos, URL firmada)      │
│  • Tiles OpenStreetMap        │        │        └──► SNS (alertas)                │
└──────────────────────────────┘        └────────────────────────────────────────┘
```

| Parte | Dónde vive | Tecnología |
|-------|-----------|------------|
| Frontend | S3 privado + **CloudFront** (HTTPS) | Nuxt 4 SPA (`ssr:false`), Vue 3, Nuxt UI 4, Tailwind 4, MapLibre, PWA |
| Backend | **Lambda** (imagen Bref) + API Gateway | Laravel 13 (PHP 8.3) |
| Datos | **DynamoDB** — `bloqueos` (TTL) + `usuarios` (login) | AWS SDK, repositorios propios (sin Eloquent) |
| Auth | **JWT propio** (HS256) emitido por Laravel | correo/contraseña + social (dormido) |
| Mapas/rutas | **Amazon Location** (geocode + rutas) vía Lambda | — |
| Fotos | **S3** (subida directa con URL firmada) | — |
| Infra | **Terraform** (`backend/infra/`) con budget de **$10** | — |

> Frontend y backend son **dos proyectos separados** (carpetas y despliegues
> distintos): no se mezclan. Los tiles del mapa son de OpenStreetMap; el dato vive
> en DynamoDB.

---

## 3. Usuarios, roles y acceso 🔑

El login es **propio** (in-app): Laravel guarda al usuario en DynamoDB y emite un
**JWT** con su rol. El frontend lo manda en `Authorization: Bearer <token>` en cada
escritura. Reportar y confirmar **exigen sesión**.

### Roles
| Rol | Qué puede hacer |
|-----|-----------------|
| **usuario** | Reporta, pero su reporte queda **"por verificar"** hasta que la comunidad lo confirme. |
| **noticiero** | Sus reportes se publican **verificados al instante**. Además puede verificar reportes de otros. |
| **admin** | **Todos** los poderes: verificar, cerrar y borrar reportes, y cambiar el rol de cualquier usuario. |

### Verificación de un reporte
- Un **usuario** normal crea un reporte → `verificado = false` (badge "Por verificar",
  marcador con anillo punteado y "?").
- Cuando junta **`verificaciones_umbral` (2)** confirmaciones "Sigue así" de la
  comunidad → pasa a `verificado = true`.
- Un **noticiero/admin** publica ya verificado; también puede verificar con un clic.

### Proveedores de acceso
- **Correo / contraseña:** activo (registro + login).
- **Google / Facebook:** el código está listo pero **dormido**; se encienden poniendo
  sus IDs (ver §11) sin tocar código.

### 🔐 Cuenta admin (documentada)
| | |
|---|---|
| **Correo** | `admin@vialibre.mx` |
| **Contraseña** | `ViaLibre.Admin2026` |

> Se crea con `php artisan usuarios:crear-admin` (idempotente; los valores por defecto
> están en `config/vialibre.php → admin`). **Cambia la contraseña tras el primer
> acceso.** Desde el panel **/admin** puedes promover a otros a `noticiero`/`admin`.

---

## 4. El viaje de un reporte

```
1. Inicias sesión (correo/contraseña) → el frontend guarda tu JWT
2. Tocas el mapa                       → obtiene lat/lng
3. Eliges tipo, estado, descripción…   → activo ahora, o programado (con hora)
4. POST /api/reportes  (Bearer token)  → viaja al backend
5. Laravel valida (tipo, dentro del Istmo, estado) y fija verificado según tu rol
6. Genera id, calcula "expira_en", guarda en DynamoDB y avisa por SNS
7. Devuelve el bloqueo (201) → el mapa y la lista se actualizan
```

Confirmaciones de la comunidad (requieren sesión):
```
POST /api/reportes/{id}/confirmar { "voto": "sigue" }     → +1, empuja TTL +45 min;
                                                             al umbral, verifica el reporte
POST /api/reportes/{id}/confirmar { "voto": "liberado" }  → al 2º voto: estado = finalizado
```

---

## 5. Ruteo tipo Waze 🧭

`GET /api/rutas?origen…&destino…` calcula la **ruta directa** con Amazon Location y
detecta los **bloqueos activos** sobre ella. Si hay bloqueos, prueba varios desvíos
(perpendiculares al bloqueo, a distintas distancias y a ambos lados), los **rankea por
bloqueos evitados y luego por tiempo**, y devuelve hasta **2 alternativas**:

```json
{ "directa": { "libre": false, "resumen": {…}, "geometria": […], "bloqueos_en_ruta": […] },
  "alternativas": [ { "libre": true, "resumen": {…}, "geometria": […] }, … ] }
```

En el mapa se dibujan como **opciones seleccionables** (la elegida en trazo grueso
terracota; las demás finas punteadas). El buscador lista cada opción con
distancia/tiempo y "Libre" o "Evita menos: N bloqueo(s)", y permite **Recalcular**.
El origen puede fijarse con **"Mi ubicación"**.

---

## 6. Modelo de datos (DynamoDB)

**Tabla `via-libre-dev-bloqueos`** — GSI `activos-index` (`estado` HASH, `creado_en`
RANGE). TTL sobre `expira_en`.

| Campo | Notas |
|-------|-------|
| `id` | UUID (clave) |
| `estado` | **`activo` · `programado` · `finalizado`** |
| `tipo` | manifestacion, obra, accidente, conflicto, derrumbe, otro |
| `lat`, `lng`, `descripcion`, `municipio` | ubicación y texto |
| `verificado` | **bool** — si es un dato de fiar |
| `autor_id`, `autor_rol`, `autor_nombre`, `autor_foto` | quién lo reportó |
| `inicia_en` | solo `programado` ("INICIA 14:00") |
| `ruta_alterna_texto` | sugerencia mostrada en la tarjeta |
| `foto_url` | opcional (S3) |
| `confirmaciones_sigue` / `_liberado` | votos de la comunidad |
| `expira_en` | epoch (seg) — **TTL** |

**Tabla `via-libre-dev-usuarios`** — GSI `email-index` (`email` HASH). Campos:
`id`, `email`, `password_hash`, `nombre`, `rol`, `proveedor`, `foto`, `creado_en`.

**Vigencia (`expira_en`):** `activo` = ahora + `ttl_horas` (2h); `programado` =
`inicia_en` + `programado_ventana_horas` (6h); `finalizado` = ahora +
`finalizado_ttl_horas` (2h).

---

## 7. Endpoints (prefijo `/api`)

| Método | Ruta | Auth | Qué hace |
|--------|------|------|----------|
| `POST` | `/auth/registro` | — | Crea cuenta (rol `usuario`) → `{token, usuario}` |
| `POST` | `/auth/login` | — | Inicia sesión → `{token, usuario}` |
| `POST` | `/auth/social` | — | Login Google/Facebook (501 si dormido) |
| `GET` | `/auth/yo` | JWT | Rehidrata la sesión |
| `GET` | `/reportes?estado=&verificado=&bbox=` | — | Lista (incluye `verificado`) |
| `GET` | `/reportes/resumen` | — | Conteos por estado |
| `POST` | `/reportes` | JWT | Crea bloqueo (verificado según rol) |
| `POST` | `/reportes/{id}/confirmar` | JWT | Vota `sigue` / `liberado` |
| `GET` | `/rutas?origen…&destino…` | — | Ruta directa + **alternativas** |
| `GET` | `/geocode?texto=` | — | Nombre de lugar → coordenadas |
| `POST` | `/fotos/firma` | JWT | URL firmada para subir la foto a S3 |
| `POST` | `/reportes/{id}/verificar` | noticiero/admin | Verifica al instante |
| `POST` | `/reportes/{id}/finalizar` | admin | Cierra el reporte |
| `DELETE` | `/reportes/{id}` | admin | Borra el reporte |
| `GET` | `/admin/usuarios` | admin | Lista usuarios |
| `POST` | `/admin/usuarios/{id}/rol` | admin | Cambia el rol |

Anti-spam por IP: 10 reportes/min, 30 confirmaciones/min, 20 intentos de auth/min.

---

## 8. Frontend por dentro

| Archivo | Rol |
|---------|-----|
| `app/app.vue` | Restaura la sesión + monta el modal de login global |
| `app/pages/index.vue` · `components/landing/*` | Landing |
| `app/pages/mapa.vue` · `components/mapa/*` · `MapaBloqueos.vue` | App de mapa (2 paneles, filtros, reporte, ruta) |
| `app/pages/admin.vue` | **Panel admin** (moderar reportes + roles) |
| `app/components/auth/LoginModal.vue` | Modal de acceso (correo + social) |
| `app/components/BuscadorRuta.vue` | Ruta A→B con **opciones seleccionables** |
| `app/components/FormularioReporte.vue` | Reporte (avisa si sale "por verificar") |
| `app/composables/useAuth.ts` | Login propio (JWT) + social dormido + roles |
| `app/composables/useApi.ts` | Llamadas al backend (auth, reportes, moderación) |
| `app/composables/useLoginModal.ts` | Estado compartido del modal |
| `app/composables/useAlertasCercania.ts` | Notificaciones por cercanía + programados |
| `app/types/bloqueo.ts` | Tipos + `TIPOS_META` · `ESTADOS_META` · `ROLES_META` |

**Diseño:** paleta crema/terracota/verde-pino/ámbar, serif *Playfair Display*,
animaciones (aparición al scroll, marcadores con pulso, transiciones), PWA
instalable con caché offline. Marcadores distinguen **verificado vs por verificar**.

---

## 9. Backend por dentro

| Archivo | Rol |
|---------|-----|
| `routes/api.php` | Rutas (auth, reportes, moderación) con throttle y roles |
| `app/Http/Controllers/AuthController.php` | registro / login / social / yo |
| `app/Http/Controllers/ReporteController.php` | listar, crear (verificado por rol), confirmar, verificar/finalizar/eliminar |
| `app/Http/Controllers/AdminController.php` | listar usuarios + cambiar rol |
| `app/Http/Controllers/RutaController.php` | ruta directa + **alternativas** + geocode |
| `app/Http/Middleware/Autenticar.php` | valida el JWT (`auth.jwt`) |
| `app/Http/Middleware/ExigirRol.php` | restringe por rol (`rol:admin`…) |
| `app/Support/Jwt.php` | JWT HS256 propio (sin dependencias) |
| `app/Support/DynamoBloqueos.php` · `DynamoUsuarios.php` | Repositorios DynamoDB |
| `app/Console/Commands/` | `dynamo:crear-tabla`, `dynamo:sembrar`, `usuarios:crear-admin` |
| `config/vialibre.php` | Config (tablas, roles, umbral, JWT, admin, Istmo, tipos) |
| `tests/` | PHPUnit — reportes/roles/auth. **Ver §10.** |

---

## 10. Desarrollo local (Docker, sin costo)

```bash
cd backend
docker compose up --build     # API en http://localhost:8000/api
# crea tablas (bloqueos + usuarios), siembra ejemplos y crea el admin automáticamente
docker compose exec app php artisan test     # correr los tests
```
El admin local es el mismo: `admin@vialibre.mx` / `ViaLibre.Admin2026`.

Frontend:
```bash
cd frontend && npm install && npm run dev   # http://localhost:3000 (lee frontend/.env)
```

---

## 11. Despliegue a AWS (lo que se hizo)

```bash
# 1) Backend: ECR → imagen Bref → infra
cd backend/infra && terraform init && terraform apply -target=aws_ecr_repository.app -auto-approve
cd .. && aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <cuenta>.dkr.ecr.us-east-1.amazonaws.com
docker buildx build --platform linux/amd64 --provenance=false -f docker/bref.Dockerfile -t <ECR>:latest --push .
cd infra && terraform apply -auto-approve
aws lambda update-function-code --function-name via-libre-dev-app --image-uri <ECR>:latest

# 2) Crear admin + sembrar en las tablas reales (artisan dentro de la imagen)
docker run --rm --entrypoint /opt/bin/php -e APP_KEY=… -e AWS_ACCESS_KEY_ID=… -e AWS_SECRET_ACCESS_KEY=… \
  -e AWS_DEFAULT_REGION=us-east-1 -e DYNAMO_TABLA=via-libre-dev-bloqueos -e USUARIOS_TABLA=via-libre-dev-usuarios \
  -e JWT_SECRET=… <ECR>:latest /var/task/artisan usuarios:crear-admin

# 3) Frontend: build estático + subir + invalidar
cd ../../frontend && npm run generate
aws s3 sync .output/public s3://<web-bucket> --delete
aws cloudfront create-invalidation --distribution-id <id> --paths "/*"
```

**Notas aprendidas:** construir con `--platform linux/amd64 --provenance=false`
(Lambda rechaza el manifest-list de Docker Desktop); fijar `platform.php=8.3.32` en
`composer.json`; el JWT es propio (HS256) porque `firebase/php-jwt` está bajo un aviso
de seguridad que composer bloquea. Variables sensibles (`app_key`, `jwt_secret`) en
`infra/terraform.tfvars` (gitignored).

---

## 12. Cómo mejorar el proyecto

1. **Encender Google/Facebook**: crear el OAuth Client ID (Google) y App ID/Secret
   (Facebook), ponerlos en `frontend/.env` (`NUXT_PUBLIC_GOOGLE_CLIENT_ID`,
   `NUXT_PUBLIC_FACEBOOK_APP_ID`) y en `infra/terraform.tfvars`, y redesplegar. El
   código ya está.
2. **Rate-limit por usuario** (además de por IP) usando el `sub` del JWT.
3. **Avisos push reales** (Web Push / SNS→móvil) para bloqueos cercanos.
4. **Compartir un bloqueo por WhatsApp** (link directo a un reporte).
5. **Ruteo con evitación nativa** (Amazon Location Routes v2 con áreas de evitación)
   en vez de waypoints perpendiculares.
6. **Panel de corredores críticos**: analítica de qué tramos se bloquean más.
7. **CI/CD** (GitHub Actions): tests + despliegue al hacer merge.
8. **Recortar infra sin uso** (Amazon Location Map + Cognito, ya que el mapa usa OSM).
