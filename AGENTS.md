# RepuestosYa — Notas del entorno de desarrollo

## Entorno / Shell

- Este workspace se edita con rutas Windows (`C:\RepuestosYa`) pero el shell
  es WSL (`/mnt/c/RepuestosYa`).
- `node`/`npm` NO están en el PATH del bash WSL. Usar la ruta completa:
  `/mnt/d/Program Files/nodejs/node.exe` (o `node.exe`).
- `flutter` en bash WSL falla (`$'\r': command not found` en
  `shared.sh`). Ejecutar Flutter vía Windows:
  `cmd.exe /c "cd /d C:\RepuestosYa && flutter <comando>"`.

## Verificación

- Backend (sintaxis):
  `cd /mnt/c/RepuestosYa/backend && "/mnt/d/Program Files/nodejs/node.exe" --check src/...`
- Flutter:
  `cmd.exe /c "cd /d C:\RepuestosYa && flutter analyze"`
- Migraciones: aplicar a Supabase vía MCP (`apply_migration` usa `query`,
  no `statement`). PostgreSQL no soporta `ADD CONSTRAINT IF NOT EXISTS`:
  usar bloques `DO $$ ... IF NOT EXISTS (SELECT 1 FROM pg_constraint ...)`.

## Backend

- `backend/src/utils/geocoding.js`: geocodificación server-side (Nominatim,
  país configurable con `GEOCODING_COUNTRY`, default Ecuador) + Haversine +
  ETA de despacho. La dirección del cliente no incluye ciudad: si la
  búsqueda con calles+referencia no resuelve, cae a calle principal + país.
- Las direcciones de entrega (`direcciones_entrega`) tienen
  `latitude`/`longitude`/`coordenadas_fuente` ('gps' | 'manual'); las
  solicitudes guardan snapshot `latitud_entrega`/`longitud_entrega`; las
  cotizaciones guardan `distancia_km`/`tiempo_despacho_estimado_min`.
