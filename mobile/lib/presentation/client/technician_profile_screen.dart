import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../data/services/zego_call_service.dart';
import '../shared/responsive_web_wrapper.dart';

// =========================================================================
// ÉCRAN DE PROFIL DU TECHNICIEN
// =========================================================================
// Affiche les informations complètes d'un technicien (À propos, Horaires, 
// Expérience, Avis). Permet de l'assigner à la mission en cours.

class TechnicianProfileScreen extends StatefulWidget {
  final Map<String, dynamic> technician;
  final String missionId;

  const TechnicianProfileScreen({
    super.key,
    required this.technician,
    required this.missionId,
  });

  @override
  State<TechnicianProfileScreen> createState() => _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = widget.technician['users'] as Map<String, dynamic>? ?? widget.technician;
    final name = user['name'] as String? ?? 'Technicien';
    final phone = user['phone'] as String? ?? '';
    final avatarUrl = user['avatar_url'] as String?;
    
    List<String> specialties = [];
    if (widget.technician['specialties'] is List) {
      specialties = List<String>.from(widget.technician['specialties'] as List);
    } else if (widget.technician['specialties'] is String) {
      specialties = [widget.technician['specialties'] as String];
    }
    
    final primarySpecialty = specialties.isNotEmpty ? specialties.first : 'Professionnel';
    final bio = widget.technician['bio'] as String? ?? 'Aucune biographie fournie pour le moment.';
    final experience = (widget.technician['experience_years'] as num?)?.toInt() ?? 0;
    final rating = (widget.technician['rating_average'] as num?)?.toDouble() ?? 0.0;
    final totalMissions = (widget.technician['total_missions'] as num?)?.toInt() ?? 0;
    final distanceKm = (widget.technician['distance_km'] as num?)?.toDouble();

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _buildTopAppBar(name, primarySpecialty, distanceKm, tc, isDark),
                const SizedBox(height: 10),
                _buildImageAndStats(name, avatarUrl, experience, rating, totalMissions, tc, isDark),
                const SizedBox(height: 16),
                _buildAboutTab(name, primarySpecialty, bio, phone, avatarUrl, tc, isDark),
                const Divider(height: 32),
                _buildAvailabilityTab(widget.technician['availability'] as Map<String, dynamic>?, tc, isDark),
                const Divider(height: 32),
                _buildExperienceTab(experience, specialties, tc, isDark),
                const Divider(height: 32),
                _buildReviewsTab(rating, totalMissions, tc, isDark),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(tc, isDark),
    );
  }

  Widget _buildTopAppBar(String name, String specialty, double? distanceKm, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: tc.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          Column(
            children: [
              Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: tc.textPrimary)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(specialty, style: TextStyle(fontSize: 13, color: tc.textSecondary, fontWeight: FontWeight.w500)),
                  if (distanceKm != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 10, color: AppColors.primary),
                          const SizedBox(width: 2),
                          Text(
                            distanceKm < 1.0 ? '${(distanceKm * 1000).toStringAsFixed(0)} m' : '${distanceKm.toStringAsFixed(1)} km',
                            style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.ios_share, size: 18, color: tc.textPrimary),
              onPressed: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAndStats(String name, String? avatarUrl, int experience, double rating, int missions, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            height: 320,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? tc.primaryLight : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(32),
              image: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? DecorationImage(
                      image: NetworkImage(avatarUrl), 
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (avatarUrl == null || avatarUrl.isEmpty)
                ? Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T', style: TextStyle(fontSize: 80, color: isDark ? tc.textPrimary : AppColors.primary, fontWeight: FontWeight.bold)))
                : null,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
              border: Border.all(color: Colors.grey.withOpacity(0.1), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatBox(rating.toStringAsFixed(1), 'Avis', Icons.star, Colors.amber.withOpacity(0.2), Colors.amber, tc, isDark),
                Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2)),
                _buildStatBox('$experience ans', 'Expérience', Icons.work, AppColors.primary.withOpacity(0.2), AppColors.primary, tc, isDark),
                Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2)),
                _buildStatBox(missions.toString(), 'Missions', Icons.task_alt, Colors.green.withOpacity(0.2), Colors.green, tc, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon, Color bgColor, Color iconColor, TechLinkColors tc, bool isDark) {
    return Container(
      width: 95,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: tc.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: tc.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTabBar(TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 45, bottom: 8, left: 8, right: 8),
      child: Container(
        height: 45,
        decoration: BoxDecoration(
          color: isDark ? tc.surface : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: isDark ? tc.textPrimary : AppColors.primary,
          unselectedLabelColor: tc.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          indicator: BoxDecoration(
            color: isDark ? tc.primaryLight : AppColors.primaryLight,
            borderRadius: BorderRadius.circular(30),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'À propos'),
            Tab(text: 'Disponibilité'),
            Tab(text: 'Expérience'),
            Tab(text: 'Avis'),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutTab(String name, String specialty, String bio, String phone, String? avatarUrl, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('À propos de $name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 12),
          Text(bio, style: TextStyle(color: tc.textSecondary, height: 1.5, fontSize: 14)),
          const SizedBox(height: 24),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isDark ? tc.primaryLight : AppColors.primaryLight,
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty) ? NetworkImage(avatarUrl) : null,
                child: (avatarUrl == null || avatarUrl.isEmpty) ? Text(name.isNotEmpty ? name[0] : 'T', style: TextStyle(color: isDark ? tc.textPrimary : AppColors.primary)) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
                    Text(specialty, style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  // Action pour chat si nécessaire
                },
                icon: Icon(Icons.chat_bubble_outline, color: isDark ? tc.textPrimary : AppColors.primary),
                style: IconButton.styleFrom(backgroundColor: isDark ? tc.primaryLight : AppColors.primaryLight),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ZegoCallService().startCall(
                    context,
                    receiverId: widget.technician['user_id'] as String,
                    receiverName: name,
                    callType: 'audio',
                  );
                },
                icon: const Icon(Icons.phone_outlined, color: AppColors.success),
                style: IconButton.styleFrom(backgroundColor: AppColors.success.withOpacity(0.1)),
                tooltip: 'Appel Audio',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  ZegoCallService().startCall(
                    context,
                    receiverId: widget.technician['user_id'] as String,
                    receiverName: name,
                    callType: 'video',
                  );
                },
                icon: const Icon(Icons.videocam_outlined, color: AppColors.primary),
                style: IconButton.styleFrom(backgroundColor: AppColors.primary.withOpacity(0.1)),
                tooltip: 'Appel Vidéo',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTab(Map<String, dynamic>? availability, TechLinkColors tc, bool isDark) {
    // Valeurs par défaut si le technicien n'a pas configuré sa disponibilité
    final Map<String, dynamic> schedule = availability ?? {
      'Lundi': '08:00 - 18:00',
      'Mardi': '08:00 - 18:00',
      'Mercredi': '08:00 - 18:00',
      'Jeudi': '08:00 - 18:00',
      'Vendredi': '08:00 - 18:00',
      'Samedi': '09:00 - 14:00',
      'Dimanche': 'Fermé',
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Horaires de travail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 16),
          ...schedule.entries.map((entry) {
            final day = entry.key;
            final hours = entry.value.toString();
            final isClosed = hours.toLowerCase() == 'fermé' || hours.toLowerCase() == 'closed';
            return _buildDayRow(day, hours, tc, isClosed: isClosed);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day, String hours, TechLinkColors tc, {bool isClosed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: tc.textPrimary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isClosed ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              hours,
              style: TextStyle(
                color: isClosed ? AppColors.error : AppColors.success,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceTab(int experience, List<String> specialties, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expérience Professionnelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.work_history, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Années d\'expérience', style: TextStyle(color: tc.textSecondary, fontSize: 13)),
                    Text('$experience ans', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Spécialités', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties.map((s) => Chip(
              label: Text(s, style: TextStyle(color: isDark ? tc.textPrimary : AppColors.primary)),
              backgroundColor: isDark ? tc.primaryLight : AppColors.primaryLight,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(double rating, int missions, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? tc.primaryLight : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : '5.0',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: isDark ? tc.textPrimary : AppColors.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (index) {
                          final fill = rating - index;
                          return Icon(
                            fill >= 1 ? Icons.star : (fill >= 0.5 ? Icons.star_half : Icons.star_border),
                            color: Colors.amber,
                            size: 24,
                          );
                        }),
                      ),
                      const SizedBox(height: 4),
                      Text('Basé sur $missions avis', style: TextStyle(color: tc.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('Avis récents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 16),
          missions > 0 
              ? _buildReviewItem('Client satisfait', 'Très professionnel et rapide !', 5.0, tc, isDark)
              : Text('Aucun avis pour le moment', style: TextStyle(color: tc.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildReviewItem(String author, String text, double rating, TechLinkColors tc, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? tc.surface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(author, style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 16,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(color: tc.textPrimary, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(TechLinkColors tc, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: tc.background,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Choisir ce technicien', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? tc.primaryLight : AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.star_outline, color: isDark ? tc.textPrimary : AppColors.primary),
                    onPressed: () {},
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