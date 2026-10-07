// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : app_routes.dart
// Rôle          : Définition centralisée de tous les chemins d'URL (routes)
//                 utilisés par le routeur déclaratif GoRouter.
// Module        : Core / Constantes & Navigation
// Dépendances   : Aucune (constantes pures)
// Sécurité/RLS  : Référencé par AppRouter pour appliquer les guards
// =============================================================================

/// [AppRoutes]
///
/// Répertoire complet des routes nommées de l'application TechLink,
/// classées par domaine métier (Authentification, Client, Technicien, Partagé).
class AppRoutes {
  // ── 1. ROUTES D'AUTHENTIFICATION & INITIALISATION ──
  /// Écran de démarrage animé (Splash screen & vérification de session).
  static const String splash = '/';
  /// Saisie du numéro de téléphone pour l'authentification par SMS.
  static const String phoneInput = '/phone';
  /// Vérification du code OTP reçu par SMS.
  static const String otpVerify = '/otp';
  /// Page de connexion avec email et mot de passe.
  static const String login = '/login';
  /// Formulaire d'inscription multi-étapes pour clients et techniciens.
  static const String register = '/register';

  // ── 2. ROUTES DE L'ESPACE CLIENT ──
  /// Tableau de bord principal du client (recherche, catégories, bannières).
  static const String clientHome = '/client/home';
  /// Saisie du problème (texte ou synthèse vocale).
  static const String problemInput = '/client/problem';
  /// Solution générée par l'intelligence artificielle et devis estimatif.
  static const String aiSolution = '/client/ai-solution';
  /// Carte radar affichant les techniciens géolocalisés à proximité.
  static const String techniciansMap = '/client/map';
  /// Profil public détaillé d'un technicien consulté par le client.
  static const String technicianDetail = '/client/technician/:id';
  /// Suivi en temps réel de l'état d'avancement d'une intervention.
  static const String missionTracking = '/client/tracking/:id';
  /// Revue et acceptation d'un devis émis par un technicien.
  static const String quoteReview = '/client/quote/:id';
  /// Écran de paiement Mobile Money pour le règlement d'une mission.
  static const String payment = '/client/payment/:id';
  /// Évaluation et notation du technicien après fin d'intervention.
  static const String rating = '/client/rating/:id';
  /// Historique complet de toutes les commandes et interventions du client.
  static const String clientHistory = '/client/history';

  // ── 3. ROUTES DE L'ESPACE TECHNICIEN ──
  /// Parcours de finalisation du profil technique (KYC, pièces justificatives).
  static const String technicianOnboarding = '/technician/onboarding';
  /// Écran d'attente de validation administrative (KYC en cours d'examen).
  static const String pendingValidation = '/technician/pending';
  /// Tableau de bord principal du technicien (missions disponibles, alertes).
  static const String technicianHome = '/technician/home';
  /// Notification détaillée d'une demande de mission reçue.
  static const String missionRequest = '/technician/request/:id';
  /// Écran de déroulement d'une mission active (en route, sur place, terminée).
  static const String missionActive = '/technician/mission/:id';
  /// Outil de génération et d'envoi d'un devis au client.
  static const String quoteBuilder = '/technician/quote/:id';
  /// Historique des gains, portefeuille et statistiques financières.
  static const String earnings = '/technician/earnings';
  /// Historique des missions réalisées par le technicien.
  static const String technicianHistory = '/technician/history';
  /// Sélection et gestion des abonnements mensuels/annuels pro.
  static const String subscriptionSelect = '/subscription/select';

  // ── 4. ROUTES PARTAGÉES (CLIENT & TECHNICIEN & ADMIN) ──
  /// Messagerie instantanée en direct liée à une mission spécifique.
  static const String chat = '/chat/:missionId';
  /// Profil personnel et paramètres du compte de l'utilisateur connecté.
  static const String profile = '/profile';
  /// Centre de notifications système et alertes.
  static const String notifications = '/notifications';
  /// Appel vocal sécurisé en direct.
  static const String callAudio = '/call/audio';
  /// Appel vidéo sécurisé en direct.
  static const String callVideo = '/call/video';
}