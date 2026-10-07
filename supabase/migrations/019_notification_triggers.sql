-- =============================================================================
-- FICHIER : 019_notification_triggers.sql
-- RÔLE : Déclencheurs automatiques de notifications :
--         - 'handle_mission_status_notification()' : génère une notification in-app
--           lorsque le statut d'une mission évolue (quote_sent, quote_accepted, en_route, completed, etc.)
--         - 'handle_new_message_notification()' : alerte le destinataire lors de la réception
--           d'un nouveau message de tchat lié à la mission.
-- MODULE : Schéma de base de données / Triggers & Notifications
-- DÉPENDANCES : public.missions, public.messages, public.notifications
-- SÉCURITÉ / RLS : Fonctions définies en SECURITY DEFINER pour insérer dans la table notifications.
-- =============================================================================

-- Trigger function for mission status changes
CREATE OR REPLACE FUNCTION handle_mission_status_notification()
RETURNS TRIGGER AS $$
DECLARE
  notification_title TEXT;
  notification_body TEXT;
  notification_user_id UUID;
BEGIN
  -- Check if status actually changed
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    IF NEW.status = 'quote_sent' THEN
      notification_title := 'Nouveau devis reçu';
      notification_body := 'Le technicien vous a envoyé un devis. Veuillez le consulter et l''accepter.';
      notification_user_id := NEW.client_id;
    ELSIF NEW.status = 'quote_accepted' THEN
      notification_title := 'Devis accepté';
      notification_body := 'Le client a accepté votre devis. Vous pouvez commencer la mission.';
      notification_user_id := NEW.technician_id;
    ELSIF NEW.status = 'quote_rejected' THEN
      notification_title := 'Devis refusé';
      notification_body := 'Le client a refusé votre devis.';
      notification_user_id := NEW.technician_id;
    ELSIF NEW.status = 'accepted' THEN
      notification_title := 'Mission acceptée';
      notification_body := 'Le technicien a accepté votre demande de mission.';
      notification_user_id := NEW.client_id;
    ELSIF NEW.status = 'en_route' THEN
      notification_title := 'Technicien en route';
      notification_body := 'Le technicien est en route vers votre position.';
      notification_user_id := NEW.client_id;
    ELSIF NEW.status = 'in_progress' THEN
      notification_title := 'Mission commencée';
      notification_body := 'La mission a commencé.';
      notification_user_id := NEW.client_id;
    ELSIF NEW.status = 'completed' THEN
      notification_title := 'Mission terminée';
      notification_body := 'La mission est terminée. Merci de laisser un avis au technicien !';
      notification_user_id := NEW.client_id;
    END IF;

    -- Insert notification if applicable
    IF notification_user_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (
        notification_user_id, 
        notification_title, 
        notification_body, 
        'mission', 
        jsonb_build_object('mission_id', NEW.id)
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Trigger for mission status changes
DROP TRIGGER IF EXISTS on_mission_status_change ON public.missions;
CREATE TRIGGER on_mission_status_change
  AFTER UPDATE OF status ON public.missions
  FOR EACH ROW
  EXECUTE FUNCTION handle_mission_status_notification();


-- Trigger function for new messages
CREATE OR REPLACE FUNCTION handle_new_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  mission_record RECORD;
  notification_user_id UUID;
BEGIN
  -- Get mission details to find the other user
  SELECT client_id, technician_id INTO mission_record 
  FROM public.missions 
  WHERE id = NEW.mission_id;
  
  -- If sender is client, notify technician, else notify client
  IF NEW.sender_id = mission_record.client_id THEN
     notification_user_id := mission_record.technician_id;
  ELSE
     notification_user_id := mission_record.client_id;
  END IF;

  -- Insert notification if we found the user
  IF notification_user_id IS NOT NULL THEN
     INSERT INTO public.notifications (user_id, title, body, type, data)
     VALUES (
       notification_user_id, 
       'Nouveau message', 
       'Vous avez reçu un nouveau message concernant votre mission.', 
       'message', 
       jsonb_build_object('mission_id', NEW.mission_id)
     );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create Trigger for new messages
DROP TRIGGER IF EXISTS on_new_message_notification ON public.messages;
CREATE TRIGGER on_new_message_notification
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION handle_new_message_notification();
