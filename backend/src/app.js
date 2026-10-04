const express = require('express');
const cors = require('cors');
const compression = require('compression');
const swaggerUi = require('swagger-ui-express');
const swaggerSpec = require('./docs/swagger');
require('dotenv').config();

const { globalLimiter } = require('./middlewares/rateLimit.middleware');
const errorHandler = require('./middlewares/errorHandler.middleware');

const app = express();

// ✅ Middleware EN PREMIER
app.use(compression()); // Compresse les réponses HTTP pour économiser la bande passante
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// 🛡️ Protection Rate Limiting globale
app.use(globalLimiter);

// 📚 Documentation Swagger
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// Routes
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

// Mounting webhook and callback routes directly at root to preserve existing URLs
app.use('/', webhookRoutes);

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'TechLink API running' });
});

// 🛡️ Gestion globale des erreurs (doit être en TOUT DERNIER)
app.use(errorHandler);

// 🛡️ Protection contre les crashs de processus Node.js (Unhandled Rejections & Exceptions)
process.on('uncaughtException', (err) => {
  console.error('❌ [Process Error] Uncaught Exception:', err);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ [Process Error] Unhandled Rejection at:', promise, 'reason:', reason);
});

const PORT = process.env.PORT || 3000;
if (!process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 TechLink API démarrée sur le port ${PORT}`);
  });
}

module.exports = app;

