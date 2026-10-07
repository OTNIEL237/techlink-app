// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : login_screen.dart
// Rôle          : Écran d'authentification utilisateur (Connexion email/mot de passe avec style neumorphique).
// Module        : Presentation / Auth
// Dépendances   : flutter_riverpod, go_router, supabase_flutter, neumorphic_styles.dart, auth_provider.dart
// Sécurité/RLS  : Authentifie l'utilisateur via Supabase Auth et purge le cache des rôles.
// =============================================================================

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/neumorphic_styles.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/morph_transitions.dart';
import '../../core/routing/app_router.dart';
import '../../providers/auth_provider.dart';

/// Écran principal de connexion utilisateur de l'application TechLink.
///
/// Propose une interface soignée avec design neumorphique 3D / Glassmorphism,
/// animations d'entrée en cascade (staggered animation), support dynamique
/// du mode sombre et gestion sécurisée des sessions.
class LoginScreen extends ConsumerStatefulWidget {
  /// Constructeur constant pour [LoginScreen].
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

/// État associé à l'écran de connexion [LoginScreen].
///
/// Gère la saisie des identifiants, le masquage/démasquage du mot de passe,
/// l'état de chargement et les animations d'entrée en cascade.
class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  /// Contrôleur du champ de saisie de l'adresse e-mail.
  final _emailController = TextEditingController();

  /// Contrôleur du champ de saisie du mot de passe.
  final _passwordController = TextEditingController();

  /// Indicateur déterminant si les caractères du mot de passe sont masqués.
  bool _isObscure = true;

  /// Option pour mémoriser la session locale.
  bool _rememberMe = true;

  /// Indicateur d'exécution d'une tentative de connexion réseau.
  bool _isLoading = false;

  /// Contrôleur principal des animations d'apparition synchronisées.
  late AnimationController _animController;

  /// Animation d'échelle avec effet ressort pour le logo 3D.
  late Animation<double> _logoScale;

  /// Animation d'opacité pour l'en-tête (titre et sous-titre).
  late Animation<double> _fadeHeader;

  /// Animation de translation verticale pour l'en-tête.
  late Animation<Offset> _slideHeader;

  /// Animation d'opacité pour le formulaire de saisie.
  late Animation<double> _fadeForm;

  /// Animation de translation pour le bloc de formulaire.
  late Animation<Offset> _slideForm;

