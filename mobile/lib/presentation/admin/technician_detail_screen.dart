import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';

// =========================================================================
// ÉCRAN DE DÉTAILS D'UN TECHNICIEN (ADMIN)
// =========================================================================
// Affiche le profil complet d'un technicien (informations, disponibilité,
// expérience, avis, documents) et permet de l'approuver, de le suspendre
// ou de modifier ses informations.

class TechnicianDetailScreen extends StatefulWidget {
  final Map<String, dynamic> technician;
  const TechnicianDetailScreen({super.key, required this.technician});

  @override
  State<TechnicianDetailScreen> createState() => _TechnicianDetailScreenState();
}

class _TechnicianDetailScreenState extends State<TechnicianDetailScreen> with SingleTickerProviderStateMixin {
  late Map<String, dynamic> _technician;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _technician = widget.technician;
    _tabController = TabController(length: 5, vsync: this);
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    try {
      final docs = await Supabase.instance.client
          .from('technician_documents')
          .select()
          .eq('technician_id', _technician['id']);

      if (mounted) {
        setState(() => _documents = List<Map<String, dynamic>>.from(docs));
      }
    } catch (_) {}
  }

  Future<void> _validate(String action) async {
    setState(() => _isLoading = true);

    try {
      String status = 'pending';
      if (action == 'approve') status = 'approved';
      if (action == 'reject') status = 'rejected';
      if (action == 'suspend') status = 'suspended';

      await Supabase.instance.client
          .from('technicians')
          .update({
            'validation_status': status,
            'is_verified': action == 'approve',
            'status': 'offline',
          })
          .eq('id', _technician['id']);

      await Supabase.instance.client.from('admin_logs').insert({
        'admin_id': Supabase.instance.client.auth.currentUser!.id,
        'action': action == 'approve' ? 'technician_approved' : action == 'suspend' ? 'technician_suspended' : 'technician_rejected',
        'target_id': _technician['id'],
        'details': {'technician_name': _technician['users']?['name'] ?? ''},
      });

      setState(() => _technician = {
            ..._technician,
            'validation_status': status,
            'is_verified': action == 'approve',
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(action == 'approve' ? '✅ Technicien approuvé avec succès !' : action == 'suspend' ? '⚠️ Technicien suspendu' : '❌ Technicien rejeté'),
            backgroundColor: action == 'approve' ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = _technician['users'] as Map<String, dynamic>?;
    final name = user?['name'] as String? ?? 'Technicien';
    final phone = user?['phone'] as String? ?? '';
    final email = user?['email'] as String? ?? '';
    final avatarUrl = user?['avatar_url'] as String?;
    
    final specialties = List<String>.from(_technician['specialties'] as List? ?? []);
    final primarySpecialty = specialties.isNotEmpty ? specialties.first : 'Professionnel';
    final bio = _technician['bio'] as String? ?? 'Aucune biographie fournie pour le moment.';
    final experience = (_technician['experience_years'] as num?)?.toInt() ?? 0;
    final rating = (_technician['rating_average'] as num?)?.toDouble() ?? 0.0;
    final totalMissions = (_technician['total_missions'] as num?)?.toInt() ?? 0;
    final status = _technician['validation_status'] as String? ?? 'pending';

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(name, primarySpecialty, tc, isDark),
            const SizedBox(height: 10),
            _buildImageAndStats(name, avatarUrl, experience, rating, totalMissions, tc, isDark),
            const SizedBox(height: 8),
            _buildTabBar(tc, isDark),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAboutTab(name, primarySpecialty, bio, phone, email, avatarUrl, tc, isDark),
                  _buildAvailabilityTab(_technician['availability'] as Map<String, dynamic>?, tc, isDark),
                  _buildExperienceTab(experience, specialties, tc, isDark),
                  _buildReviewsTab(rating, totalMissions, tc, isDark),
                  _buildDocumentsTab(tc, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildAdminBottomBar(status, tc, isDark),
    );
  }

  Widget _buildTopAppBar(String name, String specialty, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.border),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, size: 18, color: tc.textPrimary),
              onPressed: () => context.pop(),
            ),
          ),
          Column(
            children: [
              Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
              Text(specialty, style: TextStyle(fontSize: 13, color: tc.textSecondary)),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? tc.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tc.border),
            ),
            child: IconButton(
              icon: Icon(Icons.edit, size: 18, color: tc.textPrimary),
              onPressed: _showEditTechnicianDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAndStats(String name, String? avatarUrl, int experience, double rating, int missions, TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? tc.primaryLight : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(32),
              image: avatarUrl != null
                  ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                  : null,
            ),
            child: avatarUrl == null
                ? Center(child: Text(name[0].toUpperCase(), style: TextStyle(fontSize: 80, color: isDark ? tc.textPrimary : AppColors.primary, fontWeight: FontWeight.bold)))
                : null,
          ),
          Positioned(
            bottom: -25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? tc.card : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.08), blurRadius: 15, offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStatBox('$experience ans', 'Expérience', Icons.work, isDark ? Colors.red.withOpacity(0.2) : const Color(0xFFFEE2E2), const Color(0xFFDC2626), tc, isDark),
                  const SizedBox(width: 8),
                  _buildStatBox(rating > 0 ? rating.toStringAsFixed(1) : 'Nouveau', 'Note', Icons.star, isDark ? AppColors.primary.withOpacity(0.2) : const Color(0xFFE0E7FF), AppColors.primary, tc, isDark),
                  const SizedBox(width: 8),
                  _buildStatBox('$missions+', 'Missions', Icons.task_alt, isDark ? Colors.amber.withOpacity(0.2) : const Color(0xFFFEF3C7), const Color(0xFFD97706), tc, isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, IconData icon, Color bgColor, Color iconColor, TechLinkColors tc, bool isDark) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tc.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10, color: tc.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildTabBar(TechLinkColors tc, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 8),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: isDark ? tc.textPrimary : AppColors.primary,
        unselectedLabelColor: tc.textSecondary,
        indicator: BoxDecoration(
          color: isDark ? tc.primaryLight : AppColors.primaryLight,
          borderRadius: BorderRadius.circular(24),
        ),
        indicatorPadding: const EdgeInsets.symmetric(horizontal: -16, vertical: 4),
        tabs: const [
          Tab(text: 'À propos'),
          Tab(text: 'Disponibilité'),
          Tab(text: 'Expérience'),
          Tab(text: 'Avis'),
          Tab(text: 'Documents'),
        ],
      ),
    );
  }

  Widget _buildAboutTab(String name, String specialty, String bio, String phone, String email, String? avatarUrl, TechLinkColors tc, bool isDark) {
    final mtn = _technician['mtn_number'] as String? ?? '';
    final orange = _technician['orange_number'] as String? ?? '';
    
    return SingleChildScrollView(
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
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null ? Text(name[0], style: TextStyle(color: isDark ? tc.textPrimary : AppColors.primary)) : null,
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
            ],
          ),
          const SizedBox(height: 24),
          Text('Coordonnées', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 12),
          _DetailRow(Icons.email_outlined, 'Email', email, tc),
          _DetailRow(Icons.phone_outlined, 'Téléphone', phone, tc),
          const SizedBox(height: 24),
          Text('Paiement Mobile Money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 12),
          if (mtn.isNotEmpty) _DetailRow(Icons.phone_android, 'MTN Money', mtn, tc),
          if (orange.isNotEmpty) _DetailRow(Icons.phone_android, 'Orange Money', orange, tc),
        ],
      ),
    );
  }

  Widget _buildAvailabilityTab(Map<String, dynamic>? availability, TechLinkColors tc, bool isDark) {
    final Map<String, dynamic> schedule = availability ?? {
      'Lundi': '08:00 - 18:00',
      'Mardi': '08:00 - 18:00',
      'Mercredi': '08:00 - 18:00',
      'Jeudi': '08:00 - 18:00',
      'Vendredi': '08:00 - 18:00',
      'Samedi': '09:00 - 14:00',
      'Dimanche': 'Fermé',
    };

    return SingleChildScrollView(
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
    return SingleChildScrollView(
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
    return SingleChildScrollView(
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
              ? Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: isDark ? tc.surface : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: tc.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Client satisfait', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
                          Row(children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.amber, size: 16))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Très professionnel et rapide !', style: TextStyle(color: tc.textPrimary, height: 1.4)),
                    ],
                  ),
                )
              : Text('Aucun avis pour le moment', style: TextStyle(color: tc.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab(TechLinkColors tc, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Documents d\'identité et professionnels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
          const SizedBox(height: 16),
          if (_documents.isEmpty)
             Text('Aucun document fourni', style: TextStyle(color: tc.textSecondary))
          else
            ..._documents.map((doc) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? tc.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tc.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description, color: AppColors.primary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(doc['document_type'] as String? ?? 'Document', style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
                            const SizedBox(height: 4),
                            Text(
                              (doc['is_verified'] as bool? ?? false) ? 'Vérifié' : 'À vérifier',
                              style: TextStyle(
                                color: (doc['is_verified'] as bool? ?? false) ? AppColors.success : AppColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.download),
                        color: tc.textSecondary,
                        onPressed: () async {
                          final url = doc['file_url'] as String?;
                          if (url != null && url.isNotEmpty) {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
                                );
                              }
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Aucun lien disponible pour ce document')),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                )).toList(),
        ],
      ),
    );
  }

  Widget _buildAdminBottomBar(String status, TechLinkColors tc, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: tc.background,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status == 'pending') ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _validate('reject'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text('Rejeter', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => _validate('approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.verified),
                            label: const Text('Approuver', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (status == 'approved') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _validate('suspend'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.block),
                        label: const Text('Suspendre le technicien', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                  if (status == 'suspended' || status == 'rejected') ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _validate('approve'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.restore),
                        label: const Text('Réactiver / Approuver', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _showEditTechnicianDialog() async {
    final user = _technician['users'] as Map<String, dynamic>?;
    final nameController = TextEditingController(text: user?['name'] as String? ?? '');
    final phoneController = TextEditingController(text: user?['phone'] as String? ?? '');
    final bioController = TextEditingController(text: _technician['bio'] as String? ?? '');
    final expController = TextEditingController(text: (_technician['experience_years']?.toString()) ?? '0');
    final mtnController = TextEditingController(text: _technician['mtn_number'] as String? ?? '');
    final orangeController = TextEditingController(text: _technician['orange_number'] as String? ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('Modifier le technicien'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Informations Personnelles', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: 'Nom complet', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: 'Téléphone', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                const Text('Profil Professionnel', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: expController,
                  decoration: InputDecoration(labelText: 'Années d\'expérience', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  decoration: InputDecoration(labelText: 'Biographie', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const Text('Paiement Mobile', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: mtnController,
                  decoration: InputDecoration(labelText: 'MTN Mobile Money', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orangeController,
                  decoration: InputDecoration(labelText: 'Orange Money', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final newName = nameController.text.trim();
        final newPhone = phoneController.text.trim();
        final newBio = bioController.text.trim();
        final newExp = int.tryParse(expController.text.trim()) ?? 0;
        final newMtn = mtnController.text.trim();
        final newOrange = orangeController.text.trim();

        // Update Users table
        await Supabase.instance.client
            .from('users')
            .update({
              'name': newName,
              'phone': newPhone,
            })
            .eq('id', _technician['id']);

        // Update Technicians table
        await Supabase.instance.client
            .from('technicians')
            .update({
              'bio': newBio,
              'experience_years': newExp,
              'mtn_number': newMtn,
              'orange_number': newOrange,
            })
            .eq('id', _technician['id']);

        if (mounted) {
          setState(() {
            _technician['users']['name'] = newName;
            _technician['users']['phone'] = newPhone;
            _technician['bio'] = newBio;
            _technician['experience_years'] = newExp;
            _technician['mtn_number'] = newMtn;
            _technician['orange_number'] = newOrange;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil technicien mis à jour avec succès'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la mise à jour : $e'), backgroundColor: AppColors.error),
          );
        }
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TechLinkColors tc;
  const _DetailRow(this.icon, this.label, this.value, this.tc);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(color: tc.textSecondary, fontSize: 14)),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: tc.textPrimary))),
        ],
      ),
    );
  }
}