-- Store the city supplied by the address form. Keep it nullable for legacy
-- rows and older app versions.
ALTER TABLE public.direcciones_entrega
  ADD COLUMN IF NOT EXISTS ciudad TEXT;

COMMENT ON COLUMN public.direcciones_entrega.ciudad IS
  'Ciudad indicada por el cliente; usada para identificar y geocodificar la dirección.';
