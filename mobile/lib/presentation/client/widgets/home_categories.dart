import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import '../../../../core/theme/neumorphic_styles.dart';
import '../../../../core/animations/morph_transitions.dart';

/// Modèle pour les cartes réalistes de catégories / missions
class CategoryCardData {
  final String slug;
  final String title;
  final String subtitle;
  final String missionsInfo;
  final String imageUrl;
  final IconData icon;
  final Color accentColor;
  final String activeCount;

  const CategoryCardData({
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.missionsInfo,
    required this.imageUrl,
    required this.icon,
    required this.accentColor,
    required this.activeCount,
  });
}

/// Carrousel 3D Ultra-Animé avec photos réalistes des missions & catégories
class ClientHomeCategories extends StatefulWidget {
  final List<Map<String, dynamic>> categories;

  const ClientHomeCategories({
    super.key,
    required this.categories,
  });

  @override
  State<ClientHomeCategories> createState() => _ClientHomeCategoriesState();
}

class _ClientHomeCategoriesState extends State<ClientHomeCategories> {
  late PageController _pageController;
  double _currentPage = 0.0;
  int _selectedChipIndex = 0;

  // Données des catégories avec photos ultra-réalistes et palette harmonisée TechLink
  static const List<CategoryCardData> _defaultCards = [
    CategoryCardData(
      slug: 'plomberie',
      title: 'Plomberie & Sanitaire',
      subtitle: 'Fuites, canalisations, robinetterie & chauffe-eau',
      missionsInfo: 'Dépannage express < 30 min',
      imageUrl: 'https://images.unsplash.com/photo-1585704032915-c3400ca199e7?auto=format&fit=crop&q=80&w=800',
      icon: Icons.plumbing_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '42 artisans en ligne',
    ),
    CategoryCardData(
      slug: 'electricite',
      title: 'Électricité & Domotique',
      subtitle: 'Tableaux, disjoncteurs, pannes & éclairages',
      missionsInfo: 'Artisans certifiés • Norme NF',
      imageUrl: 'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&q=80&w=800',
      icon: Icons.bolt_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '38 techniciens dispo',
    ),
    CategoryCardData(
      slug: 'climatisation',
      title: 'Climatisation & Froid',
      subtitle: 'Installation, recharge gaz, entretien filtres',
      missionsInfo: 'Spécialistes climatiseurs split',
      imageUrl: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?auto=format&fit=crop&q=80&w=800',
      icon: Icons.ac_unit_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '29 dépanneurs dispo',
    ),
    CategoryCardData(
      slug: 'electromenager',
      title: 'Électroménager',
      subtitle: 'Réfrigérateur, lave-linge, four & micro-ondes',
      missionsInfo: 'Diagnostic rapide & pièces d\'origine',
      imageUrl: 'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&q=80&w=800',
      icon: Icons.local_laundry_service_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '31 réparateurs actifs',
    ),
    CategoryCardData(
      slug: 'serrurerie',
      title: 'Serrurerie & Blindage',
      subtitle: 'Ouverture de porte, cylindre, serrures blindées',
      missionsInfo: 'Urgence 24h/7j sans dégradation',
      imageUrl: 'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&q=80&w=800',
      icon: Icons.lock_person_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '24 serruriers prêts',
    ),
    CategoryCardData(
      slug: 'peinture',
      title: 'Peinture & Décoration',
      subtitle: 'Peinture intérieure, murs, plafonds & ravalement',
      missionsInfo: 'Finitions impeccables & devis gratuit',
      imageUrl: 'https://images.unsplash.com/photo-1562259949-e8e7689d7828?auto=format&fit=crop&q=80&w=800',
      icon: Icons.format_paint_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '27 peintres disponibles',
    ),
    CategoryCardData(
      slug: 'menuiserie',
      title: 'Menuiserie & Bois',
      subtitle: 'Portes, placards, parquets & mobilier sur mesure',
      missionsInfo: 'Travail du bois sur-mesure de précision',
      imageUrl: 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?auto=format&fit=crop&q=80&w=800',
      icon: Icons.carpenter_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '19 menuisiers prêts',
    ),
    CategoryCardData(
      slug: 'informatique',
      title: 'Informatique & Réseaux',
      subtitle: 'Dépannage PC/Mac, box fibre, virus & logiciels',
      missionsInfo: 'Support sur site ou à distance',
      imageUrl: 'https://images.unsplash.com/photo-1597872200969-2b65d56bd16b?auto=format&fit=crop&q=80&w=800',
      icon: Icons.computer_rounded,
      accentColor: Color(0xFF1E3A8A),
      activeCount: '25 experts tech',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: 0.84,
      initialPage: 0,
    );
    _pageController.addListener(() {
      if (_pageController.page != null && mounted) {
        setState(() {
          _currentPage = _pageController.page!;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onCategoryTapped(CategoryCardData card) {
    HapticFeedback.lightImpact();
    context.push(
      '/client/problem',
      extra: {
        'category': card.slug,
        'category_name': card.title,
        'autofocus': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cards = _defaultCards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête de section avec titre premium & badge interactif
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)).withOpacity(0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'MISSIONS DISPONIBLES',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Nos Domaines d\'Intervention',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark
                          ? NeumorphicTheme.darkTextPrimary
                          : NeumorphicTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
              // Compteur animé
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: NeumorphicTheme.debossedShadows(isDark),
                ),
                child: Text(
                  '${cards.length} Métiers',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Barre de filtres rapides / Chips animés
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            itemBuilder: (context, idx) {
              final item = cards[idx];
              final isSelected = _selectedChipIndex == idx;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedChipIndex = idx);
                    _pageController.animateToPage(
                      idx,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFF1E40AF))
                          : (isDark ? const Color(0xFF252526) : Colors.white),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              )
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E3A8A))
                            : (isDark
                                ? const Color(0xFF333333)
                                : const Color(0xFFE2E8F0)),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.icon,
                          size: 15,
                          color: isSelected ? Colors.white : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.title.split(' ')[0], // Premier mot
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? NeumorphicTheme.darkTextPrimary
                                    : NeumorphicTheme.lightTextPrimary),
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

        const SizedBox(height: 16),

        // Carrousel 3D proportionné et léger avec cartes photographiques
        SizedBox(
          height: 270,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (idx) {
              if (_selectedChipIndex != idx) {
                setState(() => _selectedChipIndex = idx);
              }
            },
            itemBuilder: (context, index) {
              final card = cards[index];

              // Calcul de la transformation 3D (Scale, Translation & Parallaxe)
              final pageOffset = (index - _currentPage);
              final scale = (1.0 - (pageOffset.abs() * 0.08)).clamp(0.90, 1.03);
              final translateY = (pageOffset.abs() * 8.0);
              final opacity = (1.0 - (pageOffset.abs() * 0.25)).clamp(0.60, 1.0);
              final rotateY = (pageOffset * 0.04).clamp(-0.12, 0.12);

              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // perspective
                  ..rotateY(rotateY)
                  ..translate(0.0, translateY)
                  ..scale(scale),
                alignment: Alignment.center,
                child: Opacity(
                  opacity: opacity,
                  child: MorphingCard(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _onCategoryTapped(card),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.40 : 0.08),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. Image photographique réaliste en arrière-plan avec parallaxe
                            Positioned.fill(
                              left: pageOffset * -20,
                              right: pageOffset * 20,
                              child: CachedNetworkImage(
                                imageUrl: card.imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: card.accentColor,
                                    ),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: card.accentColor.withOpacity(0.2),
                                  child: Icon(card.icon, size: 40, color: card.accentColor),
                                ),
                              ),
                            ),

                            // 2. Dégradé sombre cinématique pour une lisibilité parfaite
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.30),
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.60),
                                    Colors.black.withOpacity(0.88),
                                  ],
                                  stops: const [0.0, 0.25, 0.55, 1.0],
                                ),
                              ),
                            ),

                            // 3. Badge en haut : Icône & Indicateur en direct
                            Positioned(
                              top: 14,
                              left: 14,
                              right: 14,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.50),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.25),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      card.icon,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF10B981),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          card.activeCount,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 4. Contenu inférieur : Titre, sous-titre et bouton d'action
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 14,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: card.accentColor.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      card.missionsInfo,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    card.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    card.subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          card.accentColor,
                                          card.accentColor.withOpacity(0.85),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: card.accentColor.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            'Demander une intervention',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // Indicateur de page animé (Dots stretch)
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(cards.length, (idx) {
              final distance = (idx - _currentPage).abs();
              final isCurrent = distance < 0.5;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isCurrent ? 24 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? cards[idx].accentColor
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: cards[idx].accentColor.withOpacity(0.5),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
