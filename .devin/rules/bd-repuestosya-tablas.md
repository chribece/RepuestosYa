-- =========================================================================
-- 1. ELIMINACIÓN DE TABLAS Y TIPOS PREVIOS (PARA REINSTALACIÓN LIMPIA)
-- =========================================================================

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();
DROP FUNCTION IF EXISTS public.calcular_distancia(NUMERIC, NUMERIC, NUMERIC, NUMERIC);
DROP FUNCTION IF EXISTS public.get_user_role();

DROP TABLE IF EXISTS public.cotizaciones CASCADE;
DROP TABLE IF EXISTS public.solicitudes_repuesto CASCADE;
DROP TABLE IF EXISTS public.almacenes CASCADE;
DROP TABLE IF EXISTS public.direcciones_entrega CASCADE;
DROP TABLE IF EXISTS public.vehiculos_cliente CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;
DROP TABLE IF EXISTS public.modelos_vehiculo CASCADE;
DROP TABLE IF EXISTS public.marcas_vehiculo CASCADE;

DROP TYPE IF EXISTS user_role CASCADE;
DROP TYPE IF EXISTS solicitud_status CASCADE;
DROP TYPE IF EXISTS cotizacion_status CASCADE;
DROP TYPE IF EXISTS estado_repuesto CASCADE;

-- =========================================================================
-- 2. CREACIÓN DE TIPOS ENUMERADOS (ENUMS)
-- =========================================================================

CREATE TYPE user_role AS ENUM ('admin', 'cliente', 'almacen');
CREATE TYPE solicitud_status AS ENUM ('en_proceso', 'completado', 'expirado');
CREATE TYPE cotizacion_status AS ENUM ('pendiente', 'aceptada', 'rechazada');
CREATE TYPE estado_repuesto AS ENUM ('Nuevo (En caja original)', 'Nuevo (Abierto)', 'Usado (Buen estado)');

-- =========================================================================
-- 3. TABLAS MAESTRAS (CATÁLOGOS EN 3FN)
-- =========================================================================

-- Catálogo de Marcas de Vehículos
CREATE TABLE public.marcas_vehiculo (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre TEXT UNIQUE NOT NULL
);

-- Catálogo de Modelos (Garantiza la dependencia directa de la Marca)
CREATE TABLE public.modelos_vehiculo (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    marca_id INT REFERENCES public.marcas_vehiculo(id) ON DELETE CASCADE NOT NULL,
    nombre TEXT NOT NULL,
    UNIQUE(marca_id, nombre)
);

-- =========================================================================
-- 4. TABLAS PRINCIPALES DEL SISTEMA
-- =========================================================================

