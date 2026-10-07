-- =============================================================================
-- FICHIER : 027_technician_payment_numbers.sql
-- RÔLE : Ajout des numéros de compte Mobile Money dans la table 'technicians' :
--         - 'mtn_number' (numéro MTN Mobile Money pour les reversements)
--         - 'orange_number' (numéro Orange Money pour les reversements).
-- MODULE : Schéma de base de données / Techniciens & Mobile Money
-- DÉPENDANCES : public.technicians
-- SÉCURITÉ / RLS : Utilisé pour les paiements directs et les demandes de reversement/payout.
-- =============================================================================

-- Add Mobile Money payment fields to technicians table
ALTER TABLE public.technicians
ADD COLUMN IF NOT EXISTS mtn_number TEXT,
ADD COLUMN IF NOT EXISTS orange_number TEXT;
