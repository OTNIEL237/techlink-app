-- =============================================================================
-- FICHIER : 013_technician_details.sql
-- RÔLE : Enrichissement de la table 'technicians' :
--         - Ajout conditionnel de la colonne 'bio' (présentation professionnelle)
--         - Ajout conditionnel de la colonne 'availability' au format JSONB (planning hebdomadaire).
-- MODULE : Schéma de base de données / Techniciens
-- DÉPENDANCES : public.technicians
-- SÉCURITÉ / RLS : Mise à jour par le technicien propriétaire de la fiche profil.
-- =============================================================================

DO $$ 
BEGIN 
  -- We assume 'bio' might already exist since onboarding_screen uses it, but just in case:
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='bio') THEN
    ALTER TABLE technicians ADD COLUMN bio TEXT;
  END IF;
  
  -- Add 'availability' as JSONB
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='availability') THEN
    ALTER TABLE technicians ADD COLUMN availability JSONB DEFAULT '{}';
  END IF;
END $$;
