# Vía Libre Oaxaca

**Alertas comunitarias de bloqueos carreteros en tiempo real** para el Istmo de
Tehuantepec. Cualquier persona reporta un bloqueo en segundos y, antes de salir,
otras saben si su ruta está libre.

> Proyecto del Hackaton Kiro 2026 · Equipo Istmo

## Estructura

```
vias/
├── frontend/   App web (Nuxt 4 + Vue 3 + Nuxt UI) — mapa, reporte y rutas
└── backend/    API en Laravel (Docker local · AWS Lambda + Bref · DynamoDB · Terraform)
```

## Arrancar el frontend

```powershell
cd frontend
npm install
npm run dev        # http://localhost:3000
```

El frontend lee la API de `frontend/.env` (`NUXT_PUBLIC_API_URL`). Apunta al
backend local (`http://localhost:8000/api`) o al desplegado en AWS. Sin config de
Amazon Location, el mapa usa OpenStreetMap (modo demo).

## Arrancar el backend en local (Docker)

```bash
cd backend
docker compose up --build   # API en http://localhost:8000/api
```

## Desplegar el backend en AWS

Ver la guía completa en **[`backend/README.md`](backend/README.md)**.

```bash
cd backend
bash scripts/desplegar.sh   # ECR + imagen Bref + Terraform (con budget de $10)
```

## Funcionalidad (núcleo del PDF)

- 📍 Reportar bloqueo (ubicación, tipo, hora, descripción)
- 🗺️ Mapa en vivo con los bloqueos activos
- ✅ Confirmación comunitaria: *sigue ahí* / *ya se liberó* (los reportes caducan solos)
- 🛣️ Buscar ruta A→B y ver si tiene bloqueos