  /// Animation d'opacité pour les boutons d'action en pied de page.
  late Animation<double> _fadeFooter;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    // 1. Logo 3D Spring Bouncy Entrance
    _logoScale = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.55, curve: Curves.elasticOut),
      ),
    );

    // 2. En-tête titre & sous-titre
    _fadeHeader = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.18, 0.60, curve: Curves.easeOut),
      ),
    );
    _slideHeader = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.18, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // 3. Formulaire (Champs email, mot de passe & remember me)
    _fadeForm = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOut),
      ),
    );
    _slideForm = Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.35, 0.80, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Boutons d'action & réseaux sociaux
    _fadeFooter = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Traduit les messages d'erreur courants de Supabase Auth en français limpide.
  String _translateAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials') || lower.contains('invalid_grant')) {
      return 'Adresse e-mail ou mot de passe incorrect.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Votre adresse e-mail n\'a pas encore été confirmée. Veuillez vérifier votre boîte de réception.';
    }
    if (lower.contains('user not found')) {
      return 'Aucun compte associé à cette adresse e-mail.';
    }
    if (lower.contains('too many requests') || lower.contains('rate limit')) {
      return 'Trop de tentatives de connexion. Veuillez patienter avant de réessayer.';
    }
    if (lower.contains('network') || lower.contains('socketexception')) {
      return 'Erreur de connexion internet. Veuillez vérifier votre réseau.';
    }
    return msg;
  }

  /// Nettoie les messages d'erreur bruts pour un affichage utilisateur agréable.
  String _cleanErrorMessage(String raw) {
    if (raw.startsWith('Exception: ')) {
      return raw.substring(11);
    }
    return raw;
  }

  /// Traite la soumission du formulaire de connexion.
  ///
  /// Valide les champs obligatoires, active le retour tactile, purge le cache
  /// de rôle obsolète et délègue l'authentification à [authNotifierProvider].
  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    debugPrint('════════════════════════════════════════════════════════════════');
    debugPrint('[CONNEXION] Tentative de connexion initiée');
    debugPrint('[CONNEXION] Email saisi : $email');
    debugPrint('════════════════════════════════════════════════════════════════');

    if (email.isEmpty || password.isEmpty) {
      debugPrint('[CONNEXION] Échec validation : email ou mot de passe vide.');
      _showToast('Veuillez remplir votre email et mot de passe');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      AppRouter.clearRoleCache();
      debugPrint('[CONNEXION] Étape 1 : Envoi de la requête de connexion à Supabase...');

      // Authentification Supabase
      final authResponse = await ref.read(authNotifierProvider.notifier).login(email, password);
      final user = authResponse.user;

      if (user == null) {
        debugPrint('[CONNEXION] Avertissement : Aucun utilisateur retourné.');
        _showToast('Erreur : impossible de récupérer vos données utilisateur.');
        return;
      }

      debugPrint('[CONNEXION] Étape 2 : Authentification réussie !');
      debugPrint('[CONNEXION] ID Utilisateur : ${user.id}');
      debugPrint('[CONNEXION] Email confirmé : ${user.emailConfirmedAt != null ? "Oui (${user.emailConfirmedAt})" : "Non"}');

      // Étape 3 : Résolution du rôle
      debugPrint('[CONNEXION] Étape 3 : Résolution du rôle utilisateur...');
      final role = await AppRouter.resolveUserRole(Supabase.instance.client, user);
      debugPrint('[CONNEXION] Rôle résolu : $role');

      if (!mounted) return;

      // Redirection déterministe basée sur le rôle si GoRouter n'a pas encore pris le relais
      if (role == 'admin') {
        debugPrint('[CONNEXION] Redirection vers l\'espace Administrateur (/admin/home)');
        context.go('/admin/home');
      } else if (role == 'technician') {
        final status = await AppRouter.resolveTechnicianStatus(Supabase.instance.client, user.id);
        debugPrint('[CONNEXION] Statut technicien : $status');
        if (status == 'approved') {
          debugPrint('[CONNEXION] Redirection Technicien approuvé (/technician/home)');
          context.go('/technician/home');
        } else if (status == 'pending') {
          debugPrint('[CONNEXION] Redirection Technicien en attente (/technician/pending)');
          context.go('/technician/pending');
        } else {
          debugPrint('[CONNEXION] Redirection Technicien onboarding (/technician/onboarding)');
          context.go('/technician/onboarding');
        }
      } else {
        // Client par défaut
        debugPrint('[CONNEXION] Redirection vers l\'espace Client (/client/home)');
        context.go('/client/home');
      }
    } on AuthException catch (e) {
      debugPrint('[CONNEXION] ERREUR AuthException : Code=${e.statusCode}, Message=${e.message}');
      final frenchMessage = _translateAuthError(e.message);
      _showToast(frenchMessage);
    } catch (e) {
      debugPrint('[CONNEXION] ERREUR Inattendue : $e');
      // Ignorer l'erreur si la session Supabase est bien active
      if (e.toString().contains('Future already completed') ||
          Supabase.instance.client.auth.currentSession != null) {
        debugPrint('[CONNEXION] Session Supabase valide malgré l\'exception de transition.');
        return;
      }
      _showToast('Erreur de connexion : ${_cleanErrorMessage(e.toString())}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Affiche un message éphémère flottant (SnackBar) pour informer l'utilisateur.
  ///
  /// [msg] Message textuel à présenter à l'écran.
  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 750;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      body: PinterestFluidBackground(
        showSpheres: false,
        useSafeArea: true,
        child: Stack(
          children: [
            // Contenu scrollable centré avec animation en cascade
            Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 460 : 420,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 6),

                      // 1. Hero Logo 3D Glassmorphism (Doux & Apaisant pour les yeux)
                      ScaleTransition(
                        scale: _logoScale,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Halo diffus doux et reposant pour les yeux
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A)).withOpacity(0.12),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.2, 1.0],
                                  radius: 0.8,
                                ),
                              ),
                            ),
                            // Glassmorphism card
                            Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withOpacity(0.85) : Colors.white.withOpacity(0.90),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.85),
                                  width: 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(21),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/icon/logo_techlink.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.handyman_rounded,
                                          size: 34,
                                          color: Color(0xFF1E3A8A),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Titres avec glissement & fondu (Couleurs douces et reposantes)
                      FadeTransition(
                        opacity: _fadeHeader,
                        child: SlideTransition(
                          position: _slideHeader,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Bienvenue sur',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.4,
                                  color: isDark
                                      ? NeumorphicTheme.darkTextPrimary
                                      : NeumorphicTheme.lightTextPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isDark
                                      ? [const Color(0xFFE2E8F0), const Color(0xFF93C5FD)]
                                      : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  'TechLink',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Connectez-vous pour continuer',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? NeumorphicTheme.darkTextSecondary
                                      : NeumorphicTheme.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 3. Formulaire animé (Verre givré neutre & apaisant)
                      FadeTransition(
                        opacity: _fadeForm,
                        child: SlideTransition(
                          position: _slideForm,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.80) : Colors.white.withOpacity(0.92),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.90),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.05),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                              // Champ Email
                              NeumorphicTextField(
                                controller: _emailController,
                                hint: 'Adresse email',
                                prefixIcon: Icons.person_outline_rounded,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),

                              const SizedBox(height: 18),

                              // Champ Password
                              NeumorphicTextField(
                                controller: _passwordController,
                                hint: 'Mot de passe',
                                prefixIcon: Icons.lock_outline_rounded,
                                obscureText: _isObscure,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleLogin(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _isObscure ? Icons.visibility : Icons.visibility_off,
                                    color: isDark ? const Color(0xFF8E9EB5) : const Color(0xFF6B7A99),
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() => _isObscure = !_isObscure);
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // Se souvenir de moi & Mot de passe oublié (100% Anti-débordement)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    flex: 5,
                                    child: GestureDetector(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setState(() => _rememberMe = !_rememberMe);
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            width: 18,
                                            height: 18,
                                            decoration: BoxDecoration(
                                              color: _rememberMe
                                                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A))
                                                  : (isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField),
                                              borderRadius: BorderRadius.circular(5),
                                              boxShadow: NeumorphicTheme.debossedShadows(isDark),
                                              border: Border.all(
                                                color: _rememberMe
                                                    ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A))
                                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: _rememberMe
                                                ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                                                : null,
                                          ),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Se souvenir',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? NeumorphicTheme.darkTextSecondary
                                                    : NeumorphicTheme.lightTextSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    flex: 6,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: GestureDetector(
                                        onTap: () {
                                          _showToast('Lien de réinitialisation envoyé à votre adresse email');
                                        },
                                        behavior: HitTestBehavior.opaque,
                                        child: Text(
                                          'Mot de passe oublié ?',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                      const SizedBox(height: 26),

                      // 4. Boutons d'action et réseaux sociaux animés
                      FadeTransition(
                        opacity: _fadeFooter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Bouton Se connecter avec effet Morphose Spring
                            MorphingCard(
                              borderRadius: BorderRadius.circular(28),
                              padding: EdgeInsets.zero,
                              onTap: _handleLogin,
                              child: NeumorphicGradientButton(
                                text: 'Se connecter',
                                isLoading: _isLoading || ref.watch(authNotifierProvider).isLoading,
                                showArrow: true,
                                onPressed: _handleLogin,
                              ),
                            ),
                            
                            const SizedBox(height: 28), // Espace aéré entre se connecter et s'inscrire

                            // Lien d'inscription vers RegisterScreen (Wrap anti-débordement)
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                Text(
                                  "Vous n'avez pas de compte ? ",
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: isDark
                                        ? NeumorphicTheme.darkTextSecondary
                                        : NeumorphicTheme.lightTextSecondary,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.go('/register'),
                                  behavior: HitTestBehavior.opaque,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      "S'inscrire",
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bouton de bascule Mode Clair / Sombre TOUJOURS au premier plan
            Positioned(
              top: 16,
              right: 20,
              child: const NeumorphicThemeToggle(),
            ),
          ],
        ),
      ),
    );
  }
}
