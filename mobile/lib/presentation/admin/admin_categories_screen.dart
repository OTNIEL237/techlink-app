import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../shared/widgets/techlink_button.dart';
import '../shared/widgets/techlink_card.dart';
import '../shared/widgets/techlink_input.dart';

// =========================================================================
// ÉCRAN DE GESTION DES CATÉGORIES (ADMIN)
// =========================================================================
// Permet d'ajouter de nouvelles catégories de services et de les activer/désactiver.

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

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
