-- ============================================================================
-- MIGRACIÓN: Catálogo Normalizado de Repuestos y Categorías
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREACIÓN DE TABLAS DEL CATÁLOGO
-- ----------------------------------------------------------------------------

-- Tabla: categorias_repuestos
CREATE TABLE IF NOT EXISTS public.categorias_repuestos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    descripcion TEXT,
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Tabla: repuestos_catalogo
CREATE TABLE IF NOT EXISTS public.repuestos_catalogo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    categoria_id UUID NOT NULL REFERENCES public.categorias_repuestos(id) ON DELETE CASCADE,
    nombre TEXT NOT NULL,
    slug TEXT NOT NULL,
    sinonimos TEXT[] DEFAULT '{}',
    activo BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- 2. ACTUALIZACIÓN DE solicitudes_repuesto
-- ----------------------------------------------------------------------------

ALTER TABLE public.solicitudes_repuesto 
ADD COLUMN IF NOT EXISTS categoria_id UUID REFERENCES public.categorias_repuestos(id),
ADD COLUMN IF NOT EXISTS repuesto_id UUID REFERENCES public.repuestos_catalogo(id),
ADD COLUMN IF NOT EXISTS repuesto_nombre_snapshot TEXT,
ADD COLUMN IF NOT EXISTS descripcion_problema TEXT;

-- ----------------------------------------------------------------------------
-- 3. POLÍTICAS RLS (Row Level Security)
-- ----------------------------------------------------------------------------

ALTER TABLE public.categorias_repuestos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.repuestos_catalogo ENABLE ROW LEVEL SECURITY;

-- Catálogo es legible por todos los usuarios autenticados
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Usuarios autenticados pueden ver categorías') THEN
        CREATE POLICY "Usuarios autenticados pueden ver categorías" ON public.categorias_repuestos
            FOR SELECT TO authenticated USING (activo = true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Usuarios autenticados pueden ver catálogo de repuestos') THEN
        CREATE POLICY "Usuarios autenticados pueden ver catálogo de repuestos" ON public.repuestos_catalogo
            FOR SELECT TO authenticated USING (activo = true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service role puede gestionar categorías') THEN
        CREATE POLICY "Service role puede gestionar categorías" ON public.categorias_repuestos
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'Service role puede gestionar catálogo de repuestos') THEN
        CREATE POLICY "Service role puede gestionar catálogo de repuestos" ON public.repuestos_catalogo
            FOR ALL TO service_role USING (true) WITH CHECK (true);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 4. SEED INICIAL (CATEGORÍAS Y REPUESTOS)
-- ----------------------------------------------------------------------------

DO $$
DECLARE
    cat_frenos UUID;
    cat_motor UUID;
    cat_suspension UUID;
    cat_transmision UUID;
    cat_electrico UUID;
    cat_carroceria UUID;
    cat_lubricantes UUID;
    cat_filtros UUID;
BEGIN
    -- Insertar Categorías
    INSERT INTO public.categorias_repuestos (nombre, slug) VALUES 
    ('Frenos', 'frenos'),
    ('Motor', 'motor'),
    ('Suspensión', 'suspension'),
    ('Transmisión', 'transmision'),
    ('Eléctrico', 'electrico'),
    ('Carrocería', 'carroceria'),
    ('Lubricantes y Fluidos', 'lubricantes-fluidos'),
    ('Filtros', 'filtros')
    ON CONFLICT (slug) DO UPDATE SET nombre = EXCLUDED.nombre;

    -- Obtener IDs
    SELECT id INTO cat_frenos FROM public.categorias_repuestos WHERE slug = 'frenos';
    SELECT id INTO cat_motor FROM public.categorias_repuestos WHERE slug = 'motor';
    SELECT id INTO cat_suspension FROM public.categorias_repuestos WHERE slug = 'suspension';
    SELECT id INTO cat_transmision FROM public.categorias_repuestos WHERE slug = 'transmision';
    SELECT id INTO cat_electrico FROM public.categorias_repuestos WHERE slug = 'electrico';
    SELECT id INTO cat_carroceria FROM public.categorias_repuestos WHERE slug = 'carroceria';
    SELECT id INTO cat_lubricantes FROM public.categorias_repuestos WHERE slug = 'lubricantes-fluidos';
    SELECT id INTO cat_filtros FROM public.categorias_repuestos WHERE slug = 'filtros';

    -- Insertar Repuestos: Frenos
    INSERT INTO public.repuestos_catalogo (categoria_id, nombre, slug, sinonimos) VALUES
    (cat_frenos, 'Pastillas de freno', 'pastillas-freno', '{pastilla,balata,frenado}'),
    (cat_frenos, 'Discos de freno', 'discos-freno', '{disco,rotores}'),
    (cat_frenos, 'Líquido de freno', 'liquido-freno', '{fluido frenos,dot3,dot4}'),
    (cat_frenos, 'Bomba de freno', 'bomba-freno', '{cilindro maestro}')
    ON CONFLICT DO NOTHING;

    -- Insertar Repuestos: Lubricantes y Fluidos
    INSERT INTO public.repuestos_catalogo (categoria_id, nombre, slug, sinonimos) VALUES
    (cat_lubricantes, 'Aceite de motor', 'aceite-motor', '{lubricante,10w40,5w30}'),
    (cat_lubricantes, 'Refrigerante', 'refrigerante', '{anticongelante,coolant}'),
    (cat_lubricantes, 'Líquido hidráulico', 'liquido-hidraulico', '{aceite direccion,atf}')
    ON CONFLICT DO NOTHING;

    -- Insertar Repuestos: Filtros
    INSERT INTO public.repuestos_catalogo (categoria_id, nombre, slug, sinonimos) VALUES
    (cat_filtros, 'Filtro de aceite', 'filtro-aceite', '{elemento aceite}'),
    (cat_filtros, 'Filtro de aire', 'filtro-aire', '{elemento aire}'),
    (cat_filtros, 'Filtro de combustible', 'filtro-combustible', '{filtro bencina,filtro diesel}')
    ON CONFLICT DO NOTHING;

    -- Insertar Repuestos: Motor
    INSERT INTO public.repuestos_catalogo (categoria_id, nombre, slug, sinonimos) VALUES
    (cat_motor, 'Bujías', 'bujias', '{candela,spark plug}'),
    (cat_motor, 'Correa de distribución', 'correa-distribucion', '{banda tiempo,kit distribucion}'),
    (cat_motor, 'Bomba de agua', 'bomba-agua', '{enfriamiento}')
    ON CONFLICT DO NOTHING;

    -- Insertar Repuestos: Eléctrico
    INSERT INTO public.repuestos_catalogo (categoria_id, nombre, slug, sinonimos) VALUES
    (cat_electrico, 'Batería', 'bateria', '{acumulador}'),
    (cat_electrico, 'Alternador', 'alternador', '{generador}'),
    (cat_electrico, 'Motor de arranque', 'motor-arranque', '{partida,burro}')
    ON CONFLICT DO NOTHING;

END $$;

-- ----------------------------------------------------------------------------
-- FIN DE MIGRACIÓN
-- ----------------------------------------------------------------------------
