-- =============================================================================
-- FICHIER : 010_add_profile_photos.sql
-- RÔLE : Ajout des colonnes de gestion des photos de profil :
--         - 'avatar_url' dans la table 'users'
--         - 'photo_url' dans la table 'technicians'.
-- MODULE : Schéma de base de données / Profils & Médias
-- DÉPENDANCES : public.users, public.technicians
-- SÉCURITÉ / RLS : Permet l'affichage des avatars d'utilisateurs et techniciens.
-- =============================================================================

-- Add avatar_url to public.users if it doesn't exist
ALTER TABLE IF EXISTS public.users ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Add photo_url to public.technicians if it doesn't exist (assuming they might have a separate one, or they just use the user's avatar)
-- Let's add it to technicians as well just in case, but usually it's tied to the user table.
ALTER TABLE IF EXISTS public.technicians ADD COLUMN IF NOT EXISTS photo_url TEXT;
