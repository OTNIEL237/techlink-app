// =============================================================================
// FICHIER : errorHandler.middleware.test.js
// RÔLE : Tests unitaires Jest pour le middleware global de capture d'erreurs
//         (gestion des statuts HTTP par défaut, masquage de détails sensibles en production,
//         exposition des traces d'erreurs en mode développement).
// MODULE : Tests / Middlewares (Backend)
// DÉPENDANCES : ../../src/middlewares/errorHandler.middleware, jest
// SÉCURITÉ / RLS : N/A (Tests de conformité de sécurité sur les messages d'erreur)
// =============================================================================

/**
 * Suite de tests unitaires pour le gestionnaire d'erreurs global errorHandler.
 */
describe('Middleware: errorHandler', () => {
  let errorHandler;
  let mockReq;
  let mockRes;
  let mockNext;
  const originalEnv = process.env.NODE_ENV;

  beforeEach(() => {
    // Recharger le module à chaque test pour un état propre
    jest.resetModules();
    errorHandler = require('../../src/middlewares/errorHandler.middleware');
    
    mockReq = {};
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    mockNext = jest.fn();
    // Supprimer les logs console pendant les tests
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
    jest.restoreAllMocks();
  });

  it('devrait retourner 500 par défaut si err.statusCode n\'est pas défini', () => {
    const err = new Error('Erreur interne');

    errorHandler(err, mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(500);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Erreur interne' })
    );
  });

  it('devrait utiliser err.statusCode s\'il est défini', () => {
    const err = new Error('Ressource non trouvée');
    err.statusCode = 404;

    errorHandler(err, mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(404);
    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Ressource non trouvée' })
    );
  });

  it('devrait masquer le message d\'erreur 500 en production', () => {
    process.env.NODE_ENV = 'production';
    // Recharger pour prendre en compte le changement d'env
    jest.resetModules();
    errorHandler = require('../../src/middlewares/errorHandler.middleware');
    
    const err = new Error('Détails sensibles de la DB');
    // statusCode non défini => 500

    errorHandler(err, mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(500);
    expect(mockRes.json).toHaveBeenCalledWith({
      error: 'Erreur interne du serveur',
    });
    // Pas de stack en production
    const jsonCall = mockRes.json.mock.calls[0][0];
    expect(jsonCall.stack).toBeUndefined();
  });

  it('devrait inclure la stack trace en développement', () => {
    process.env.NODE_ENV = 'development';
    jest.resetModules();
    errorHandler = require('../../src/middlewares/errorHandler.middleware');
    
    const err = new Error('Bug de dev');

    errorHandler(err, mockReq, mockRes, mockNext);

    const jsonCall = mockRes.json.mock.calls[0][0];
    expect(jsonCall.error).toBe('Bug de dev');
    expect(jsonCall.stack).toBeDefined();
  });

  it('devrait afficher le message d\'erreur custom pour les codes non-500 en production', () => {
    process.env.NODE_ENV = 'production';
    jest.resetModules();
    errorHandler = require('../../src/middlewares/errorHandler.middleware');
    
    const err = new Error('Accès refusé');
    err.statusCode = 403;

    errorHandler(err, mockReq, mockRes, mockNext);

    expect(mockRes.status).toHaveBeenCalledWith(403);
    expect(mockRes.json).toHaveBeenCalledWith({
      error: 'Accès refusé',
    });
  });

  it('devrait utiliser un message par défaut si err.message est vide', () => {
    const err = new Error();

    errorHandler(err, mockReq, mockRes, mockNext);

    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({ error: 'Erreur interne du serveur' })
    );
  });
});
