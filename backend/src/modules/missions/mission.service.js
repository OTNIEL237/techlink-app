const supabase = require('../../config/supabase');

const createMission = async (data) => {
  const { data: mission, error } = await supabase
    .from('missions')
    .insert({
      client_id: data.client_id,
      problem_description: data.problem_description,
      problem_photos: data.problem_photos || [],
      urgency_level: data.urgency_level || 'normal',
      ai_solution: data.ai_solution,
      ai_category_detected: data.ai_category_detected,
      client_address: data.client_address,
      client_lat: data.client_lat,
      client_lng: data.client_lng,
      status: 'pending',
    })
    .select()
    .single();

  if (error) throw new Error(error.message);
  return mission;
};

const getClientMissions = async (clientId) => {
  const { data, error } = await supabase
    .from('missions')
    .select(`*, categories(name, slug)`)
    .eq('client_id', clientId)
    .order('created_at', { ascending: false });

  if (error) throw new Error(error.message);
  return data;
};

const getMissionById = async (missionId) => {
  const { data, error } = await supabase
    .from('missions')
    .select(`*, categories(name, slug)`)
    .eq('id', missionId)
    .single();

  if (error) throw new Error(error.message);
  return data;
};

const updateMissionStatus = async (missionId, status) => {
  // 🛡️ Logique de Séquestration (Escrow) : 
  // Libérer l'argent du paiement SEULEMENT quand la mission est marquée "completed"
  if (status === 'completed') {
    // 1. Chercher un paiement en attente de versement
    const { data: payment } = await supabase
      .from('payments')
      .select('*')
      .eq('mission_id', missionId)
      .eq('status', 'success')
      .eq('payout_status', 'pending')
      .single();

    if (payment) {
      // 2. Trouver le technicien
      const { data: technician } = await supabase
        .from('technicians')
        .select('*')
        .eq('id', payment.technician_id)
        .single();

      if (technician) {
        // 3. Ajouter la transaction dans l'historique du portefeuille
        await supabase
          .from('wallet_transactions')
          .insert({
            technician_id: technician.id,
            mission_id: missionId,
            type: 'payment',
            amount: payment.technician_amount,
            description: `Paiement libéré pour la mission terminée ${missionId}`,
            reference: payment.camerpay_reference,
          });

        // 4. Créditer le portefeuille virtuel du technicien
        await supabase
          .from('technicians')
          .update({
            wallet_balance: (technician.wallet_balance || 0) + payment.technician_amount,
            total_earnings: (technician.total_earnings || 0) + payment.technician_amount,
            total_missions: (technician.total_missions || 0) + 1,
          })
          .eq('id', technician.id);

        // 5. Marquer le versement comme complété
        await supabase
          .from('payments')
          .update({ payout_status: 'completed' })
          .eq('id', payment.id);
      }
    }
  }

  // Mettre à jour le statut de la mission
  const { data, error } = await supabase
    .from('missions')
    .update({ status })
    .eq('id', missionId)
    .select()
    .single();

  if (error) throw new Error(error.message);
  return data;
};

module.exports = { createMission, getClientMissions, getMissionById, updateMissionStatus };