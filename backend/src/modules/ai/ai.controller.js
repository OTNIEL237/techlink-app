// =============================================================================
// FICHIER : backend/src/modules/ai/ai.controller.js
// RÔLE : Contrôleur HTTP pour le diagnostic assisté par Intelligence Artificielle
// MODULE : Backend / Module IA (Assistant Diagnostic)
// DÉPENDANCES : ./ai.service
// SÉCURITÉ / RLS : Accessible aux clients authentifiés ou en phase de pré-diagnostic
// =============================================================================

const aiService = require('./ai.service');

/**
 * Analyse une description de panne ou problème technique soumise par le client.
 * Valide la longueur minimale de la description (5 caractères) et appelle le service IA.
 *
 * @param {import('express').Request} req - Requête contenant `problem` et optionnellement `photos_count`
 * @param {import('express').Response} res - Réponse renvoyant le diagnostic structuré (catégorie, urgence, estimation prix)
 */
const analyzeProblem = async (req, res) => {
  try {
    const { problem, photos_count } = req.body;

    if (!problem || problem.trim().length < 5) {
      return res.status(400).json({
        error: 'Veuillez décrire votre problème plus en détail'
      });
    }

    const result = await aiService.analyzeProblem(problem, photos_count || 0);
    res.json(result);

  } catch (error) {
    console.error('Erreur analyze problem:', error);
    res.status(500).json({ error: 'Erreur lors de l\'analyse IA' });
  }
};

module.exports = { analyzeProblem };