// =============================================================================
// FICHIER : admin_categories_screen.dart
// RÔLE : Gestion administrative du référentiel des catégories de métiers / services
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, go_router, supabase_flutter, app_colors.dart, theme_provider.dart, techlink_widgets
// SÉCURITÉ / RLS : Rôle administrateur requis. Lecture, insertion et activation/désactivation dans la table `categories`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_card.dart';
import '../shared/widgets/techlink_input.dart';

/// Écran administrateur de configuration des catégories de prestations.
///
/// Permet de consulter l'ensemble des corps de métier référencés, d'activer ou désactiver
/// une catégorie en direct, et d'enregistrer de nouveaux types d'interventions.
class AdminCategoriesScreen extends StatefulWidget {
  /// Constructeur constant du widget [AdminCategoriesScreen].
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

/// État associé à l'écran de gestion des catégories.
///
/// Gère le chargement de la table `categories`, la boîte de dialogue modale de création
/// et la mise à jour du champ `is_active`.
class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  /// Liste des catégories chargées depuis la base de données.
  List<Map<String, dynamic>> _categories = [];

  /// Indicateur de chargement asynchrone des catégories.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  /// Charge l'ensemble des catégories ordonnées par ordre alphabétique.
  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('categories')
          .select()
          .order('name');
      
      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur: $e');
    }
  }

  /// Inverse le statut d'activation (`is_active`) d'une catégorie donnée.
  Future<void> _toggleCategoryStatus(int id, bool currentStatus) async {
    try {
      await Supabase.instance.client
          .from('categories')
          .update({'is_active': !currentStatus})
          .eq('id', id);
      _loadCategories();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  /// Affiche la boîte de dialogue modale permettant de créer une nouvelle catégorie de service.
  void _showAddCategoryDialog() {
    final nameController = TextEditingController();
    final iconController = TextEditingController(text: 'build');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final tc = Theme.of(context).extension<TechLinkColors>()!;
          return AlertDialog(
            backgroundColor: tc.surface,
            title: Text('Nouvelle Catégorie', style: TextStyle(color: tc.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TechLinkInput(
                  label: 'Nom de la catégorie',
                  controller: nameController,
                ),
                const SizedBox(height: 16),
                TechLinkInput(
                  label: 'Nom de l\'icône (ex: build)',
                  controller: iconController,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TechLinkButton(
                text: 'Ajouter',
                onPressed: isSaving ? null : () async {
                  if (nameController.text.trim().isEmpty) return;
                  setDialogState(() => isSaving = true);
                  try {
                    await Supabase.instance.client.from('categories').insert({
                      'name': nameController.text.trim(),
                      'icon_name': iconController.text.trim(),
                      'is_active': true,
                    });
                    if (context.mounted) context.pop();
                    _loadCategories();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
                    setDialogState(() => isSaving = false);
                  }
                },
                isLoading: isSaving,
              ),
            ],
          );
        },
      ),
    );
  }

  /// Construit la vue de liste des catégories avec commutateurs d'activation et FAB d'ajout.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Catégories', style: TextStyle(color: Colors.white)),
        backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('Aucune catégorie trouvée.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isActive = cat['is_active'] ?? true;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TechLinkCard(
                        padding: const EdgeInsets.all(8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isActive ? AppColors.primary.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                            child: Icon(Icons.category, color: isActive ? AppColors.primary : Colors.grey),
                          ),
                          title: Text(cat['name'], style: TextStyle(
                            decoration: isActive ? TextDecoration.none : TextDecoration.lineThrough,
                            color: isActive ? tc.textPrimary : tc.textSecondary,
                          )),
                          subtitle: Text('Icône: ${cat['icon_name'] ?? 'build'}', style: TextStyle(color: tc.textSecondary)),
                          trailing: Switch(
                            value: isActive,
                            onChanged: (val) => _toggleCategoryStatus(cat['id'], isActive),
                            activeColor: AppColors.success,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCategoryDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
