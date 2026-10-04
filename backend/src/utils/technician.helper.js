const supabase = require('../config/supabase');

async function findTechnician(technicianId) {
  const byUserId = await supabase
    .from('technicians')
    .select('id, user_id, wallet_balance, total_earnings, total_missions, mtn_number, orange_number')
    .eq('user_id', technicianId)
    .maybeSingle();

  if (byUserId.data) {
    return byUserId.data;
  }

  const byTechnicianId = await supabase
    .from('technicians')
    .select('id, user_id, wallet_balance, total_earnings, total_missions, mtn_number, orange_number')
    .eq('id', technicianId)
    .maybeSingle();

  return byTechnicianId.data;
}

module.exports = {
  findTechnician
};
