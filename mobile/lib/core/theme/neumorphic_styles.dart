// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : neumorphic_styles.dart
// Rôle          : Design System Neumorphique & Glassmorphisme 3D.
//                 Fournit les ombres en relief (embossed), en creux (debossed),
//                 les dégradés signatures, et les widgets stylisés
//                 (NeumorphicCard, NeumorphicButton, NeumorphicTextField, etc.).
// Module        : Core / Thèmes & Design System
// Dépendances   : Flutter Material, Flutter Riverpod
// Sécurité/RLS  : Public / UI
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_provider.dart';

/// [NeumorphicTheme]
///
/// Système de design Neumorphisme Doux & Glassmorphisme 3D
/// Inspiré de la maquette moderne Pinterest avec support Mode Clair & Sombre.
class NeumorphicTheme {
  // ── Palette Mode Clair (Blanc pur professionnel) ──
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF8FAFC);
  static const Color lightField = Color(0xFFF1F5F9);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);
  static const Color lightShadowTop = Colors.white;
  static const Color lightShadowBottom = Color(0xFFE2E8F0);

  // ── Palette Mode Sombre (VS Code Dark Professionnel #1E1E1E) ──
  static const Color darkBg = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF252526);
  static const Color darkField = Color(0xFF2D2D30);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF858585);
  static const Color darkShadowTop = Color(0xFF2A2A2B);
  static const Color darkShadowBottom = Color(0xFF141414);

  // ── Dégradés Signature (Palette élégante, douce et apaisante pour les yeux) ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1E3A8A), Color(0xFF1E40AF), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient techlinkVioletGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF4338CA), Color(0xFF3730A3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentCyanGradient = LinearGradient(
    colors: [Color(0xFF60A5FA), Color(0xFF1E40AF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Ombres neumorphiques en relief (Embossed)
  static List<BoxShadow> embossedShadows(bool isDark, {double depth = 6, double blur = 14}) {
    if (isDark) {
      return [
        BoxShadow(
          color: darkShadowTop.withOpacity(0.55),
          offset: Offset(-depth * 0.7, -depth * 0.7),
          blurRadius: blur * 0.8,
        ),
        BoxShadow(
          color: darkShadowBottom.withOpacity(0.75),
          offset: Offset(depth, depth),
          blurRadius: blur,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: lightShadowTop.withOpacity(0.95),
          offset: Offset(-depth, -depth),
          blurRadius: blur,
        ),
        BoxShadow(
          color: lightShadowBottom.withOpacity(0.65),
          offset: Offset(depth, depth),
          blurRadius: blur * 1.1,
        ),
      ];
    }
  }

  // Ombres debossed / creusées pour les champs de formulaire
  static List<BoxShadow> debossedShadows(bool isDark) {
    if (isDark) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.35),
          offset: const Offset(2, 2),
          blurRadius: 4,
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFFCAD7E8).withOpacity(0.45),
          offset: const Offset(2, 3),
          blurRadius: 6,
        ),
      ];
    }
  }
}

/// Conteneur d'arrière-plan épuré et professionnel sans animation
class NeumorphicBackground extends StatelessWidget {
  final Widget child;
  final bool showSpheres;

  const NeumorphicBackground({
    super.key,
    required this.child,
    this.showSpheres = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? NeumorphicTheme.darkBg : NeumorphicTheme.lightBg;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: SafeArea(child: child),
    );
  }
}

/// Carte / Conteneur Neumorphique en relief (Squircle avec double ombre douce)
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool hasInnerGlow;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.hasInnerGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? NeumorphicTheme.darkCard : NeumorphicTheme.lightCard;

    final container = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: NeumorphicTheme.embossedShadows(isDark),
        border: Border.all(
          color: isDark
              ? const Color(0xFF263352).withOpacity(0.45)
              : Colors.white.withOpacity(0.85),
          width: 1.2,
        ),
      ),
      child: child,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: container,
      );
    }
    return container;
  }
}

/// Bouton tactile neumorphique (pour toggle thème, icônes sociales, etc.)
class NeumorphicIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  final double size;
  final double borderRadius;
  final String? tooltip;

  const NeumorphicIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.borderRadius = 16,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final btnBg = isDark ? NeumorphicTheme.darkCard : NeumorphicTheme.lightCard;

    Widget btn = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: btnBg,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: NeumorphicTheme.embossedShadows(isDark, depth: 4, blur: 8),
          border: Border.all(
            color: isDark
                ? const Color(0xFF283655).withOpacity(0.5)
                : Colors.white.withOpacity(0.9),
            width: 1.0,
          ),
        ),
        child: Center(child: icon),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// Bouton à bascule du Thème (Soleil / Lune) avec animation
class NeumorphicThemeToggle extends ConsumerWidget {
  const NeumorphicThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return NeumorphicIconButton(
      size: 42,
      borderRadius: 14,
      tooltip: isDark ? 'Passer au mode clair' : 'Passer au mode sombre',
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => RotationTransition(
          turns: anim,
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
          key: ValueKey(isDark),
          size: 20,
          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E293B),
        ),
      ),
      onTap: () {
        ref.read(themeModeProvider.notifier).toggleDarkMode(!isDark);
      },
    );
  }
}

/// Champ de texte neumorphique creusé (Pill Debossed TextField) avec affichage instantané du clavier
class NeumorphicTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;
  final bool autofocus;

  const NeumorphicTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  State<NeumorphicTextField> createState() => _NeumorphicTextFieldState();
}

class _NeumorphicTextFieldState extends State<NeumorphicTextField> {
  FocusNode? _internalFocusNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted && _isFocused != _effectiveFocusNode.hasFocus) {
      setState(() => _isFocused = _effectiveFocusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField;
    final textColor = isDark ? NeumorphicTheme.darkTextPrimary : NeumorphicTheme.lightTextPrimary;
    final hintColor = isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary;
    final iconColor = _isFocused
        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
        : (isDark ? const Color(0xFF7E8FA8) : const Color(0xFF6B7A99));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _isFocused
            ? [
                ...NeumorphicTheme.debossedShadows(isDark),
                BoxShadow(
                  color: (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF)).withOpacity(isDark ? 0.20 : 0.12),
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ]
            : NeumorphicTheme.debossedShadows(isDark),
        border: Border.all(
          color: _isFocused
              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E40AF))
              : (isDark
                  ? const Color(0xFF333333)
                  : const Color(0xFFE2E8F0)),
          width: _isFocused ? 1.4 : 1.2,
        ),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: hintColor.withOpacity(0.75),
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(widget.prefixIcon, color: iconColor, size: 21),
          suffixIcon: widget.suffixIcon,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

/// Bouton d'action principal dégradé avec cercle flèche blanche sur la droite
class NeumorphicGradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final bool showArrow;

  const NeumorphicGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    final btnGradient = gradient ?? NeumorphicTheme.primaryGradient;

    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: btnGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withOpacity(0.22),
            offset: const Offset(0, 4),
            blurRadius: 14,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showArrow) const SizedBox(width: 32), // Pour équilibrer le texte au centre
                Expanded(
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                if (showArrow)
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
