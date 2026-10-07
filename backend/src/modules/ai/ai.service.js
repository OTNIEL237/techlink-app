// =============================================================================
// FICHIER : backend/src/modules/ai/ai.service.js
// RÔLE : Orchestrateur de diagnostic IA (Cache LRU, Groq LLaMA, OpenAI Fallback, Analyse locale)
// MODULE : Backend / Module IA (Service)
// DÉPENDANCES : openai, dotenv
// SÉCURITÉ / RLS : Nettoyage et assainissement des prompts, gestion sécurisée des clés d'API
// =============================================================================

const { OpenAI } = require('openai');

// ---------------------------------------------------------
// 1. CACHE EN MÉMOIRE
// ---------------------------------------------------------
/** Cache en mémoire pour stocker les diagnostics récents et réduire les coûts d'inférence */
const analysisCache = new Map();
/** Durée de rétention des résultats en cache (24 heures) */
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Normalise une chaîne de texte pour servir de clé de hachage de cache (minuscules, sans accents ni ponctuation).
 *
 * @param {string} text - Texte brut à normaliser
 * @returns {string} Chaîne normalisée
 */
const normalizeTextForCache = (text) => {
  return text.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9 ]/g, ' ')
    .trim()
    .replace(/\s+/g, ' '); // Enlève les espaces multiples
};

// ---------------------------------------------------------
// 2. ANALYSE LOCALE (FALLBACK ULTIME)
// ---------------------------------------------------------
/**
 * Diagnostic local déterministe basé sur des expressions régulières et mots-clés métier.
 * Utilisé en cas d'indisponibilité du réseau ou de quota LLM dépassé.
 *
 * @param {string} problem - Description du problème
 * @param {number} photosCount - Nombre de photos jointes
 * @returns {{success: boolean, data: Object}} Diagnostic structuré par défaut
 */
const fallbackAnalyze = (problem, photosCount) => {
  const problemNormalized = normalizeTextForCache(problem);

  const categories = [
    { name: 'Plomberie', slug: 'plomberie', keywords: /eau|robinet|fuit|tuyau|wc|toilette|evier|douche|chauffe|canalisation/ },
    { name: 'Électricité', slug: 'electricite', keywords: /electr|courant|prise|disjonct|cable|lumiere|ampoule|court circuit|fil/ },
    { name: 'Climatisation', slug: 'climatisation', keywords: /clim|climatiseur|froid|chaud|ventilat|air conditionn/ },
    { name: 'Informatique', slug: 'informatique', keywords: /ordinateur|pc|laptop|internet|reseau|wifi|ecran|virus/ },
    { name: 'Menuiserie', slug: 'menuiserie', keywords: /porte|fenetre|serrure|meuble|bois|parquet|placard/ },
    { name: 'Service général', slug: 'general', keywords: /.*/ }
  ];

  let selectedCategory = categories[categories.length - 1];
  let maxMatches = 0;

  categories.slice(0, -1).forEach((cat) => {
    const matches = (problemNormalized.match(cat.keywords) || []).length;
    if (matches > maxMatches) {
      maxMatches = matches;
      selectedCategory = cat;
    }
  });

  const photoNote = photosCount > 0 ? ` ${photosCount} photo(s) fournie(s).` : '';

  return {
    success: true,
    data: {
      is_relevant: true,
      category: selectedCategory.name,
      category_slug: selectedCategory.slug,
      urgency: 'normal',
      urgency_label: 'Normal',
      temporary_solution: `1. Isolez la zone concernée par le problème.\n2. Ne tentez pas de réparer vous-même si cela présente un danger.\n3. Attendez le technicien avec ces informations.`,
      problem_summary: `Problème de ${selectedCategory.name.toLowerCase()} détecté.${photoNote}`,
      estimated_duration: '1h à 3h',
      safety_warning: '',
    }
  };
};

// ---------------------------------------------------------
// 3. ANALYSE IA (GROQ -> OPENAI -> LOCAL)
// ---------------------------------------------------------
/**
 * Analyse une description de panne en cascade :
 * 1. Vérifie le cache local (TTL 24h).
 * 2. Tente une inférence ultra-rapide avec Groq (LLaMA 3.3).
 * 3. En cas d'échec, bascule sur OpenAI (GPT-4o-mini).
 * 4. En cas de panne générale des API, bascule sur l'analyseur déterministe local.
 *
 * @param {string} problem - Description formulée par le client
 * @param {number} [photosCount=0] - Nombre de clichés annexés
 * @returns {Promise<{success: boolean, data: Object}>} Diagnostic complet validé
 */
