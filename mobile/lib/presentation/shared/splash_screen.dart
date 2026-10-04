import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/neumorphic_styles.dart';

// =========================================================================
// ÉCRAN DE DÉMARRAGE MODERNE (Splash Screen 3D Neumorphique)
// =========================================================================
// S'affiche à l'ouverture de l'application TechLink.
// Anime l'emblème 3D en relief avec un effet de respiration glassmorphique,
// vérifie la session Supabase active et oriente automatiquement l'utilisateur
// selon son rôle (Client, Technicien vérifié/en attente, ou Administrateur).

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _animController.forward();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Laisser le temps à l'animation d'accueillir l'utilisateur avec élégance
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;

    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        // Aucune session active -> Redirection vers la page de connexion
        if (mounted) context.go('/login');
        return;
      }

      // Session existante -> Récupération du rôle utilisateur dans Supabase
      final userResponse = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      if (!mounted) return;

      if (userResponse == null || userResponse['role'] == null) {
        // Profil incomplet -> Déconnexion de sécurité
        await Supabase.instance.client.auth.signOut();
        if (mounted) context.go('/login');
        return;
      }

      final role = userResponse['role'] as String;

      if (role == 'client') {
        context.go('/client/home');
      } else if (role == 'technician') {
        try {
          final tech = await Supabase.instance.client
              .from('technicians')
              .select('validation_status')
              .eq('user_id', session.user.id)
              .maybeSingle();

          if (!mounted) return;

          if (tech == null) {
            context.go('/technician/onboarding');
          } else if (tech['validation_status'] == 'approved') {
            context.go('/technician/home');
          } else if (tech['validation_status'] == 'pending') {
            context.go('/technician/pending');
          } else {
            context.go('/technician/onboarding');
          }
        } catch (e) {
          debugPrint('Erreur vérification technicien: $e');
          if (mounted) context.go('/technician/onboarding');
        }
      } else if (role == 'admin') {
        context.go('/admin/home');
      } else {
        await Supabase.instance.client.auth.signOut();
        if (mounted) context.go('/login');
      }
    } catch (e) {
      debugPrint('Erreur vérification session: $e');
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: NeumorphicBackground(
        showSpheres: true,
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. Hero Logo 3D Glassmorphism (Splash Screen)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing orb behind, animates with _glowAnimation
                            Container(
                              width: 170 + (20 * _glowAnimation.value),
                              height: 170 + (20 * _glowAnimation.value),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E3A8A)).withOpacity(0.35 * _glowAnimation.value),
                                    (isDark ? const Color(0xFF1E40AF) : const Color(0xFF3B82F6)).withOpacity(0.12 * _glowAnimation.value),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.2, 0.6, 1.0],
                                  radius: 0.8,
                                ),
                              ),
                            ),
                            // Glassmorphism card
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(42),
                                border: Border.all(
                                  color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1E3A8A).withOpacity(0.18 * _glowAnimation.value),
                                    blurRadius: 32,
                                    spreadRadius: 8,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(40),
                                child: BackdropFilter(
                                  filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                                  child: Center(
                                    child: Image.asset(
                                      'assets/icon/logo_techlink.png',
                                      width: 85,
                                      height: 85,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const Icon(
                                          Icons.handyman_rounded,
                                          size: 60,
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

                        const SizedBox(height: 38),

                        // Marque TechLink
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [const Color(0xFFE2E8F0), const Color(0xFF93C5FD), const Color(0xFF60A5FA)]
                                : [const Color(0xFF1E3A8A), const Color(0xFF1E40AF), const Color(0xFF2563EB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: const Text(
                            'TechLink',
                            style: TextStyle(
                              color: Colors.white, // Requis pour le ShaderMask
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.0,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Slogan / Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155).withOpacity(0.5)
                                  : const Color(0xFFDBEAFE).withOpacity(0.8),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Dépannage & Services Pro au Cameroun',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF4B5563),
                            ),
                          ),
                        ),

                        const SizedBox(height: 50),

                        // Barre de chargement neumorphique douce
                        Container(
                          width: 140,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E283E) : const Color(0xFFD6E0EE),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: isDark
                                    ? Colors.black.withOpacity(0.3)
                                    : const Color(0xFFBAC8DC).withOpacity(0.4),
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}