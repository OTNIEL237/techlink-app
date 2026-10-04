-- Migration to add 'in_dispute' status to missions table
DO $$ 
BEGIN
  -- Drop the existing check constraint on the status column if it exists
  -- Note: Depending on how the table was created, the constraint might be named differently.
  -- We'll try a generic approach or drop specific known names.
  
  -- Supabase often names it missions_status_check
  BEGIN
    ALTER TABLE public.missions DROP CONSTRAINT IF EXISTS missions_status_check;
  EXCEPTION
    WHEN undefined_object THEN null;
  END;

  -- Add the new constraint with 'in_dispute'
  ALTER TABLE public.missions 
  ADD CONSTRAINT missions_status_check 
  CHECK (status IN ('searching', 'pending', 'accepted', 'technician_enroute', 'in_progress', 'quote_sent', 'quote_accepted', 'payment_pending', 'paid', 'completed', 'cancelled', 'in_dispute', 'cancelled_refunded'));

END $$;
