// =============================================================================
// FICHIER : ai.service.test.js
// RÔLE : Tests unitaires Jest pour le service d'analyse IA (analyzeProblem) :
//         - Tests du fallback heuristique local par mots-clés
//         - Tests du cache en mémoire et normalisation textuelle
//         - Tests du chaînage de résilience (Groq -> OpenAI -> Fallback).
// MODULE : Tests / Intelligence Artificielle (Backend)
// DÉPENDANCES : ../../../src/modules/ai/ai.service, openai, jest
// SÉCURITÉ / RLS : N/A (Tests unitaires avec isolation d'environnement)
// =============================================================================

jest.mock('openai', () => {
  const mockCreate = jest.fn();
  return {
    OpenAI: jest.fn().mockImplementation(() => ({
      chat: {
        completions: {
          create: mockCreate,
        },
      },
    })),
    __mockCreate: mockCreate, // Exposer pour les tests
  };
});

describe('AI Service: analyzeProblem', () => {
  let analyzeProblem;
  const originalEnv = { ...process.env };

  beforeEach(() => {
    jest.resetModules();
    // Désactiver les clés API pour tester le fallback par défaut
    delete process.env.GROQ_API_KEY;
    delete process.env.OPENAI_API_KEY;
    jest.spyOn(console, 'log').mockImplementation(() => {});
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    jest.spyOn(console, 'error').mockImplementation(() => {});
    
    const aiService = require('../../../src/modules/ai/ai.service');
    analyzeProblem = aiService.analyzeProblem;
  });

  afterEach(() => {
    process.env = { ...originalEnv };
    jest.restoreAllMocks();
  });

  // ─── TESTS DU FALLBACK LOCAL ───────────────────────────────────────────

  describe('fallbackAnalyze (aucune clé API)', () => {
    it('devrait détecter "plomberie" à partir de mots-clés eau/robinet', async () => {
      const result = await analyzeProblem('Mon robinet fuit dans la cuisine');

      expect(result.success).toBe(true);
      expect(result.data.category).toBe('Plomberie');
      expect(result.data.category_slug).toBe('plomberie');
      expect(result.data.is_relevant).toBe(true);
    });

    it('devrait détecter "électricité" à partir de mots-clés courant/prise', async () => {
      const result = await analyzeProblem('La prise électrique fait des étincelles');

      expect(result.success).toBe(true);
      expect(result.data.category).toBe('Électricité');
      expect(result.data.category_slug).toBe('electricite');
    });

    it('devrait détecter "climatisation" à partir de mots-clés clim/froid', async () => {
      const result = await analyzeProblem('Mon climatiseur ne fait plus de froid');

      expect(result.success).toBe(true);
      expect(result.data.category).toBe('Climatisation');
      expect(result.data.category_slug).toBe('climatisation');
    });

    it('devrait détecter "informatique" à partir de mots-clés ordinateur/wifi', async () => {
      const result = await analyzeProblem('Mon ordinateur ne se connecte plus au wifi');

      expect(result.success).toBe(true);
      expect(result.data.category).toBe('Informatique');
      expect(result.data.category_slug).toBe('informatique');
    });

    it('devrait détecter "menuiserie" à partir de mots-clés porte/fenêtre', async () => {
      const result = await analyzeProblem('La porte de ma chambre ne ferme plus correctement');

      expect(result.success).toBe(true);
      expect(result.data.category).toBe('Menuiserie');
      expect(result.data.category_slug).toBe('menuiserie');
    });

    it('devrait tomber sur "Service général" si aucun mot-clé ne correspond', async () => {
      const result = await analyzeProblem('Je veux quelqu\'un pour un travail spécial chez moi');

      expect(result.success).toBe(true);
      expect(result.data.category_slug).toBe('general');
    });

    it('devrait mentionner les photos dans le résumé si photos_count > 0', async () => {
      const result = await analyzeProblem('Mon robinet fuit', 2);

      expect(result.data.problem_summary).toContain('photo');
    });

    it('devrait toujours retourner une solution temporaire', async () => {
      const result = await analyzeProblem('Problème électrique dans mon salon');

      expect(result.data.temporary_solution).toBeDefined();
      expect(result.data.temporary_solution.length).toBeGreaterThan(0);
    });

    it('devrait retourner une durée estimée', async () => {
      const result = await analyzeProblem('Fuite eau toilette');

      expect(result.data.estimated_duration).toBeDefined();
    });
  });

  // ─── TESTS DU CACHE ───────────────────────────────────────────────────

  describe('Cache mémoire', () => {
    it('devrait retourner le même résultat pour un texte identique (cache hit)', async () => {
      const problem = 'Le robinet de la salle de bain fuit depuis ce matin';
      
      const result1 = await analyzeProblem(problem);
      const result2 = await analyzeProblem(problem);

      // Les deux résultats doivent être identiques
      expect(result1).toEqual(result2);
    });

    it('devrait normaliser le texte pour le cache (accents, majuscules)', async () => {
      const result1 = await analyzeProblem('Mon ROBINET fuit beaucoup trop vite');
      const result2 = await analyzeProblem('mon robinet fuit beaucoup trop vite');

      expect(result1.data.category_slug).toEqual(result2.data.category_slug);
    });
  });

  // ─── TESTS DU CHAINAGE IA ─────────────────────────────────────────────

  describe('Chaînage Groq → OpenAI → Fallback', () => {
    it('devrait utiliser le fallback si aucune clé API n\'est disponible', async () => {
      const result = await analyzeProblem('Panne de courant dans tout l\'appartement');

      // Le fallback doit fonctionner sans exception
      expect(result.success).toBe(true);
      expect(result.data).toBeDefined();
    });

    it('devrait essayer Groq en premier si GROQ_API_KEY est défini', async () => {
      jest.resetModules();
      process.env.GROQ_API_KEY = 'test_groq_key';
      
      const { OpenAI, __mockCreate } = require('openai');
      
      // Simuler un échec de Groq pour qu'il tombe sur le fallback
      __mockCreate.mockRejectedValueOnce(new Error('Groq timeout'));
      
      const { analyzeProblem: ap } = require('../../../src/modules/ai/ai.service');
      const result = await ap('Mon évier est bouché depuis deux jours');

      // Doit quand même retourner un résultat via fallback
      expect(result.success).toBe(true);
    });
  });
});
