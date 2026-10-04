-- ============================================================================
-- 030_missing_indexes.sql
-- Index de performance pour les colonnes fréquemment filtrées
-- À exécuter dans la console SQL du dashboard Supabase
-- ============================================================================
-- Ces index accélèrent les sous-requêtes utilisées dans les politiques RLS
-- et les requêtes courantes de l'application.
-- ============================================================================


-- ─── Payments ────────────────────────────────────────────────────────────────
-- Utilisé par les policies RLS payments_select_client/technician
-- et les requêtes du backend (GET /api/payments/client/:clientId)
CREATE INDEX IF NOT EXISTS idx_payments_client_id
ON public.payments(client_id);

CREATE INDEX IF NOT EXISTS idx_payments_technician_id
ON public.payments(technician_id);

CREATE INDEX IF NOT EXISTS idx_payments_mission_id
ON public.payments(mission_id);

CREATE INDEX IF NOT EXISTS idx_payments_status
ON public.payments(status);

-- Lookup par référence CamerPay (vérification de paiement)
CREATE INDEX IF NOT EXISTS idx_payments_camerpay_reference
ON public.payments(camerpay_reference);


-- ─── Wallet Transactions ─────────────────────────────────────────────────────
-- Utilisé par la policy RLS wallet_tx_select_own
CREATE INDEX IF NOT EXISTS idx_wallet_tx_technician_id
ON public.wallet_transactions(technician_id);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_mission_id
ON public.wallet_transactions(mission_id);

CREATE INDEX IF NOT EXISTS idx_wallet_tx_created_at
ON public.wallet_transactions(created_at DESC);


-- ─── Calls ───────────────────────────────────────────────────────────────────
-- Utilisé par les policies RLS calls_select/update_participant
CREATE INDEX IF NOT EXISTS idx_calls_caller_id
ON public.calls(caller_id);

CREATE INDEX IF NOT EXISTS idx_calls_receiver_id
ON public.calls(receiver_id);

CREATE INDEX IF NOT EXISTS idx_calls_status
ON public.calls(status);


-- ─── Mission Requests ────────────────────────────────────────────────────────
-- Utilisé par les policies RLS mission_requests_select_*
CREATE INDEX IF NOT EXISTS idx_mission_requests_mission_id
ON public.mission_requests(mission_id);

CREATE INDEX IF NOT EXISTS idx_mission_requests_technician_id
ON public.mission_requests(technician_id);

CREATE INDEX IF NOT EXISTS idx_mission_requests_status
ON public.mission_requests(status);


-- ─── Technicians ─────────────────────────────────────────────────────────────
-- Note: technicians.user_id a déjà une contrainte UNIQUE (index auto-créé)
-- Seul l'index sur status est nécessaire
CREATE INDEX IF NOT EXISTS idx_technicians_status
ON public.technicians(status);


-- ─── Quotes ──────────────────────────────────────────────────────────────────
-- Utilisé par les policies RLS quotes_select_client (JOIN missions)
CREATE INDEX IF NOT EXISTS idx_quotes_technician_id
ON public.quotes(technician_id);


-- ─── Admin Logs ──────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_admin_logs_admin_id
ON public.admin_logs(admin_id);

CREATE INDEX IF NOT EXISTS idx_admin_logs_created_at
ON public.admin_logs(created_at DESC);


-- ─── Disputes ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_disputes_mission_id
ON public.disputes(mission_id);

CREATE INDEX IF NOT EXISTS idx_disputes_reporter_id
ON public.disputes(reporter_id);

CREATE INDEX IF NOT EXISTS idx_disputes_status
ON public.disputes(status);


-- ─── Technician Subscriptions ────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_tech_subscriptions_technician_id
ON public.technician_subscriptions(technician_id);

CREATE INDEX IF NOT EXISTS idx_tech_subscriptions_status
ON public.technician_subscriptions(status);


-- ============================================================================
-- FIN DE LA MIGRATION 030
-- ============================================================================
