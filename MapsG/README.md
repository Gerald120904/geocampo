# GeoCampo Backend

Backend FastAPI para recibir mapas GIS, procesarlos en segundo plano y entregar paquetes offline `.geocampo.zip` consumibles por Flutter.

## Alcance implementado

- JWT, roles y aislamiento por empresa.
- `POST /api/auth/login` y `GET /api/auth/me`.
- Empresas, usuarios, proyectos y mapas.
- Subida multipart con limite de tamano, extension, MIME y nombres seguros.
- PostgreSQL/PostGIS, SQLAlchemy y Alembic.
- Redis y Celery para procesamiento separado cuando se necesite.
- GeoJSON, Shapefile ZIP, GeoPackage, MBTiles, GeoTIFF y GeoPDF.
- Reproyeccion vectorial a EPSG:4326, bounds, centro, propiedades y conteo de features.
- Reproyeccion raster a EPSG:3857 y generacion de `map.mbtiles` usando GDAL/rasterio.
- `metadata.json`, `preview.png`, leyenda, original y paquete `.geocampo.zip`.
- Checksum SHA256, tamano, version y fecha de creacion del paquete.
- `GET /api/maps/{map_id}/package/info` para validacion previa en Flutter.
- Observaciones de campo con CRUD y carga de foto.
- Health checks para API, base de datos, storage y Redis.
- Eliminacion logica del mapa y limpieza de derivados.

Los proyectos QGIS (`.qgs/.qgz`) quedan como fase avanzada porque requieren subir el proyecto completo junto con sus archivos referenciados.

## Inicio rapido local

Requisitos:

- Python 3.11.
- PostgreSQL con PostGIS.
- GDAL y librerias nativas GIS.
- Redis solo si va a ejecutar un worker Celery separado.

Copie `.env.example` a `.env`, cambie `JWT_SECRET_KEY`, `BOOTSTRAP_ADMIN_PASSWORD` y las credenciales de PostgreSQL. Para desarrollo local, deje `CELERY_TASK_ALWAYS_EAGER=true` y ejecute:

```bash
python -m venv .venv
.\.venv\Scripts\activate
python -m pip install --upgrade pip
pip install -r requirements-dev.txt
alembic upgrade head
uvicorn app.main:app --host 127.0.0.1 --port 8001 --reload
```

Tambien puede usar el script local:

```powershell
.\start_backend_gdal.ps1
```

La API queda en `http://localhost:8001`, Swagger en `http://localhost:8001/docs` y el health check en `http://localhost:8001/api/health`.

Administrador inicial:

```text
email: admin@geocampo.local
password: change_me_now
```

Cambie esos valores antes de cualquier despliegue real.

## Ambientes

- `.env.local`: desarrollo en la computadora, con `CELERY_TASK_ALWAYS_EAGER=true`.
- `.env.staging`: pruebas de despliegue, con API, Worker, Redis y PostgreSQL separados.
- `.env.production`: produccion, `APP_DEBUG=false`, `CELERY_TASK_ALWAYS_EAGER=false` y storage fuera del repo.
- `.env.example`: plantilla segura para compartir.

El backend carga `.env` por defecto. Para usar otro ambiente, copie el archivo correspondiente a `.env` en el servidor o configure el gestor de despliegue para pasar esas variables.

## Migraciones

FastAPI ya no crea tablas automaticamente. Alembic es la fuente de verdad del esquema:

```bash
alembic upgrade head
```

Ejecute esa migracion antes de iniciar la API.

## Worker de procesamiento

En desarrollo puede procesar en el mismo proceso con:

```env
CELERY_TASK_ALWAYS_EAGER=true
```

Para produccion o cargas pesadas, instale Redis en el servidor y ejecute el worker aparte:

```bash
celery -A app.workers.celery_app.celery_app worker --loglevel=info
```

## Contrato principal para Flutter

```text
POST /api/auth/login
GET /api/auth/me

GET /api/companies
POST /api/companies

GET /api/users
POST /api/users

GET /api/projects
POST /api/projects
GET /api/projects/{project_id}/maps

POST /api/maps/upload
POST /api/maps/{map_id}/process
GET /api/maps/{map_id}/status
GET /api/maps/{map_id}
GET /api/maps/{map_id}/preview
GET /api/maps/{map_id}/package/info
GET /api/maps/{map_id}/package
DELETE /api/maps/{map_id}

POST /api/observations
GET /api/observations/map/{map_id}
GET /api/observations/{observation_id}
PUT /api/observations/{observation_id}
DELETE /api/observations/{observation_id}
POST /api/observations/{observation_id}/photo
```

Use el token como `Authorization: Bearer <token>`.

## Tests

```bash
pytest
```

## Paquete generado

```text
mapa.geocampo.zip
|-- metadata.json
|-- map.mbtiles              # si la fuente es raster o MBTiles
|-- preview.png
|-- layers/*.geojson         # si la fuente es vectorial
|-- legend/legend.json
`-- original/archivo_original
```

Las rutas internas son relativas, los nombres se normalizan y el paquete no depende del backend una vez descargado.

## Backups minimos

- Backup diario de PostgreSQL con `pg_dump`.
- Backup diario de `originals/`, `packages/` y `photos/`.
- Retener 7 diarios, 4 semanales y 12 mensuales.
- Probar una restauracion al menos una vez al mes.

Un backup que nunca se ha restaurado no cuenta como backup real.
