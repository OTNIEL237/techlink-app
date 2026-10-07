// =============================================================================
// FICHIER : admin_users_tab.dart
// RÔLE : Onglet de gestion unifiée des utilisateurs (Clients et Techniciens)
// MODULE : Présentation Administrateur (Admin Users)
// DÉPENDANCES : flutter/material.dart, app_colors.dart, admin_clients_screen.dart, technician_validation_screen.dart
// SÉCURITÉ / RLS : Réservé aux administrateurs (rôle admin requis)
// =============================================================================

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'admin_clients_screen.dart';
import 'technician_validation_screen.dart';

/// Onglet principal de gestion des comptes utilisateurs pour le portail administrateur.
///
/// Propose un sélecteur segmenté pour basculer aisément entre :
/// - La liste des clients ([AdminClientsScreen]).
/// - La liste et la validation des techniciens ([TechnicianValidationScreen]).
class AdminUsersTab extends StatefulWidget {
  /// Constructeur par défaut de [AdminUsersTab].
  const AdminUsersTab({super.key});

  @override
  State<AdminUsersTab> createState() => _AdminUsersTabState();
}

/// État associé à [AdminUsersTab] contrôlant l'animation de bascule entre sous-onglets.
class _AdminUsersTabState extends State<AdminUsersTab>
    with SingleTickerProviderStateMixin {
  /// Contrôleur gérant la transition entre la vue Clients et la vue Techniciens.
  late TabController _tabController;

  /// Index de l'onglet actif (0: Clients, 1: Techniciens).
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging ||
          _tabController.index != _currentIndex) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Modern Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? tc.surface : Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? tc.border : Colors.grey.shade200,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gestion des Utilisateurs',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: tc.textPrimary,
                              ),
                            ),
                            Text(
                              'Clients & Techniciens de la plateforme',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: tc.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Segmented Modern Control (Pill switch)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isDark ? tc.background : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? tc.border : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(0);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: _currentIndex == 0
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentIndex == 0
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_rounded,
                                    size: 18,
                                    color: _currentIndex == 0
                                        ? Colors.white
                                        : tc.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Clients',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _currentIndex == 0
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _currentIndex == 0
                                          ? Colors.white
                                          : tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              _tabController.animateTo(1);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeInOut,
                              decoration: BoxDecoration(
                                color: _currentIndex == 1
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                boxShadow: _currentIndex == 1
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.engineering_rounded,
                                    size: 18,
                                    color: _currentIndex == 1
                                        ? Colors.white
                                        : tc.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Techniciens',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: _currentIndex == 1
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: _currentIndex == 1
                                          ? Colors.white
                                          : tc.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tab Views for Clients & Technicians
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(), // tab switch only via header
                children: const [
                  AdminClientsScreen(showAppBar: false),
                  TechnicianValidationScreen(
                    filter: 'all',
                    showAppBar: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
