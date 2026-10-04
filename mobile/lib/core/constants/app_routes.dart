class AppRoutes {
  // Auth
  static const String splash = '/';
  static const String phoneInput = '/phone';
  static const String otpVerify = '/otp';

  // Client
  static const String clientHome = '/client/home';
  static const String problemInput = '/client/problem';
  static const String aiSolution = '/client/ai-solution';
  static const String techniciansMap = '/client/map';
  static const String technicianDetail = '/client/technician/:id';
  static const String missionTracking = '/client/tracking/:id';
  static const String quoteReview = '/client/quote/:id';
  static const String payment = '/client/payment/:id';
  static const String rating = '/client/rating/:id';
  static const String clientHistory = '/client/history';

  // Technicien
  static const String technicianOnboarding = '/technician/onboarding';
  static const String pendingValidation = '/technician/pending';
  static const String technicianHome = '/technician/home';
  static const String missionRequest = '/technician/request/:id';
  static const String missionActive = '/technician/mission/:id';
  static const String quoteBuilder = '/technician/quote/:id';
  static const String earnings = '/technician/earnings';
  static const String technicianHistory = '/technician/history';

  // Partagés
  static const String chat = '/chat/:missionId';
  static const String profile = '/profile';
}