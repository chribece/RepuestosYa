-- Migration: Fix RLS policies for solicitudes_repuesto table
-- Description: Allow service role to insert/update/delete solicitudes and clients to manage their own

-- Drop existing restrictive policies if they block service role
DROP POLICY IF EXISTS "Users can insert their own solicitudes" ON public.solicitudes_repuesto;
DROP POLICY IF EXISTS "Users can view their own solicitudes" ON public.solicitudes_repuesto;
DROP POLICY IF EXISTS "Users can update their own solicitudes" ON public.solicitudes_repuesto;
DROP POLICY IF EXISTS "Users can delete their own solicitudes" ON public.solicitudes_repuesto;

-- Create new RLS policies that are more permissive for the backend

-- Policy: Allow service role to do anything
CREATE POLICY "Service role can do anything on solicitudes" ON public.solicitudes_repuesto
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Policy: Authenticated users can view their own solicitudes
CREATE POLICY "Users can view own solicitudes" ON public.solicitudes_repuesto
  FOR SELECT
  TO authenticated
  USING (cliente_id = auth.uid());

-- Policy: Authenticated users can insert their own solicitudes
CREATE POLICY "Users can insert own solicitudes" ON public.solicitudes_repuesto
  FOR INSERT
  TO authenticated
  WITH CHECK (cliente_id = auth.uid());

-- Policy: Authenticated users can update their own solicitudes
CREATE POLICY "Users can update own solicitudes" ON public.solicitudes_repuesto
  FOR UPDATE
  TO authenticated
  USING (cliente_id = auth.uid())
  WITH CHECK (cliente_id = auth.uid());

-- Policy: Authenticated users can delete their own solicitudes
CREATE POLICY "Users can delete own solicitudes" ON public.solicitudes_repuesto
  FOR DELETE
  TO authenticated
  USING (cliente_id = auth.uid());

-- Policy: Warehouses can view active solicitudes
CREATE POLICY "Warehouses can view active solicitudes" ON public.solicitudes_repuesto
  FOR SELECT
  TO authenticated
  USING (
    estado = 'en_proceso' AND
    EXISTS (
      SELECT 1 FROM public.almacenes 
      WHERE almacenes.encargado_id = auth.uid()
    )
  );

-- Note: The service_role has full access to bypass RLS
-- The backend should use service_role key for admin operations