-- Perfiles de usuario (Espejo de auth.users de Supabase)
CREATE TABLE public.profiles (
    id UUID REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
    nombre_completo TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    telefono TEXT,
    rol user_role DEFAULT 'cliente'::user_role,
    tipo_membresia TEXT DEFAULT 'Regular Member',
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Vehículos vinculados a los clientes (3FN - Usa el modelo_id)
CREATE TABLE public.vehiculos_cliente (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    modelo_id INT REFERENCES public.modelos_vehiculo(id) ON DELETE RESTRICT NOT NULL,
    anio INT NOT NULL,
    vin TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Direcciones de entrega para los Clientes
CREATE TABLE public.direcciones_entrega (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    nombre_ubicacion TEXT NOT NULL,
    direccion_texto TEXT NOT NULL,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Almacenes / Tiendas de Repuestos registrados
CREATE TABLE public.almacenes (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    encargado_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    nombre_comercial TEXT NOT NULL,
    direccion_texto TEXT NOT NULL,
    latitude NUMERIC(10, 8) NOT NULL,
    longitude NUMERIC(11, 8) NOT NULL,
    verificado BOOLEAN DEFAULT FALSE,
    estado_abierto BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Solicitudes de repuestos creadas por Clientes
CREATE TABLE public.solicitudes_repuesto (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    vehiculo_id UUID REFERENCES public.vehiculos_cliente(id) ON DELETE SET NULL,
    pieza_nombre TEXT NOT NULL,
    descripcion TEXT,
    foto_url TEXT,
    vin_busqueda TEXT,
    direccion_entrega_id UUID REFERENCES public.direcciones_entrega(id) ON DELETE SET NULL,
    estado solicitud_status DEFAULT 'en_proceso'::solicitud_status,
    es_urgente BOOLEAN DEFAULT FALSE,
    vistas_contador INT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Cotizaciones enviadas por los Almacenes
CREATE TABLE public.cotizaciones (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    solicitud_id UUID REFERENCES public.solicitudes_repuesto(id) ON DELETE CASCADE NOT NULL,
    almacen_id UUID REFERENCES public.almacenes(id) ON DELETE CASCADE NOT NULL,
    precio_venta NUMERIC(10, 2) NOT NULL,
    comision_plataforma NUMERIC(10, 2) GENERATED ALWAYS AS (precio_venta * 0.05) STORED,
    condicion_repuesto estado_repuesto DEFAULT 'Nuevo (En caja original)'::estado_repuesto,
    foto_evidencia_url TEXT,
    notas_adicionales TEXT,
    tiempo_entrega_estimado TEXT NOT NULL,
    estado cotizacion_status DEFAULT 'pendiente'::cotizacion_status,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- =========================================================================
-- 5. AUTOMATIZACIÓN DE PERFILES (TRIGGER PARA AUTH.USERS)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, nombre_completo, email, rol, tipo_membresia)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'nombre_completo', 'Usuario Nuevo'),
        NEW.email,
        'cliente'::user_role,
        'Regular Member'
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =========================================================================
-- 6. GEOLOCALIZACIÓN: FUNCIÓN PARA CALCULAR DISTANCIA EN KM
-- =========================================================================

CREATE OR REPLACE FUNCTION public.calcular_distancia(
    lat1 NUMERIC, lon1 NUMERIC,
    lat2 NUMERIC, lon2 NUMERIC
)
RETURNS NUMERIC AS $$
DECLARE
    p_radius NUMERIC := 6371;
    dLat NUMERIC;
    dLon NUMERIC;
    a NUMERIC;
    c NUMERIC;
BEGIN
    dLat := radians(lat2 - lat1);
    dLon := radians(lon2 - lon1);
    a := sin(dLat/2) * sin(dLat/2) +
         cos(radians(lat1)) * cos(radians(lat2)) * sin(dLon/2) * sin(dLon/2);
    c := 2 * atan2(sqrt(a), sqrt(1-a));
    RETURN ROUND((p_radius * c)::NUMERIC, 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- =========================================================================
-- 7. ACTIVACIÓN DE RLS (ROW LEVEL SECURITY)
-- =========================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vehiculos_cliente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direcciones_entrega ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.almacenes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.solicitudes_repuesto ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cotizaciones ENABLE ROW LEVEL SECURITY;

-- =========================================================================
-- 8. FUNCIÓN AUXILIAR DE SEGURIDAD (Evita bucles recursivos en RLS)
-- =========================================================================

CREATE OR REPLACE FUNCTION public.get_user_role()
RETURNS user_role AS $$
    SELECT rol FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER;

-- =========================================================================
-- 9. REGLAS PARA LA TABLA: PROFILES
-- =========================================================================

CREATE POLICY "Permitir lectura pública de perfiles"
    ON public.profiles FOR SELECT TO authenticated USING (true);

CREATE POLICY "Usuarios pueden actualizar su propio perfil"
    ON public.profiles FOR UPDATE TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- =========================================================================
-- 10. REGLAS PARA: VEHÍCULOS Y DIRECCIONES
-- =========================================================================

CREATE POLICY "Clientes gestionan sus propios vehículos"
    ON public.vehiculos_cliente FOR ALL TO authenticated
    USING (auth.uid() = cliente_id)
    WITH CHECK (auth.uid() = cliente_id);

CREATE POLICY "Clientes gestionan sus propias direcciones"
    ON public.direcciones_entrega FOR ALL TO authenticated
    USING (auth.uid() = cliente_id)
    WITH CHECK (auth.uid() = cliente_id);

-- =========================================================================
-- 11. REGLAS PARA LA TABLA: ALMACENES (NUEVAS POLÍTICAS AGREGADAS)
-- =========================================================================

-- 11.1. Cualquier usuario autenticado puede ver los almacenes (mapa y cotizaciones)
CREATE POLICY "Usuarios autenticados pueden ver almacenes"
    ON public.almacenes FOR SELECT TO authenticated
    USING (true);

-- 11.2. Un almacén puede actualizar su propio perfil comercial
CREATE POLICY "Almacenes pueden actualizar su propio perfil"
    ON public.almacenes FOR UPDATE TO authenticated
    USING (encargado_id = auth.uid())
    WITH CHECK (encargado_id = auth.uid());

-- 11.3. Un almacén puede crear su propio registro (flujo de registro de tienda)
CREATE POLICY "Almacenes pueden crear su propio perfil"
    ON public.almacenes FOR INSERT TO authenticated
    WITH CHECK (encargado_id = auth.uid());

-- =========================================================================
-- 12. REGLAS PARA LA TABLA: SOLICITUDES DE REPUESTO
-- =========================================================================

-- Cliente: control total de sus solicitudes
CREATE POLICY "Clientes controlan sus solicitudes"
    ON public.solicitudes_repuesto FOR ALL TO authenticated
    USING (auth.uid() = cliente_id)
    WITH CHECK (auth.uid() = cliente_id);

-- Almacén: solo puede ver solicitudes activas (en_proceso)
CREATE POLICY "Almacenes pueden ver solicitudes activas"
    ON public.solicitudes_repuesto FOR SELECT TO authenticated
    USING (
        public.get_user_role() = 'almacen'::user_role
        AND estado = 'en_proceso'::solicitud_status
    );

-- =========================================================================
-- 13. REGLAS PARA LA TABLA: COTIZACIONES
-- =========================================================================

-- Almacén: gestiona sus propias cotizaciones enviadas
CREATE POLICY "Almacenes gestionan sus propias cotizaciones"
    ON public.cotizaciones FOR ALL TO authenticated
    USING (
        almacen_id IN (SELECT id FROM public.almacenes WHERE encargado_id = auth.uid())
    )
    WITH CHECK (
        almacen_id IN (SELECT id FROM public.almacenes WHERE encargado_id = auth.uid())
    );

-- Cliente: puede ver las cotizaciones recibidas en sus solicitudes
CREATE POLICY "Clientes pueden ver cotizaciones recibidas"
    ON public.cotizaciones FOR SELECT TO authenticated
    USING (
        solicitud_id IN (SELECT id FROM public.solicitudes_repuesto WHERE cliente_id = auth.uid())
    );

-- =========================================================================
-- 14. REGLAS GLOBALES PARA EL ROL: ADMIN
-- =========================================================================

CREATE POLICY "Admin tiene control total de perfiles" ON public.profiles FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);
CREATE POLICY "Admin tiene control total de vehículos" ON public.vehiculos_cliente FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);
CREATE POLICY "Admin tiene control total de direcciones" ON public.direcciones_entrega FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);
CREATE POLICY "Admin tiene control total de almacenes" ON public.almacenes FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);
CREATE POLICY "Admin tiene control total de solicitudes" ON public.solicitudes_repuesto FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);
CREATE POLICY "Admin tiene control total de cotizaciones" ON public.cotizaciones FOR ALL TO authenticated USING (public.get_user_role() = 'admin'::user_role);

-- =========================================================================
-- 15. REGLAS DE VALIDACIÓN DE NEGOCIO (CONSTRAINTS)
-- =========================================================================

-- Precio de venta debe ser positivo
ALTER TABLE public.cotizaciones
    ADD CONSTRAINT check_precio_positivo CHECK (precio_venta > 0);

-- Validación de coordenadas geográficas en direcciones de entrega
ALTER TABLE public.direcciones_entrega
    ADD CONSTRAINT check_lat_valida CHECK (latitude BETWEEN -90 AND 90),
    ADD CONSTRAINT check_lon_valida CHECK (longitude BETWEEN -180 AND 180);