-- ============================================================================
-- MIGRACIÓN: Sistema de Órdenes de Compra y Flujo de Cotizaciones
-- ============================================================================
-- Este script añade funcionalidad para aceptar/rechazar cotizaciones y crear
-- órdenes de compra de forma transaccional.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VERIFICACIÓN SEGURA DE ENUMS EXISTENTES
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- Verificar que los enums base existen antes de modificarlos
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cotizacion_status') THEN
        RAISE EXCEPTION 'El enum cotizacion_status no existe. Ejecuta primero la migración base.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'solicitud_status') THEN
        RAISE EXCEPTION 'El enum solicitud_status no existe. Ejecuta primero la migración base.';
    END IF;
    
    RAISE NOTICE 'Enums base verificados exitosamente.';
END $$;

-- ----------------------------------------------------------------------------
-- 2. AMPLIACIÓN DE ENUMS (USANDO IF NOT EXISTS PARA EVITAR ERRORES)
-- ----------------------------------------------------------------------------

-- Ampliar cotizacion_status con 'aceptada' y 'rechazada' si no existen
DO $$
BEGIN
    -- Verificar si 'aceptada' ya existe en cotizacion_status
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'aceptada' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'cotizacion_status')
    ) THEN
        ALTER TYPE cotizacion_status ADD VALUE 'aceptada';
        RAISE NOTICE 'Valor "aceptada" añadido a cotizacion_status.';
    ELSE
        RAISE NOTICE 'Valor "aceptada" ya existe en cotizacion_status.';
    END IF;
    
    -- Verificar si 'rechazada' ya existe en cotizacion_status
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'rechazada' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'cotizacion_status')
    ) THEN
        ALTER TYPE cotizacion_status ADD VALUE 'rechazada';
        RAISE NOTICE 'Valor "rechazada" añadido a cotizacion_status.';
    ELSE
        RAISE NOTICE 'Valor "rechazada" ya existe en cotizacion_status.';
    END IF;
END $$;

-- Ampliar solicitud_status con 'asignada' y 'cerrada' si no existen
DO $$
BEGIN
    -- Verificar si 'asignada' ya existe en solicitud_status
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'asignada' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'solicitud_status')
    ) THEN
        ALTER TYPE solicitud_status ADD VALUE 'asignada';
        RAISE NOTICE 'Valor "asignada" añadido a solicitud_status.';
    ELSE
        RAISE NOTICE 'Valor "asignada" ya existe en solicitud_status.';
    END IF;
    
    -- Verificar si 'cerrada' ya existe en solicitud_status
    IF NOT EXISTS (
        SELECT 1 
        FROM pg_enum 
        WHERE enumlabel = 'cerrada' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'solicitud_status')
    ) THEN
        ALTER TYPE solicitud_status ADD VALUE 'cerrada';
        RAISE NOTICE 'Valor "cerrada" añadido a solicitud_status.';
    ELSE
        RAISE NOTICE 'Valor "cerrada" ya existe en solicitud_status.';
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 3. CREACIÓN DE TABLA ordenes_compra
-- ----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ordenes_compra (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cliente_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    almacen_id UUID NOT NULL REFERENCES almacenes(id) ON DELETE CASCADE,
    solicitud_id UUID NOT NULL REFERENCES solicitudes_repuesto(id) ON DELETE CASCADE,
    cotizacion_id UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
    
    -- Snapshot de la cotización en el momento de aceptación (JSONB inmutable)
    detalles JSONB NOT NULL,
    
    -- Estado de la orden de compra
    estado orden_compra_status NOT NULL DEFAULT 'pendiente',
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Restricción de unicidad: una orden por cotización
    CONSTRAINT uc_orden_cotizacion UNIQUE (cotizacion_id)
);

-- ----------------------------------------------------------------------------
-- 4. ÍNDICES PARA ordenes_compra
-- ----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_ordenes_cliente ON ordenes_compra(cliente_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_almacen ON ordenes_compra(almacen_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_solicitud ON ordenes_compra(solicitud_id);
CREATE INDEX IF NOT EXISTS idx_ordenes_estado ON ordenes_compra(estado);
CREATE INDEX IF NOT EXISTS idx_ordenes_created_at ON ordenes_compra(created_at DESC);

-- Trigger para updated_at
CREATE OR REPLACE FUNCTION update_ordenes_compra_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_ordenes_compra_updated_at ON ordenes_compra;
CREATE TRIGGER trigger_update_ordenes_compra_updated_at
    BEFORE UPDATE ON ordenes_compra
    FOR EACH ROW
    EXECUTE FUNCTION update_ordenes_compra_updated_at();

-- ----------------------------------------------------------------------------
-- 5. ROW LEVEL SECURITY (RLS) PARA ordenes_compra
-- ----------------------------------------------------------------------------
ALTER TABLE ordenes_compra ENABLE ROW LEVEL SECURITY;

-- Política: Los clientes pueden ver sus propias órdenes
CREATE POLICY clientes_ven_sus_ordenes ON ordenes_compra
    FOR SELECT
    USING (
        cliente_id = auth.uid()
    );

-- Política: Los almacenes pueden ver las órdenes donde participan
CREATE POLICY almacenes_ven_sus_ordenes ON ordenes_compra
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 
            FROM almacenes 
            WHERE almacenes.id = ordenes_compra.almacen_id 
            AND almacenes.encargado_id = auth.uid()
        )
    );

