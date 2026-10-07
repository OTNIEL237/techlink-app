// =============================================================================
// FICHIER : backend/src/docs/swagger.js
// RÔLE : Configuration OpenAPI / Swagger JSDoc pour la documentation interactive de l'API
// MODULE : Backend / Documentation Swagger
// DÉPENDANCES : swagger-jsdoc
// SÉCURITÉ / RLS : Déclare le schéma d'authentification Bearer JWT
// =============================================================================

const swaggerJsdoc = require('swagger-jsdoc');

/**
 * Options de configuration pour la génération de la spécification OpenAPI 3.0.0.
 * Définit les métadonnées de l'API, les serveurs d'exécution et les schémas de sécurité.
 */
const options = {
  definition: {
    openapi: '3.0.0',
    info: {
      title: 'TechLink Backend API',
      version: '1.0.0',
      description: 'API for TechLink Mobile App and Admin Panel',
    },
    servers: [
      {
        url: 'http://localhost:3000',
        description: 'Development server',
      },
      {
        url: 'https://techlink-backend-production.up.railway.app',
        description: 'Production server',
      },
    ],
    components: {
      securitySchemes: {
        bearerAuth: {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
        },
      },
    },
    security: [
      {
        bearerAuth: [],
      },
    ],
  },
  apis: ['./src/modules/**/*.routes.js'], // Chemins scannés pour extraire les annotations JSDoc Swagger
};

/** Spécification OpenAPI compilée par swagger-jsdoc */
const swaggerSpec = swaggerJsdoc(options);

module.exports = swaggerSpec;

