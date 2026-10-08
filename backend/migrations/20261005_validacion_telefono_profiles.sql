-- ============================================================================
-- MIGRACIÓN: validación coherente del teléfono en profiles
-- ============================================================================
-- El backend ahora normaliza el teléfono a DÍGITOS antes de persistir
-- (src/utils/phone.js), igual que el CHECK ya existente en `almacenes`
-- (^[0-9]{9,}$). Este CHECK garantiza que `profiles.telefono` tenga el mismo
-- formato mínimo (solo dígitos, 9+); el techo de 15 dígitos (E.164) lo
-- validan el backend y el frontend (formularios con 9-15 dígitos).
-- ============================================================================

-- 1. Limpiar teléfonos vacíos ('' → NULL): un string vacío no es un teléfono
--    y violaría el CHECK nuevo. No hay datos perdidos: '' equivale a "sin
--    teléfono".
UPDATE profiles SET telefono = NULL WHERE telefono = '';

-- 2. CHECK con guard IF NOT EXISTS (PostgreSQL no soporta
--    ADD CONSTRAINT IF NOT EXISTS; patrón del proyecto).
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'profiles_telefono_check'
    ) THEN
        ALTER TABLE profiles
            ADD CONSTRAINT profiles_telefono_check
            CHECK (telefono IS NULL OR telefono ~ '^[0-9]{9,}$');
    END IF;
END $$;

-- ============================================================================
-- FIN DE MIGRACIÓN
-- ============================================================================
