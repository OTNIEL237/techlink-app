// =============================================================================
// FICHIER : backend/src/app.js
// RÔLE : Configuration centrale de l'application Express (middlewares, routes, docs, erreurs)
// MODULE : Backend / Core Application
// DÉPENDANCES : express, cors, compression, swagger-ui-express, dotenv, rateLimit, errorHandler
// SÉCURITÉ / RLS : Rate limiting global, CORS sécurisé, gestion globale des exceptions
// =============================================================================

const express = require('express');
const cors = require('cors');
const compression = require('compression');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./docs/swagger');
require('dotenv').config();

const { globalLimiter } = require('./middlewares/rateLimit.middleware');
const errorHandler = require('./middlewares/errorHandler.middleware');

/** Instance principale de l'application Express */
const app = express();

// ✅ Middlewares fondamentaux (compression, CORS et analyseur JSON)
app.use(compression()); // Compresse les réponses HTTP pour économiser la bande passante
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// 🛡️ Protection Rate Limiting globale contre les attaques par force brute et abus d'API
app.use(globalLimiter);

// 📚 Exposition de la documentation interactive Swagger / OpenAPI
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Déclaration et enregistrement des routeurs applicatifs par module
const aiRoutes = require('./modules/ai/ai.routes');
const missionRoutes = require('./modules/missions/mission.routes');
const paymentRoutes = require('./modules/payments/payment.routes');
const subscriptionRoutes = require('./modules/subscriptions.routes');
const adminRoutes = require('./modules/admin/admin.routes');
const webhookRoutes = require('./modules/payments/payment.webhook');

app.use('/api/ai', aiRoutes);
app.use('/api/missions', missionRoutes);
app.use('/api/payments', paymentRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/admin', adminRoutes);

// Montage des webhooks de paiement directement à la racine pour compatibilité passerelles
app.use('/', webhookRoutes);

/**
 * Route de contrôle de santé (health check) pour le monitoring et orchestrateurs.
 * @route GET /health
 */
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'TechLink API running' });
});

// 🛡️ Middleware de gestion globale et uniforme des erreurs HTTP (doit être en DERNIER)
app.use(errorHandler);

// 🛡️ Protection contre les crashs inopinés du processus Node.js
process.on('uncaughtException', (err) => {
  console.error('❌ [Process Error] Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ [Process Error] Unhandled Rejection at:', promise, 'reason:', reason);
});

/** Port d'écoute par défaut ou injecté par l'environnement */
const PORT = process.env.PORT || 3000;
if (!process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 TechLink API démarrée sur le port ${PORT}`);
  });
}

module.exports = app;


