-- =============================================================================
-- FICHIER : 017_technician_hourly_rate.sql
-- RÔLE : Ajout conditionnel de la colonne 'hourly_rate' dans la table 'technicians'
--         (tarif horaire indicatif de base du technicien en Francs CFA / FCFA).
-- MODULE : Schéma de base de données / Techniciens & Tarifs
-- DÉPENDANCES : public.technicians
-- SÉCURITÉ / RLS : Modifiable par le technicien propriétaire de la fiche.
-- =============================================================================

DO $$ 
BEGIN 
  -- Add 'hourly_rate' to technicians table
  IF NOT EXISTS(SELECT * FROM information_schema.columns WHERE table_name='technicians' AND column_name='hourly_rate') THEN
    ALTER TABLE technicians ADD COLUMN hourly_rate INTEGER DEFAULT 0;
  END IF;
END $$;
