-- ============================================================================
-- 031_calls_indexes.sql
-- Optimisation des requêtes Realtime pour le service ZegoCloud
-- ============================================================================

-- Ces index permettent à Supabase Realtime d'écouter beaucoup plus rapidement
-- les changements d'état des appels pour un utilisateur spécifique.
-- (IF NOT EXISTS évite les erreurs si créés lors de la table initiale)

CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON public.calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON public.calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON public.calls(status);
