-- Migration: Update direcciones_entrega table structure
-- Description: Change from GPS-based structure to address-based structure

-- First, backup existing data if needed
-- CREATE TABLE direcciones_entrega_backup AS SELECT * FROM direcciones_entrega;

-- Drop old table and recreate with new structure
DROP TABLE IF EXISTS public.direcciones_entrega CASCADE;

-- Create table with new structure
CREATE TABLE public.direcciones_entrega (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    cliente_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    alias TEXT NOT NULL,
    calle_principal TEXT NOT NULL,
    calle_secundaria TEXT,
    referencia TEXT,
    es_principal BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc'::TEXT, NOW()) NOT NULL
);

-- Enable RLS
ALTER TABLE public.direcciones_entrega ENABLE ROW LEVEL SECURITY;

-- Create RLS policies
-- Policy: Allow service role to do anything
CREATE POLICY "Service role can do anything on direcciones" ON public.direcciones_entrega
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Authenticated users can view their own addresses
CREATE POLICY "Users can view own direcciones" ON public.direcciones_entrega
  FOR SELECT
  TO authenticated
  USING (cliente_id = auth.uid());

-- Policy: Authenticated users can insert their own addresses
CREATE POLICY "Users can insert own direcciones" ON public.direcciones_entrega
  FOR INSERT
  TO authenticated
  WITH CHECK (cliente_id = auth.uid());

-- Policy: Authenticated users can update their own addresses
CREATE POLICY "Users can update own direcciones" ON public.direcciones_entrega
  FOR UPDATE
  TO authenticated
  USING (cliente_id = auth.uid())
  WITH CHECK (cliente_id = auth.uid());

-- Policy: Authenticated users can delete their own addresses
CREATE POLICY "Users can delete own direcciones" ON public.direcciones_entrega
  FOR DELETE
  TO authenticated
  USING (cliente_id = auth.uid());

-- Create index for performance
CREATE INDEX idx_direcciones_cliente_id ON public.direcciones_entrega(cliente_id);
CREATE INDEX idx_direcciones_es_principal ON public.direcciones_entrega(es_principal);

-- Add trigger for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::TEXT, NOW());
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_direcciones_entrega_updated_at 
    BEFORE UPDATE ON public.direcciones_entrega 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Add comment
COMMENT ON TABLE public.direcciones_entrega IS 'Direcciones de entrega para clientes con estructura basada en calles en lugar de coordenadas GPS';
