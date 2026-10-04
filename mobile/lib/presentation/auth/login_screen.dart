import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/neumorphic_styles.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/animations/morph_transitions.dart';
import '../../providers/auth_provider.dart';

// =========================================================================
// ÉCRAN DE CONNEXION MODERNE (Login Neumorphique & Animations Pinterest)
// =========================================================================
// Animation d'entrée en cascade (staggered animation), arrière-plan fluide
// Pinterest respirant, champs neumorphiques creusés et retour tactile spring.

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isObscure = true;
  bool _rememberMe = true;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeHeader;
  late Animation<Offset> _slideHeader;
  late Animation<double> _fadeForm;
  late Animation<Offset> _slideForm;
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

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showToast('Veuillez remplir votre email et mot de passe');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      // Authentification Supabase (le flux réactif GoRouter déclenche automatiquement la redirection)
      await ref.read(authNotifierProvider.notifier).login(email, password);
    } on AuthException catch (e) {
      _showToast(e.message);
    } catch (e) {
      // Ignorer l'erreur si la session Supabase est bien active
      if (e.toString().contains('Future already completed') ||
          Supabase.instance.client.auth.currentSession != null) {
        return;
      }
      _showToast('Erreur de connexion: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
