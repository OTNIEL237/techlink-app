-- =============================================================================
-- FICHIER : 011_user_preferences.sql
-- RÔLE : Ajout des colonnes de préférences utilisateur dans la table 'users' :
--         - 'language' (code langue de l'interface, défaut 'fr')
--         - 'dark_mode' (thème sombre, défaut false).
-- MODULE : Schéma de base de données / Préférences utilisateur
-- DÉPENDANCES : public.users
-- SÉCURITÉ / RLS : Mise à jour par l'utilisateur connecté via auth.uid() = id.
-- =============================================================================

-- Add language and dark_mode preferences to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS language VARCHAR(10) DEFAULT 'fr';
ALTER TABLE users ADD COLUMN IF NOT EXISTS dark_mode BOOLEAN DEFAULT false;
