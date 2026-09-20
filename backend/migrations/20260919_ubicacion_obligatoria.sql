-- Migración: Ubicación obligatoria (GPS + geocodificación server-side)
-- 2026-09-19
--
-- La ubicación es núcleo del flujo, no un añadido: sin coordenadas confiables
-- el almacén no puede calcular tiempos/costos de despacho ni el cliente puede
-- validar que el almacén sugerido esté dentro de un radio razonable.
--
-- 1. direcciones_entrega: recupera las coordenadas del diseño original
--    (bd-repuestosya-tablas.md) que la migración
--    update_direcciones_entrega_structure.sql eliminó. La fuente queda
--    registrada: 'gps' (dispositivo) o 'manual' (geocodificada server-side).
-- 2. solicitudes_repuesto: snapshot de las coordenadas de entrega al momento
--    de crear la solicitud, para que la operación sea estable aunque el
--    cliente edite su dirección después.
-- 3. cotizaciones: distancia real (km) y tiempo de despacho estimado (min)
--    entre el almacén y el punto de entrega, calculados al crear la
--    cotización.
--
-- Todas las columnas son aditivas y nullable para no romper registros
-- legacy; el backend (solicitudController/cotizacionController) es quien
-- exige coordenadas verificables al crear solicitudes/cotizaciones nuevas.
--
-- Nota: PostgreSQL no soporta ADD CONSTRAINT IF NOT EXISTS; las restricciones
-- se crean dentro de bloques DO para que la migración sea idempotente.

-- =========================================================================
-- 1. DIRECCIONES DE ENTREGA: COORDENADAS + FUENTE
-- =========================================================================

ALTER TABLE public.direcciones_entrega
  ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 8),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8),
  ADD COLUMN IF NOT EXISTS coordenadas_fuente TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'direcciones_lat_valida') THEN
    ALTER TABLE public.direcciones_entrega
      ADD CONSTRAINT direcciones_lat_valida
        CHECK (latitude IS NULL OR (latitude BETWEEN -90 AND 90));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'direcciones_lon_valida') THEN
    ALTER TABLE public.direcciones_entrega
      ADD CONSTRAINT direcciones_lon_valida
        CHECK (longitude IS NULL OR (longitude BETWEEN -180 AND 180));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'direcciones_coordenadas_ambas') THEN
    ALTER TABLE public.direcciones_entrega
      ADD CONSTRAINT direcciones_coordenadas_ambas
        CHECK ((latitude IS NULL) = (longitude IS NULL));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'direcciones_fuente_check') THEN
    ALTER TABLE public.direcciones_entrega
      ADD CONSTRAINT direcciones_fuente_check
        CHECK (coordenadas_fuente IS NULL OR coordenadas_fuente IN ('gps', 'manual'));
  END IF;
END $$;

COMMENT ON COLUMN public.direcciones_entrega.latitude IS 'Latitud de la dirección (origen: GPS del dispositivo o geocodificación server-side)';
COMMENT ON COLUMN public.direcciones_entrega.longitude IS 'Longitud de la dirección (origen: GPS del dispositivo o geocodificación server-side)';
COMMENT ON COLUMN public.direcciones_entrega.coordenadas_fuente IS 'Origen de las coordenadas: gps (dispositivo) o manual (geocodificadas por el backend)';

-- =========================================================================
-- 2. SOLICITUDES: SNAPSHOT DE COORDENADAS DE ENTREGA
-- =========================================================================

ALTER TABLE public.solicitudes_repuesto
  ADD COLUMN IF NOT EXISTS latitud_entrega NUMERIC(10, 8),
  ADD COLUMN IF NOT EXISTS longitud_entrega NUMERIC(11, 8),
  ADD COLUMN IF NOT EXISTS coordenadas_fuente TEXT;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitudes_lat_entrega_valida') THEN
    ALTER TABLE public.solicitudes_repuesto
      ADD CONSTRAINT solicitudes_lat_entrega_valida
        CHECK (latitud_entrega IS NULL OR (latitud_entrega BETWEEN -90 AND 90));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitudes_lon_entrega_valida') THEN
    ALTER TABLE public.solicitudes_repuesto
      ADD CONSTRAINT solicitudes_lon_entrega_valida
        CHECK (longitud_entrega IS NULL OR (longitud_entrega BETWEEN -180 AND 180));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitudes_coordenadas_ambas') THEN
    ALTER TABLE public.solicitudes_repuesto
      ADD CONSTRAINT solicitudes_coordenadas_ambas
        CHECK ((latitud_entrega IS NULL) = (longitud_entrega IS NULL));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'solicitudes_fuente_check') THEN
    ALTER TABLE public.solicitudes_repuesto
      ADD CONSTRAINT solicitudes_fuente_check
        CHECK (coordenadas_fuente IS NULL OR coordenadas_fuente IN ('gps', 'manual'));
  END IF;
END $$;

COMMENT ON COLUMN public.solicitudes_repuesto.latitud_entrega IS 'Snapshot de latitud de entrega al crear la solicitud';
COMMENT ON COLUMN public.solicitudes_repuesto.longitud_entrega IS 'Snapshot de longitud de entrega al crear la solicitud';
COMMENT ON COLUMN public.solicitudes_repuesto.coordenadas_fuente IS 'Origen de las coordenadas snapshot: gps o manual';

-- =========================================================================
-- 3. COTIZACIONES: DISTANCIA REAL Y TIEMPO DE DESPACHO ESTIMADO
-- =========================================================================

ALTER TABLE public.cotizaciones
  ADD COLUMN IF NOT EXISTS distancia_km NUMERIC(8, 1),
  ADD COLUMN IF NOT EXISTS tiempo_despacho_estimado_min INTEGER;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cotizaciones_distancia_no_negativa') THEN
    ALTER TABLE public.cotizaciones
      ADD CONSTRAINT cotizaciones_distancia_no_negativa
        CHECK (distancia_km IS NULL OR distancia_km >= 0);
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'cotizaciones_tiempo_no_negativo') THEN
    ALTER TABLE public.cotizaciones
      ADD CONSTRAINT cotizaciones_tiempo_no_negativo
        CHECK (tiempo_despacho_estimado_min IS NULL OR tiempo_despacho_estimado_min >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.cotizaciones.distancia_km IS 'Distancia real en km entre el almacén y el punto de entrega (Haversine), calculada al crear la cotización';
COMMENT ON COLUMN public.cotizaciones.tiempo_despacho_estimado_min IS 'Tiempo de despacho estimado en minutos (preparación + traslado a velocidad promedio)';