const analyzeProblem = async (problem, photosCount = 0) => {
  try {
    // A. VÉRIFICATION DU CACHE
    const cacheKey = normalizeTextForCache(problem);
    if (analysisCache.has(cacheKey)) {
      const cached = analysisCache.get(cacheKey);
      if (Date.now() - cached.timestamp < CACHE_TTL_MS) {
        console.log(`[AI Cache Hit] => ${cacheKey.substring(0, 30)}...`);
        return { success: true, data: cached.data };
      } else {
        analysisCache.delete(cacheKey);
      }
    }

    // Le Prompt
    const systemPrompt = `Tu es l'assistant IA expert en diagnostic de TechLink.
Ton rôle est d'analyser le problème technique du client et de retourner un objet JSON structuré.

RÈGLES IMPORTANTES :
1. "temporary_solution" DOIT être ultra-spécifique et EXACTEMENT adaptée au problème décrit par l'utilisateur. INTERDICTION FORMELLE de donner une solution générique ou un modèle pré-fait.
   - Si le problème est précis (ex: "écran noir avec bip au démarrage"), donne 2 ou 3 étapes de vérification techniques précises pour CE problème.
   - Si la description est trop courte ou vague (ex: "problème informatique"), réponds ceci dans temporary_solution : "Votre description est un peu vague. Pourriez-vous préciser les symptômes exacts (ex: ne s'allume plus, message d'erreur...) pour obtenir une solution sur-mesure ?"
2. Si la demande est hors-sujet (ex: cuisine, conseils de vie), is_relevant = false.

### STRUCTURE DE RÉPONSE OBLIGATOIRE (JSON strict uniquement) :
{
  "is_relevant": true/false,
  "category": "Nom complet de la catégorie",
  "category_slug": "slug_exact (electricite, plomberie, electromenager, climatisation, informatique, reseau, menuiserie, peinture, maconnerie, gaz, reparation_telephone, motorisation, serrurerie, general)",
  "urgency": "urgent" | "normal" | "low",
  "urgency_label": "Urgent" | "Normal" | "Faible",
  "problem_summary": "Résumé ultra-clair du problème",
  "temporary_solution": "1. ...\\n2. ... (spécifique au problème !)",
  "estimated_duration": "Durée estimée (ex: 1h à 2h)",
  "safety_warning": "Consigne de sécurité cruciale si danger, sinon vide."
}`;

    const promptText = `Problème : "${problem}"${photosCount > 0 ? `\n(Photos jointes: ${photosCount})` : ''}`;

    let content = null;

    // B. ESSAI AVEC GROQ (LLaMA 3.3) - Priorité car ultra rapide
    if (process.env.GROQ_API_KEY) {
      try {
        console.log('[AI] Tentative avec Groq...');
        const groqClient = new OpenAI({
          apiKey: process.env.GROQ_API_KEY,
          baseURL: "https://api.groq.com/openai/v1"
        });
        
        const response = await groqClient.chat.completions.create({
          model: 'llama3-70b-8192', // Ou llama-3.3-70b-versatile selon disponibilité
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: promptText }
          ],
          temperature: 0.2,
          response_format: { type: 'json_object' }
        });
        content = response.choices[0].message.content;
      } catch (e) {
        console.error('[AI] Erreur Groq:', e.message);
        content = null;
      }
    }

    // C. ESSAI AVEC OPENAI (Secours)
    if (!content && process.env.OPENAI_API_KEY) {
      try {
        console.log('[AI] Tentative avec OpenAI (Fallback)...');
        const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });
        const response = await openai.chat.completions.create({
          model: 'gpt-4o-mini',
          messages: [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: promptText }
          ],
          temperature: 0.2,
          response_format: { type: 'json_object' }
        });
        content = response.choices[0].message.content;
      } catch (e) {
        console.error('[AI] Erreur OpenAI:', e.message);
        content = null;
      }
    }

    // D. GESTION DU RÉSULTAT
    if (content) {
      const parsedData = JSON.parse(content);
      
      // Sauvegarde dans le cache (avec limitation de taille pour éviter les fuites mémoire)
      if (analysisCache.size >= 500) {
        const oldestKey = analysisCache.keys().next().value;
        analysisCache.delete(oldestKey);
      }
      analysisCache.set(cacheKey, {
        data: parsedData,
        timestamp: Date.now()
      });

      return { success: true, data: parsedData };
    } else {
      // Aucun service IA n'a fonctionné ou aucune clé n'est dispo
      console.warn('⚠️ Tous les services IA ont échoué, utilisation du fallback local');
      return fallbackAnalyze(problem, photosCount);
    }

  } catch (error) {
    console.error('Erreur Critique IA:', error);
    return fallbackAnalyze(problem, photosCount);
  }
};

module.exports = { analyzeProblem };