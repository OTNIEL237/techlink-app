-- =============================================================================
-- FICHIER : supabase_admin_notifications.sql
-- RÔLE : Fonctions et déclencheurs de notifications automatisées pour les administrateurs :
--         - 'notify_admins()' : diffusion d'alertes in-app à tous les profils 'admin'
--         - Trigger sur inscription technicien (alerte validation KYC requise)
--         - Trigger sur activation d'abonnement (alerte nouveau forfait payé)
--         - Trigger sur signalement de litige sur une mission (alerte intervention requise).
-- MODULE : Schéma de base de données / Notifications Système Administrateur
-- DÉPENDANCES : public.users, public.technicians, public.technician_subscriptions, public.missions, public.notifications
-- SÉCURITÉ / RLS : Fonctions plpgsql exécutées sur le serveur PostgreSQL.
-- =============================================================================

-- Fonction utilitaire pour envoyer une notification à tous les administrateurs
CREATE OR REPLACE FUNCTION notify_admins(
  p_title VARCHAR,
  p_body TEXT,
  p_type VARCHAR,
  p_data JSONB DEFAULT NULL
) RETURNS void AS $$
DECLARE
  admin_rec RECORD;
BEGIN
  FOR admin_rec IN SELECT id FROM public.users WHERE role = 'admin' LOOP
    INSERT INTO public.notifications (user_id, title, body, type, data, is_read)
    VALUES (admin_rec.id, p_title, p_body, p_type, p_data, false);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 1. Trigger pour notifier l'inscription d'un nouveau technicien
CREATE OR REPLACE FUNCTION trigger_notify_new_technician()
RETURNS TRIGGER AS $$
DECLARE
  tech_name VARCHAR;
BEGIN
  -- Récupérer le nom de l'utilisateur
  SELECT name INTO tech_name FROM public.users WHERE id = NEW.user_id;

  PERFORM notify_admins(
    'Nouveau Technicien',
    'Le technicien ' || COALESCE(tech_name, 'Inconnu') || ' vient de s''inscrire et est en attente de validation.',
    'system',
    jsonb_build_object('technician_id', NEW.id, 'action', 'validation')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_technician_created ON public.technicians;
CREATE TRIGGER on_technician_created
AFTER INSERT ON public.technicians
FOR EACH ROW
EXECUTE FUNCTION trigger_notify_new_technician();

-- 2. Trigger pour notifier un nouvel abonnement
CREATE OR REPLACE FUNCTION trigger_notify_new_subscription()
RETURNS TRIGGER AS $$
DECLARE
  tech_name VARCHAR;
  should_notify BOOLEAN := false;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'active' THEN
      should_notify := true;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.status = 'active' AND OLD.status <> 'active' THEN
      should_notify := true;
    END IF;
  END IF;

  IF should_notify THEN
    SELECT u.name INTO tech_name 
    FROM public.users u 
    JOIN public.technicians t ON t.user_id = u.id 
    WHERE t.id = NEW.technician_id;

    PERFORM notify_admins(
      'Nouvel Abonnement',
      'Le technicien ' || COALESCE(tech_name, 'Inconnu') || ' a activé un abonnement ' || NEW.subscription_type || '.',
      'system',
      jsonb_build_object('technician_id', NEW.technician_id, 'action', 'subscription')
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_subscription_activated ON public.technician_subscriptions;
CREATE TRIGGER on_subscription_activated
AFTER INSERT OR UPDATE OF status ON public.technician_subscriptions
FOR EACH ROW
EXECUTE FUNCTION trigger_notify_new_subscription();

-- 3. Trigger pour notifier d'un litige
CREATE OR REPLACE FUNCTION trigger_notify_dispute()
RETURNS TRIGGER AS $$
BEGIN
  PERFORM notify_admins(
    'Nouveau Litige',
    'La mission ' || NEW.id || ' a été signalée comme en litige.',
    'system',
    jsonb_build_object('mission_id', NEW.id, 'action', 'dispute')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_mission_dispute ON public.missions;
CREATE TRIGGER on_mission_dispute
AFTER UPDATE OF status ON public.missions
FOR EACH ROW
WHEN (NEW.status = 'disputed' AND OLD.status <> 'disputed')
EXECUTE FUNCTION trigger_notify_dispute();
