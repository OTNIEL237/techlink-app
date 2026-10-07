// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : help_center_screen.dart
// Rôle          : Écran du centre d'aide et support pour le client. Propose un
//                 onglet FAQ avec filtrage par catégorie et un onglet Contact.
// Module        : Présentation Client (Profil / Centre d'aide)
// Dépendances   : flutter/material.dart, go_router, app_colors.dart
// Sécurité/RLS  : Accès public / client sans restriction sensible.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

/// Écran du centre d'aide et de foire aux questions (FAQ) avec canaux de contact.
class HelpCenterScreen extends StatefulWidget {
  /// Constructeur constant de l'écran du centre d'aide
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> with SingleTickerProviderStateMixin {
  /// Contrôleur des onglets de navigation (FAQ et Contact)
  late TabController _tabController;

  /// Index de la catégorie sélectionnée dans l'onglet FAQ
  int _selectedCategoryIndex = 0;

  /// Liste des thématiques disponibles pour filtrer les questions
  final List<String> _categories = ['General', 'Account', 'Service', 'Payment'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help Center', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'FAQ'),
            Tab(text: 'Contact Us'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFaqTab(),
          _buildContactUsTab(),
        ],
      ),
    );
  }

  /// Construit la vue de l'onglet FAQ avec catégories et accordéons de réponses
  Widget _buildFaqTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Categories
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        _categories[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          
          // Search
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Search...',
                icon: Icon(Icons.search, color: AppColors.primary),
                suffixIcon: Icon(Icons.tune, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Items
          _buildFaqItem('What is TechLink?', 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.', isExpanded: true),
          _buildFaqItem('How to use TechLink?', ''),
          _buildFaqItem('How do I cancel a booking?', ''),
          _buildFaqItem('Is TechLink free to use?', ''),
          _buildFaqItem('How to make a payment?', ''),
        ],
      ),
    );
  }

  /// Construit un élément déroulant accordéon pour une question fréquente
  Widget _buildFaqItem(String title, String content, {bool isExpanded = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        initiallyExpanded: isExpanded,
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.primary,
        shape: const Border(),
        children: content.isNotEmpty
            ? [
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                  child: Text(
                    content,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  /// Construit l'onglet répertoriant les options de contact du support
  Widget _buildContactUsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildContactOption(Icons.headset_mic, 'Customer Service', onTap: () {
            context.push('/client/profile/customer_service');
          }),
          _buildContactOption(Icons.chat, 'WhatsApp'),
          _buildContactOption(Icons.language, 'Website'),
          _buildContactOption(Icons.facebook, 'Facebook'),
          _buildContactOption(Icons.alternate_email, 'Twitter'),
          _buildContactOption(Icons.camera_alt, 'Instagram'),
        ],
      ),
    );
  }

  /// Construit une tuile d'option de contact direct (réseau social, chat ou web)
  Widget _buildContactOption(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: onTap ?? () {},
      ),
    );
  }
}