-- Política: El servicio (backend con service role) puede insertar órdenes
CREATE POLICY servicio_puede_insertar ON ordenes_compra
    FOR INSERT
    WITH CHECK (true);

-- Política: El servicio puede actualizar órdenes
CREATE POLICY servicio_puede_actualizar ON ordenes_compra
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 6. FUNCIÓN RPC aceptar_cotización (TRANSACCIÓN ATÓMICA)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION aceptar_cotizacion(
    p_cotizacion_id UUID,
    p_cliente_id UUID
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_solicitud_id UUID;
    v_almacen_id UUID;
    v_precio_venta NUMERIC;
    v_condicion_repuesto TEXT;
    v_tiempo_entrega_estimado TEXT;
    v_notas_adicionales TEXT;
    v_foto_evidencia_url TEXT;
    v_snapshot JSONB;
    v_nueva_orden_id UUID;
BEGIN
    -- -------------------------------------------------------------------------
    -- VALIDACIONES
    -- -------------------------------------------------------------------------
    
    -- 1. Verificar que la cotización existe y está en estado 'pendiente'
    IF NOT EXISTS (
        SELECT 1 
        FROM cotizaciones 
        WHERE id = p_cotizacion_id 
        AND estado = 'pendiente'
    ) THEN
        RAISE EXCEPTION 'Cotización no encontrada o no está en estado pendiente';
    END IF;
    
    -- 2. Obtener datos de la cotización y verificar propiedad de la solicitud
    SELECT 
        c.solicitud_id,
        c.almacen_id,
        c.precio_venta,
        c.condicion_repuesto,
        c.tiempo_entrega_estimado,
        c.notas_adicionales,
        c.foto_evidencia_url,
        s.cliente_id
    INTO 
        v_solicitud_id,
        v_almacen_id,
        v_precio_venta,
        v_condicion_repuesto,
        v_tiempo_entrega_estimado,
        v_notas_adicionales,
        v_foto_evidencia_url,
        v_cliente_id
    FROM cotizaciones c
    INNER JOIN solicitudes_repuesto s ON c.solicitud_id = s.id
    WHERE c.id = p_cotizacion_id;
    
    -- 3. Verificar que el cliente autenticado es el dueño de la solicitud
    IF v_cliente_id != p_cliente_id THEN
        RAISE EXCEPTION 'No tienes permiso para aceptar esta cotización';
    END IF;
    
    -- -------------------------------------------------------------------------
    -- CONSTRUIR SNAPSHOT DE LA COTIZACIÓN
    -- -------------------------------------------------------------------------
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
    
    -- -------------------------------------------------------------------------
    -- TRANSACCIÓN ATÓMICA
    -- -------------------------------------------------------------------------
    
    -- 1. Marcar la cotización ganadora como 'aceptada'
    UPDATE cotizaciones
    SET estado = 'aceptada'
    WHERE id = p_cotizacion_id;
    
    -- 2. Marcar todas las demás cotizaciones de la solicitud como 'rechazada'
    UPDATE cotizaciones
    SET estado = 'rechazada'
    WHERE solicitud_id = v_solicitud_id
    AND id != p_cotizacion_id
    AND estado = 'pendiente';
    
    -- 3. Actualizar el estado de la solicitud a 'asignada'
    UPDATE solicitudes_repuesto
    SET estado = 'asignada'
    WHERE id = v_solicitud_id;
    
    -- 4. Crear la orden de compra con el snapshot
    INSERT INTO ordenes_compra (
        cliente_id,
        almacen_id,
        solicitud_id,
        cotizacion_id,
        detalles,
        estado
    ) VALUES (
        p_cliente_id,
        v_almacen_id,
        v_solicitud_id,
        p_cotizacion_id,
        v_snapshot,
        'pendiente'
    )
    RETURNING id INTO v_nueva_orden_id;
    
    -- -------------------------------------------------------------------------
    -- RETORNAR RESULTADO COMO JSONB
    -- -------------------------------------------------------------------------
    RETURN jsonb_build_object(
        'orden_id', v_nueva_orden_id,
        'solicitud_id', v_solicitud_id,
        'cotizacion_ganadora_id', p_cotizacion_id
    );

END;
$$;

-- ----------------------------------------------------------------------------
-- 7. COMENTARIOS DOCUMENTACIÓN
-- ----------------------------------------------------------------------------
COMMENT ON TABLE ordenes_compra IS 'Tabla de órdenes de compra generadas al aceptar una cotización';
COMMENT ON COLUMN ordenes_compra.detalles IS 'Snapshot inmutable de la cotización en el momento de aceptación (JSONB)';
COMMENT ON FUNCTION aceptar_cotizacion IS 'Función RPC transaccional para aceptar una cotización: actualiza cotizaciones, solicitud y crea orden de compra en una sola transacción';

-- ----------------------------------------------------------------------------
-- FIN DE MIGRACIÓN
-- ----------------------------------------------------------------------------
