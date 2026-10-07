// =============================================================================
// FICHIER : test-campay.js
// RÔLE : Script de test d'intégration pour l'initialisation d'un paiement d'abonnement
//         via l'utilitaire camerpay.service.
// MODULE : Tests / Outils de développement (Backend)
// DÉPENDANCES : dotenv, ./src/utils/camerpay.service
// SÉCURITÉ / RLS : Script réservé à l'environnement de développement et validation locale.
// =============================================================================

require('dotenv').config();
const service = require('./src/utils/camerpay.service');

/**
 * Exécute un test d'initialisation de paiement CamerPay en direct.
 * @returns {Promise<void>}
 */
async function test() {
  try {
    const res = await service.initializePayment({
      type: 'subscription',
      amount: 20000,
      description: 'Test Subscription',
      clientPhone: '671234567',
      reference: 'TEST_REF_' + Date.now(),
    });
    console.log(JSON.stringify(res, null, 2));
  } catch (e) {
    console.error(e);
  }
}

test();
