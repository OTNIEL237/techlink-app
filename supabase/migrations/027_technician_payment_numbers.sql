-- Add Mobile Money payment fields to technicians table
ALTER TABLE public.technicians
ADD COLUMN IF NOT EXISTS mtn_number TEXT,
ADD COLUMN IF NOT EXISTS orange_number TEXT;
