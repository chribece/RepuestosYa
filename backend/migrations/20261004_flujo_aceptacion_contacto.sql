-- ============================================================================
-- MIGRACIÓN: Flujo de aceptación de cotización con coordinación de entrega
-- ============================================================================
-- 1. Nuevo estado de solicitud 'aceptada': al elegir una cotización la
--    solicitud queda ACEPTADA (antes se marcaba 'asignada'). Es aditivo:
--    no altera filas existentes y nada del código actual depende de
--    'asignada' (solo el RPC viejo la escribía).
-- 2. RPC aceptar_cotizacion reescrito:
--    - idempotente: aceptar la MISMA cotización dos veces devuelve la orden
--      existente sin duplicar (replay seguro);
--    - 409 si otra cotización de la solicitud ya fue aceptada
--      (RAISE con marcador SOLICITUD_YA_ACEPTADA que el servicio mapea);
--    - marca la solicitud como 'aceptada' (misión: solicitud → ACEPTADA);
--    - conserva SECURITY DEFINER (igual que el desplegado) para operar
--      sin fricción con RLS dentro de la transacción.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Estado de solicitud ACEPTADA
-- ----------------------------------------------------------------------------
ALTER TYPE solicitud_status ADD VALUE IF NOT EXISTS 'aceptada';

-- ----------------------------------------------------------------------------
-- 2. RPC aceptar_cotizacion (transacción atómica + idempotencia + conflicto)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.aceptar_cotizacion(
    p_cotizacion_id UUID,
    p_cliente_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
    v_solicitud_id UUID;
    v_almacen_id UUID;
    v_precio_venta NUMERIC;
    v_condicion_repuesto TEXT;
    v_tiempo_entrega_estimado TEXT;
    v_notas_adicionales TEXT;
    v_foto_evidencia_url TEXT;
    v_cliente_id UUID;
    v_estado cotizacion_status;
    v_snapshot JSONB;
    v_nueva_orden_id UUID;
BEGIN
    -- 1. Existencia (sin filtro de estado: habilita el replay idempotente).
    SELECT c.solicitud_id, c.almacen_id, c.precio_venta, c.condicion_repuesto,
           c.tiempo_entrega_estimado, c.notas_adicionales, c.foto_evidencia_url,
           c.estado, s.cliente_id
    INTO v_solicitud_id, v_almacen_id, v_precio_venta, v_condicion_repuesto,
         v_tiempo_entrega_estimado, v_notas_adicionales, v_foto_evidencia_url,
         v_estado, v_cliente_id
    FROM cotizaciones c
    INNER JOIN solicitudes_repuesto s ON c.solicitud_id = s.id
    WHERE c.id = p_cotizacion_id;

    IF v_solicitud_id IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada';
    END IF;

    -- 2. Ownership: solo el dueño de la solicitud puede aceptar.
    IF v_cliente_id != p_cliente_id THEN
        RAISE EXCEPTION 'No tienes permiso para aceptar esta cotización';
    END IF;

    -- 3. Idempotencia: la misma cotización ya aceptada → devolver la orden
    --    existente (no falla, no duplica).
    IF v_estado = 'aceptada' THEN
        SELECT oc.id INTO v_nueva_orden_id
        FROM ordenes_compra oc
        WHERE oc.cotizacion_id = p_cotizacion_id;

        RETURN jsonb_build_object(
            'orden_id', v_nueva_orden_id,
            'solicitud_id', v_solicitud_id,
            'cotizacion_ganadora_id', p_cotizacion_id
        );
    END IF;

    -- 4. Conflicto: otra cotización de la solicitud ya fue aceptada (409).
    IF EXISTS (
        SELECT 1 FROM cotizaciones
        WHERE solicitud_id = v_solicitud_id
          AND estado = 'aceptada'
          AND id != p_cotizacion_id
    ) THEN
        RAISE EXCEPTION 'SOLICITUD_YA_ACEPTADA';
    END IF;

    -- 5. Estado inválido (p. ej. 'rechazada'): la solicitud ya fue decidida.
    IF v_estado != 'pendiente' THEN
        RAISE EXCEPTION 'Cotización no está en estado pendiente';
    END IF;

    -- 6. Snapshot inmutable de la cotización para la orden de compra.
    v_snapshot := jsonb_build_object(
        'cotizacion_id', p_cotizacion_id,
        'precio_venta', v_precio_venta,
        'condicion_repuesto', v_condicion_repuesto,
        'tiempo_entrega_estimado', v_tiempo_entrega_estimado,
        'notas_adicionales', v_notas_adicionales,
        'foto_evidencia_url', v_foto_evidencia_url,
        'almacen_id', v_almacen_id,
        'fecha_aceptacion', NOW()
    );

    -- 7. Transacción atómica: ganadora SELECCIONADA, resto NO_SELECCIONADA,
    --    solicitud ACEPTADA y orden de compra creada.
    UPDATE cotizaciones SET estado = 'aceptada'
    WHERE cotizaciones.id = p_cotizacion_id;

    UPDATE cotizaciones SET estado = 'rechazada'
    WHERE cotizaciones.solicitud_id = v_solicitud_id
      AND cotizaciones.id != p_cotizacion_id
      AND cotizaciones.estado = 'pendiente';

    UPDATE solicitudes_repuesto SET estado = 'aceptada'
    WHERE solicitudes_repuesto.id = v_solicitud_id;

    INSERT INTO ordenes_compra (
        cliente_id, almacen_id, solicitud_id, cotizacion_id, detalles, estado
    ) VALUES (
        p_cliente_id, v_almacen_id, v_solicitud_id, p_cotizacion_id, v_snapshot, 'pendiente'
    )
    RETURNING id INTO v_nueva_orden_id;

    RETURN jsonb_build_object(
        'orden_id', v_nueva_orden_id,
        'solicitud_id', v_solicitud_id,
        'cotizacion_ganadora_id', p_cotizacion_id
    );
END;
$function$;

COMMENT ON FUNCTION public.aceptar_cotizacion IS
'RPC transaccional para aceptar una cotización: idempotente (replay devuelve la orden existente), 409 si otra cotización de la solicitud ya fue aceptada (SOLICITUD_YA_ACEPTADA), marca la solicitud como aceptada y crea la orden de compra con snapshot.';

-- ============================================================================
-- FIN DE MIGRACIÓN
-- ============================================================================
