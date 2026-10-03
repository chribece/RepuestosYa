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
  `cmd.exe /c "cd /d C:\RepuestosYa && flutter test"`
- **Memoria del entorno:** la suite completa puede morir con OOM del
  compilador (`Exhausted heap space`) bajo presión de RAM. Si pasa, cerrar
  procesos pesados (backend de node, gradle daemons) y correr con
  `flutter test --concurrency=1`.
- E2E (solo dispositivo físico `T10MPROPLUS00342411`, requiere backend local
  en `192.168.100.2:3000` + fixture). El default de la app apunta a
  PRODUCCIÓN (`https://repuestosya.onrender.com/api`, ver
  `lib/config/app_config.dart`); el test fija la URL local vía
  `AppConfig.overrideBaseUrl`:
  `cmd.exe /c "cd /d C:\RepuestosYa && flutter test integration_test/ -d T10MPROPLUS00342411"`
  Fixture de almacén: `"/mnt/d/Program Files/nodejs/node.exe" backend/scripts/e2e_fixture.js`.
- CI: `.github/workflows/ci.yml` (analyze + test + formato + sintaxis backend;
  el E2E NO corre en CI por requerir hardware — ver docs/TESTING.md §5).
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
