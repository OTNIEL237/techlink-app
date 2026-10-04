import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:techlink/l10n/app_localizations.dart';
import '../../../../core/theme/neumorphic_styles.dart';
import '../../../../core/animations/morph_transitions.dart';

class ClientHomePopularServices extends StatelessWidget {
  final List<Map<String, dynamic>> popularTechnicians;

  const ClientHomePopularServices({
    super.key,
    required this.popularTechnicians,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    if (popularTechnicians.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l10n?.popularServicesTitle ?? 'Artisans Élite à Proximité',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark
                        ? NeumorphicTheme.darkTextPrimary
                        : NeumorphicTheme.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/client/problem'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir tout',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Liste horizontale d'artisans avec cartes Morphose (PowerPoint Morph)
          SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: popularTechnicians.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                return _TechnicianMorphCard(
                  technician: popularTechnicians[index],
                  isDark: isDark,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TechnicianMorphCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final bool isDark;

  const _TechnicianMorphCard({
    required this.technician,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final user = technician['users'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Technicien Pro';
    final avatarUrl = user?['avatar_url'] as String?;

    List<String> specialties = [];
    final specRaw = technician['specialties'];
    if (specRaw is List) {
      specialties = specRaw.map((e) => e.toString()).toList();
    } else if (specRaw is String) {
      specialties = [specRaw];
    }
    final primarySpecialty = specialties.isNotEmpty ? specialties.first : 'Artisan Qualifié';
    final rating = (technician['rating_average'] as num?)?.toDouble() ?? 4.9;
    final reviewCount = (technician['total_missions'] as num?)?.toInt() ?? 12;

    final cardBg = isDark ? NeumorphicTheme.darkCard : NeumorphicTheme.lightCard;

    return MorphingCard(
      borderRadius: 24,
      color: cardBg,
      shadows: NeumorphicTheme.embossedShadows(isDark, depth: 5, blur: 12),
      border: Border.all(
        color: isDark
            ? const Color(0xFF283656).withOpacity(0.4)
            : Colors.white.withOpacity(0.9),
        width: 1.2,
      ),
      padding: const EdgeInsets.all(14),
      onTap: () {
        context.push('/client/problem', extra: {
          'technician_id': technician['id'],
          'technician_name': name,
          'autofocus': true,
        });
      },
      child: SizedBox(
        width: 137,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar avec badge distance
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2843) : const Color(0xFFE2EDF9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: NeumorphicTheme.embossedShadows(isDark, depth: 3, blur: 6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            errorWidget: (context, error, stackTrace) => _buildInitials(name),
                          )
                        : _buildInitials(name),
                  ),
                ),
                Positioned(
                  top: -4,
                  right: -10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.white, size: 10),
                        SizedBox(width: 2),
                        Text(
                          'Proche',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Nom
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: isDark
                    ? NeumorphicTheme.darkTextPrimary
                    : NeumorphicTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 2),

            // Spécialité
            Text(
              primarySpecialty,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? NeumorphicTheme.darkTextSecondary
                    : NeumorphicTheme.lightTextSecondary,
              ),
            ),
            const Spacer(),

            // Étoiles et avis
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2843) : const Color(0xFFEFF5FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 3),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : '4.9',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? NeumorphicTheme.darkTextPrimary
                          : NeumorphicTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '($reviewCount)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: isDark
                          ? NeumorphicTheme.darkTextSecondary
                          : NeumorphicTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitials(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'T',
        style: const TextStyle(
          color: Color(0xFF1E3A8A),
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }
}
