-- =============================================================================
-- FICHIER : 031_calls_indexes.sql
-- RÔLE : Optimisation des requêtes Realtime pour le service ZEGOCLOUD :
--         - Index sur la table 'calls' (receiver_id, caller_id, status)
--         - Accélération des filtres de souscription en temps réel lors des appels entrants.
-- MODULE : Schéma de base de données / Téléphonie & Realtime
-- DÉPENDANCES : public.calls
-- SÉCURITÉ / RLS : N/A (Indexation interne PostgreSQL).
-- =============================================================================

-- Ces index permettent à Supabase Realtime d'écouter beaucoup plus rapidement
-- les changements d'état des appels pour un utilisateur spécifique.
-- (IF NOT EXISTS évite les erreurs si créés lors de la table initiale)

CREATE INDEX IF NOT EXISTS idx_calls_receiver_id ON public.calls(receiver_id);
CREATE INDEX IF NOT EXISTS idx_calls_caller_id ON public.calls(caller_id);
CREATE INDEX IF NOT EXISTS idx_calls_status ON public.calls(status);
