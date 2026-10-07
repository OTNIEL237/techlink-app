// =============================================================================
// FICHIER : ai.controller.test.js
// RÔLE : Tests unitaires Jest pour le contrôleur d'intelligence artificielle analyzeProblem
//         (validation de la longueur de description, retour d'erreurs 400, mode secours/fallback).
// MODULE : Tests / Intelligence Artificielle (Backend)
// DÉPENDANCES : ../../../src/modules/ai/ai.service, ../../../src/modules/ai/ai.controller, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires avec mocks LLM)
// =============================================================================

const aiService = require('../../../src/modules/ai/ai.service');

// Mock complet de l'API OpenAI
jest.mock('openai', () => {
  return {
    OpenAI: jest.fn().mockImplementation(() => ({
      chat: {
        completions: {
          create: jest.fn(),
        },
      },
    })),
  };
});

describe('AI Controller: analyzeProblem', () => {
  let analyzeProblem;
  let mockReq;
  let mockRes;

  beforeEach(() => {
    jest.resetModules();
    // Recharger le controller après le mock
    analyzeProblem = require('../../../src/modules/ai/ai.controller').analyzeProblem;
    
    mockReq = { body: {} };
    mockRes = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
    };
    jest.spyOn(console, 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('devrait retourner 400 si problem est manquant', async () => {
    mockReq.body = {};

    await analyzeProblem(mockReq, mockRes);

    expect(mockRes.status).toHaveBeenCalledWith(400);
    expect(mockRes.json).toHaveBeenCalledWith({
      error: 'Veuillez décrire votre problème plus en détail',
    });
  });

  it('devrait retourner 400 si problem est trop court (< 5 caractères)', async () => {
    mockReq.body = { problem: 'eau' };

    await analyzeProblem(mockReq, mockRes);

    expect(mockRes.status).toHaveBeenCalledWith(400);
  });

  it('devrait retourner 400 si problem ne contient que des espaces', async () => {
    mockReq.body = { problem: '    ' };

    await analyzeProblem(mockReq, mockRes);

    expect(mockRes.status).toHaveBeenCalledWith(400);
  });

  it('devrait retourner un résultat JSON si problem est valide (via fallback)', async () => {
    // Sans clés API, le service utilise le fallback local
    mockReq.body = { problem: 'Mon robinet de cuisine fuit abondamment depuis hier' };

    await analyzeProblem(mockReq, mockRes);

    expect(mockRes.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: expect.objectContaining({
          is_relevant: true,
          category: expect.any(String),
          category_slug: expect.any(String),
        }),
      })
    );
  });

  it('devrait passer photos_count=0 par défaut si absent', async () => {
    mockReq.body = { problem: 'Mon climatiseur fait un bruit anormal depuis ce matin' };

    await analyzeProblem(mockReq, mockRes);

    expect(mockRes.json).toHaveBeenCalled();
    const result = mockRes.json.mock.calls[0][0];
    expect(result.success).toBe(true);
    // Pas de mention de photo dans le résumé
    expect(result.data.problem_summary).not.toContain('photo');
  });
});
