-- =============================================================================
-- FICHIER : 008_add_subscriptions.sql
-- RÔLE : Migration du modèle économique vers le forfait/abonnement sans commission :
--         - Ajout des colonnes de gestion d'abonnements dans 'technicians'
--         - Création de la table 'technician_subscriptions' (historique des abonnements)
--         - Adaptation des tables 'payments' et 'quotes' (suppression commission 5% / forfait).
-- MODULE : Schéma de base de données / Abonnements & Paiements
-- DÉPENDANCES : public.technicians, public.payments, public.quotes
-- SÉCURITÉ / RLS : Les colonnes d'abonnement conditionnent l'accès aux missions pour les techniciens.
-- =============================================================================

-- Add subscription columns to technicians table
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_type TEXT DEFAULT 'none' CHECK (subscription_type IN ('none', 'monthly', 'yearly', 'trial'));
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_status TEXT DEFAULT 'inactive' CHECK (subscription_status IN ('active', 'inactive', 'expired', 'cancelled'));
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_start_date TIMESTAMP;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_end_date TIMESTAMP;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS trial_start_date TIMESTAMP;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS trial_end_date TIMESTAMP;
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_price_paid NUMERIC(10, 2);
ALTER TABLE technicians ADD COLUMN IF NOT EXISTS subscription_payment_reference TEXT;

-- Create subscription history table
CREATE TABLE IF NOT EXISTS technician_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  technician_id UUID NOT NULL REFERENCES technicians(id) ON DELETE CASCADE,
  subscription_type TEXT NOT NULL CHECK (subscription_type IN ('monthly', 'yearly', 'trial')),
  amount_paid NUMERIC(10, 2),
  period_start TIMESTAMP NOT NULL DEFAULT NOW(),
  period_end TIMESTAMP NOT NULL,
  trial_type TEXT DEFAULT NULL CHECK (trial_type IS NULL OR trial_type = 'free_trial'),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled', 'failed')),
  payment_reference TEXT,
  camerpay_transaction_id TEXT,
  created_at TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
  cancelled_at TIMESTAMP
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_technician_subscriptions_technician_id ON technician_subscriptions(technician_id);
CREATE INDEX IF NOT EXISTS idx_technician_subscriptions_status ON technician_subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_technician_subscriptions_period_end ON technician_subscriptions(period_end);

-- Update payments table to remove 5% commission tracking
ALTER TABLE payments ADD COLUMN IF NOT EXISTS commission_percentage NUMERIC(5, 2) DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS is_mission_payment BOOLEAN DEFAULT TRUE;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS platform_fee NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS technician_amount NUMERIC(10, 2);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS technician_id UUID;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS quote_id UUID;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS payout_status TEXT DEFAULT 'pending';
ALTER TABLE payments ADD COLUMN IF NOT EXISTS camerpay_reference TEXT;
ALTER TABLE payments ADD COLUMN IF NOT EXISTS camerpay_transaction_id TEXT;

-- Keep quote data compatible with the no-commission model
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS commission_rate NUMERIC(5, 2) DEFAULT 0;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS commission_amount NUMERIC(10, 2) DEFAULT 0;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS net_technician NUMERIC(10, 2);

CREATE INDEX IF NOT EXISTS idx_payments_camerpay_reference ON payments(camerpay_reference);
CREATE INDEX IF NOT EXISTS idx_technician_subscriptions_payment_reference ON technician_subscriptions(payment_reference);
