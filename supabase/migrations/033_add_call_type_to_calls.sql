-- =============================================================================
-- FICHIER : 033_add_call_type_to_calls.sql
-- RÔLE : Extension de la table 'calls' pour distinguer les types de communication :
--         - Ajout de la colonne 'call_type' avec contrainte CHECK ('audio', 'video')
--         - Valeur par défaut : 'audio'.
-- MODULE : Schéma de base de données / Téléphonie & Appels ZEGOCLOUD
-- DÉPENDANCES : public.calls
-- SÉCURITÉ / RLS : Permet le routage et l'initialisation adéquate des flux audio ou visio.
-- =============================================================================

-- Add call_type to calls table
ALTER TABLE calls 
ADD COLUMN call_type TEXT DEFAULT 'audio' CHECK (call_type IN ('audio', 'video'));
