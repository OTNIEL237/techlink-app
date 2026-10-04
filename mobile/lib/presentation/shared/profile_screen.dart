import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/theme/neumorphic_styles.dart';
import 'support_chat_screen.dart';

// =========================================================================
// ÉCRAN DE PROFIL PREMIUM & PERSONNALISÉ POUR CLIENT, TECHNICIEN & ADMIN
// =========================================================================

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _techData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final user = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      Map<String, dynamic>? tech;
      if (user?['role'] == 'technician') {
        tech = await Supabase.instance.client
            .from('technicians')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
      }

      if (mounted) {
        setState(() {
          _userData = user;
          _techData = tech;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLogoutModal() {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? tc.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: tc.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  'Déconnexion',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: tc.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Êtes-vous certain de vouloir vous déconnecter de TechLink ?',
                  style: TextStyle(
                    fontSize: 14,
                    color: tc.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: tc.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Annuler',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: tc.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);
                          await Supabase.instance.client.auth.signOut();
                          if (mounted) {
                            context.go('/login');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Déconnecter',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    final name = _userData?['name'] as String? ?? 'Utilisateur';
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'email@example.com';
    final phone = _userData?['phone'] as String? ?? '';
    final role = _userData?['role'] as String? ?? 'client';
    final avatarUrl = _userData?['avatar_url'] as String?;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: tc.background,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Mon Profil',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: tc.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ==========================================
                  // 1. CARTE HERO PROFIL (Personnalisée selon le rôle)
                  // ==========================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? tc.card : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: tc.border, width: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar avec bouton d'édition
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 46,
                              backgroundColor: AppColors.primary,
                              backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? CachedNetworkImageProvider(avatarUrl)
                                  : null,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: const TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            GestureDetector(
                              onTap: () {
                                if (role == 'technician') {
                                  context.push('/technician/profile/edit');
                                } else {
                                  context.push('/client/profile/edit');
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? tc.card : Colors.white,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Nom et email
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: tc.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: tc.textSecondary,
                          ),
                        ),
                        if (phone.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: tc.textSecondary.withOpacity(0.85),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // Badge de Rôle distinctif
                        _buildRoleBadge(role, isDark),

                        // Statistiques rapides si Technicien
                        if (role == 'technician' && _techData != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildQuickStat(
                                  'Expérience',
                                  '${_techData!['experience_years'] ?? 0} ans',
                                  Icons.work_history_rounded,
                                  tc,
                                ),
                                Container(width: 1, height: 26, color: tc.border),
                                _buildQuickStat(
                                  'Statut',
                                  _techData!['validation_status'] == 'approved' ? 'Vérifié' : 'En attente',
                                  Icons.verified_rounded,
                                  tc,
                                  highlightColor: _techData!['validation_status'] == 'approved'
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 2. SECTION ACTIVITÉS DÉDIÉE AU RÔLE
                  // ==========================================
                  _buildSectionHeader('Activité & Services', tc),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? tc.card : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tc.border, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        if (role == 'client') ...[
                          _buildListTileItem(
                            icon: Icons.receipt_long_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Mes Transactions & Factures',
                            subtitle: 'Historique des paiements Mobile Money',
                            tc: tc,
                            onTap: () => context.push('/client/transactions'),
                          ),
                          _buildDivider(tc),
                          _buildListTileItem(
                            icon: Icons.assignment_rounded,
                            iconColor: const Color(0xFF2563EB),
                            title: 'Mes Missions',
                            subtitle: 'Suivi de vos demandes et interventions',
                            tc: tc,
                            onTap: () => context.push('/client/history'),
                          ),
                        ] else if (role == 'technician') ...[
                          _buildListTileItem(
                            icon: Icons.card_membership_rounded,
                            iconColor: const Color(0xFF0891B2),
                            title: 'Mon Abonnement Pro',
                            subtitle: 'Gérer ma formule d\'accès',
                            tc: tc,
                            onTap: () => context.push('/technician/profile/subscription'),
                          ),
                          _buildDivider(tc),
                          _buildListTileItem(
                            icon: Icons.sensors_rounded,
                            iconColor: const Color(0xFF059669),
                            title: 'Disponibilité & Horaires',
                            subtitle: 'En ligne / Hors ligne et planning',
                            tc: tc,
                            onTap: () => context.push('/technician/availability'),
                          ),
                          _buildDivider(tc),
                          _buildListTileItem(
                            icon: Icons.account_balance_wallet_rounded,
                            iconColor: const Color(0xFF16A34A),
                            title: 'Mes Revenus & Versements',
                            subtitle: 'Solde et virements Mobile Money',
                            tc: tc,
                            onTap: () => context.push('/technician/earnings'),
                          ),
                          _buildDivider(tc),
                          _buildListTileItem(
                            icon: Icons.chat_bubble_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Mes Messages',
                            subtitle: 'Discussions avec vos clients',
                            tc: tc,
                            onTap: () => context.push('/technician/messages'),
                          ),
                        ] else ...[
                          _buildListTileItem(
                            icon: Icons.dashboard_rounded,
                            iconColor: const Color(0xFF7C3AED),
                            title: 'Tableau de bord Admin',
                            subtitle: 'Vue d\'ensemble de la plateforme',
                            tc: tc,
                            onTap: () => context.go('/admin/home'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 3. PARAMÈTRES DU COMPTE & PRÉFÉRENCES
                  // ==========================================
                  _buildSectionHeader('Paramètres & Préférences', tc),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? tc.card : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tc.border, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildListTileItem(
                          icon: Icons.badge_outlined,
                          iconColor: const Color(0xFF6366F1),
                          title: 'Modifier mes informations',
                          subtitle: 'Nom, téléphone et coordonnées',
                          tc: tc,
                          onTap: () async {
                            if (role == 'technician') {
                              final updated = await context.push('/technician/profile/edit');
                              if (updated == true && mounted) {
                                _loadProfile();
                              }
                            } else {
                              context.push('/client/profile/edit');
                            }
                          },
                        ),
                        _buildDivider(tc),
                        _buildListTileItem(
                          icon: Icons.notifications_none_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          title: 'Notifications & Alertes',
                          subtitle: 'Sons, rappels et messages push',
                          tc: tc,
                          onTap: () => context.push('/client/profile/notifications'),
                        ),
                        _buildDivider(tc),
                        _buildListTileItem(
                          icon: Icons.lock_outline_rounded,
                          iconColor: const Color(0xFF10B981),
                          title: 'Sécurité & Mot de passe',
                          subtitle: 'Mise à jour et double authentification',
                          tc: tc,
                          onTap: () => context.push('/client/profile/security'),
                        ),
                        _buildDivider(tc),
                        // Bascule Mode Sombre
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E293B)).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF1E293B),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mode Sombre (Dark Theme)',
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: tc.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      isDark ? 'Thème sombre actif (style VS Code)' : 'Thème clair actif (blanc pur)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: tc.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: isDark,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  HapticFeedback.lightImpact();
                                  ref.read(themeModeProvider.notifier).toggleDarkMode(val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ==========================================
                  // 4. ASSISTANCE & SUPPORT
                  // ==========================================
                  _buildSectionHeader('Assistance', tc),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? tc.card : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: tc.border, width: 0.8),
                    ),
                    child: Column(
                      children: [
                        _buildListTileItem(
                          icon: Icons.support_agent_rounded,
                          iconColor: const Color(0xFF1E3A8A),
                          title: 'Contacter le support TechLink',
                          subtitle: 'Assistance par messagerie instantanée',
                          tc: tc,
                          onTap: () {
                            final currentId = Supabase.instance.client.auth.currentUser?.id ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SupportChatScreen(
                                  conversationUserId: currentId,
                                  currentUserId: currentId,
                                  currentUserRole: role,
                                  otherUserName: 'Support TechLink',
                                ),
                              ),
                            );
                          },
                        ),
                        _buildDivider(tc),
                        _buildListTileItem(
                          icon: Icons.info_outline_rounded,
                          iconColor: const Color(0xFF64748B),
                          title: 'À propos de TechLink',
                          subtitle: 'Version 1.0.0 • Conditions & Confidentialité',
                          tc: tc,
                          trailing: const Text(
                            'v1.0.0',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==========================================
                  // 5. BOUTON DE DÉCONNEXION
                  // ==========================================
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showLogoutModal();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(isDark ? 0.15 : 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Se déconnecter',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleBadge(String role, bool isDark) {
    Color bg;
    Color text;
    String label;
    IconData icon;

    if (role == 'admin') {
      bg = const Color(0xFF7C3AED);
      text = Colors.white;
      label = '⚡ Administrateur Système';
      icon = Icons.admin_panel_settings_rounded;
    } else if (role == 'technician') {
      bg = const Color(0xFF0891B2);
      text = Colors.white;
      label = '🔧 Technicien Professionnel';
      icon = Icons.handyman_rounded;
    } else {
      bg = const Color(0xFF2563EB);
      text = Colors.white;
      label = '👤 Compte Particulier';
      icon = Icons.person_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg.withOpacity(isDark ? 0.25 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: bg.withOpacity(0.35), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: bg, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: bg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value, IconData icon, TechLinkColors tc, {Color? highlightColor}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: highlightColor ?? AppColors.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: tc.textSecondary),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: highlightColor ?? tc.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, TechLinkColors tc) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: tc.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTileItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required TechLinkColors tc,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: tc.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: tc.textSecondary,
        ),
      ),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: tc.textSecondary.withOpacity(0.7), size: 20),
    );
  }

  Widget _buildDivider(TechLinkColors tc) {
    return Divider(
      height: 1,
      thickness: 0.8,
      indent: 68,
      color: tc.border.withOpacity(0.6),
    );
  }
}