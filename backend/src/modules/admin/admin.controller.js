// =============================================================================
// FICHIER : backend/src/modules/admin/admin.controller.js
// RÔLE : Contrôleur HTTP pour les opérations administratives (résolution des litiges)
// MODULE : Backend / Module Administrateur
// DÉPENDANCES : ./admin.service
// SÉCURITÉ / RLS : Actions d'arbitrage financier réservées aux administrateurs
// =============================================================================

const adminService = require('./admin.service');

/**
 * Traite la résolution administrative d'un litige sur une mission.
 * Valide l'action demandée ('refund_client', 'force_payment', 'neutral_cancel')
 * et délègue l'exécution financière au service administrateur.
 *
 * @param {import('express').Request} req - Requête contenant l'ID du litige en paramètre et l'action choisie
 * @param {import('express').Response} res - Réponse HTTP renvoyant le résultat de la résolution
 */
const resolveDispute = async (req, res) => {
  try {
    const { id } = req.params;
    const { action, adminId, notes } = req.body;
    
    // action: 'refund_client', 'force_payment', 'neutral_cancel'

    if (!['refund_client', 'force_payment', 'neutral_cancel'].includes(action)) {
      return res.status(400).json({ success: false, error: 'Invalid action' });
    }

    const result = await adminService.resolveDispute(id, action, adminId, notes);
    
    res.json({ success: true, data: result });
  } catch (error) {
    console.error('Error resolving dispute:', error);
    res.status(500).json({ success: false, error: error.message });
  }
};

module.exports = {
  resolveDispute
};

