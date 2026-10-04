import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;

// =========================================================================
// EFFET MORPHOSE STYLE POWERPOINT & ANIMATIONS FLUIDES PINTEREST (RhinoGraph)
// =========================================================================

/// Arrière-plan fluide et organique inspiré des animations Pinterest ✨
/// Les bulles et sphères lumineuses respirent et flottent avec des mouvements continus et doux.
/// Arrière-plan épuré et professionnel sans animation
/// Mode clair : Blanc pur professionnel (#FFFFFF)
/// Mode sombre : Noir VS Code professionnel (#1E1E1E)
class PinterestFluidBackground extends StatelessWidget {
  final Widget child;
  final bool showSpheres;
  final bool useSafeArea;

  const PinterestFluidBackground({
    super.key,
    required this.child,
    this.showSpheres = false,
    this.useSafeArea = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fond doux et reposant pour les yeux (zéro éblouissement blanc pur ni néon)
    final bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: bgColor,
      child: useSafeArea ? SafeArea(child: child) : child,
    );
  }
}

/// Carte interactive avec Effet Morphose (PowerPoint Morph) & Spring Physics
/// Lors du clic, la carte s'enfonce doucement avec retour tactile et se métamorphose.
class MorphingCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final dynamic borderRadius; // Supporte aussi bien `double` que `BorderRadiusGeometry`
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final List<BoxShadow>? shadows;
  final BoxBorder? border;

  const MorphingCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 24.0,
    this.padding,
    this.color,
    this.shadows,
    this.border,
  });

  @override
  State<MorphingCard> createState() => _MorphingCardState();
}

class _MorphingCardState extends State<MorphingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  BorderRadiusGeometry get _resolvedBorderRadius {
    if (widget.borderRadius is BorderRadiusGeometry) {
      return widget.borderRadius as BorderRadiusGeometry;
    } else if (widget.borderRadius is num) {
      return BorderRadius.circular((widget.borderRadius as num).toDouble());
    }
    return BorderRadius.circular(20);
  }

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    final resolvedRadius = _resolvedBorderRadius;

    if (widget.color != null || widget.shadows != null || widget.border != null || widget.padding != null) {
      content = Container(
        padding: widget.padding ?? const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: resolvedRadius,
          boxShadow: widget.shadows,
          border: widget.border,
        ),
        child: widget.child,
      );
    }

    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: content,
      ),
    );
  }
}

/// Transition de page fluide style PowerPoint Morphose (Morph Transition)
/// Morphose fluide qui fait grandir l'élément sélectionné avec une courbe cinématographique.
class PowerPointMorphRoute<T> extends PageRouteBuilder<T> {
  final Widget? page;
  final WidgetBuilder? builder;

  PowerPointMorphRoute({this.page, this.builder})
      : assert(page != null || builder != null, 'Either page or builder must be provided'),
        super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              page ?? builder!(context),
          transitionDuration: const Duration(milliseconds: 450),
          reverseTransitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Effet morphose : Combinaison de mise à l'échelle douce, fondu et translation
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastLinearToSlowEaseIn,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
                ),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Page GoRouter avec Effet Morphose PowerPoint
class PowerPointMorphPage<T> extends CustomTransitionPage<T> {
  PowerPointMorphPage({
    required super.child,
    super.key,
  }) : super(
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastLinearToSlowEaseIn,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
                ),
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.94, end: 1.0).animate(curvedAnimation),
                child: child,
              ),
            );
          },
        );
}

/// Widget de persistance d'état pour PageView et transitions d'onglets animées
class KeepAliveTab extends StatefulWidget {
  final Widget child;
  const KeepAliveTab({super.key, required this.child});

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

