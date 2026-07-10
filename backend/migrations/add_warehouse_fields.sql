-- Migration: Add missing fields to almacenes table
-- Description: Add ruc, representante_legal, telefono, and email fields to almacenes table

-- Add RUC field
ALTER TABLE public.almacenes 
ADD COLUMN IF NOT EXISTS ruc TEXT;

-- Add representante_legal field
ALTER TABLE public.almacenes 
ADD COLUMN IF NOT EXISTS representante_legal TEXT;

-- Add telefono field
ALTER TABLE public.almacenes 
ADD COLUMN IF NOT EXISTS telefono TEXT;

-- Add email field
ALTER TABLE public.almacenes 
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add constraints for the new fields
ALTER TABLE public.almacenes 
ADD CONSTRAINT almacenes_ruc_check CHECK (ruc ~ '^[0-9]{11}$');

ALTER TABLE public.almacenes 
ADD CONSTRAINT almacenes_telefono_check CHECK (telefono ~ '^[0-9]{9,}$');

ALTER TABLE public.almacenes 
ADD CONSTRAINT almacenes_email_check CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$');

-- Add comments for documentation
COMMENT ON COLUMN public.almacenes.ruc IS 'RUC del almacén (11 dígitos)';
COMMENT ON COLUMN public.almacenes.representante_legal IS 'Nombre del representante legal';
COMMENT ON COLUMN public.almacenes.telefono IS 'Número de teléfono de contacto';
COMMENT ON COLUMN public.almacenes.email IS 'Email de contacto del almacén';
