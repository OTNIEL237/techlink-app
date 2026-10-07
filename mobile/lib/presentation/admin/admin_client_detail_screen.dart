// =============================================================================
// FICHIER : admin_client_detail_screen.dart
// RÔLE : Fiche détaillée d'un utilisateur client, historique des commandes et gestion de compte (bannissement/édition)
// MODULE : Presentation / Admin
// DÉPENDANCES : flutter/material.dart, supabase_flutter, app_colors.dart
// SÉCURITÉ / RLS : Rôle administrateur requis. Lecture et modification des enregistrements dans `users` et `missions`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Écran d'administration présentant le dossier complet d'un client.
///
/// Affiche les coordonnées, les statistiques d'usage, l'historique complet des demandes
/// de mission avec les techniciens assignés, et permet l'édition ou le bannissement du compte.
class AdminClientDetailScreen extends StatefulWidget {
  /// Données initiales du profil client sélectionné.
  final Map<String, dynamic> client;

  /// Constructeur constant du widget [AdminClientDetailScreen].
  const AdminClientDetailScreen({super.key, required this.client});

  @override
  State<AdminClientDetailScreen> createState() => _AdminClientDetailScreenState();
}

/// État associé à l'écran de consultation et gestion du profil client.
///
/// Gère le chargement des missions passées, l'inversion du statut de bannissement (`is_banned`),
/// et l'édition directe des informations nominatives.
class _AdminClientDetailScreenState extends State<AdminClientDetailScreen> {
  /// Liste des interventions commandées par le client.
  List<Map<String, dynamic>> _missions = [];

  /// Indicateur de chargement asynchrone des données.
  bool _isLoading = true;

  /// Statut de bannissement actuel du client sur la plateforme.
  bool _isBanned = false;

  /// Données mutables du client synchronisées localement.
  late Map<String, dynamic> _client;

  @override
  void initState() {
    super.initState();
    _client = Map<String, dynamic>.from(widget.client);
    _isBanned = _client['is_banned'] ?? false;
    _loadClientHistory();
  }

  /// Charge l'historique de toutes les missions passées du client avec les relations métier associées.
  Future<void> _loadClientHistory() async {
    try {
      final data = await Supabase.instance.client
          .from('missions')
          .select('*, categories(name), technicians:technician_id(name)')
          .eq('client_id', _client['id'])
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _missions = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print('Erreur chargement historique: $e');
    }
  }

  /// Bascule le statut de bannissement du client (`is_banned`) dans la table `users`.
  Future<void> _toggleBan() async {
    final newStatus = !_isBanned;
    try {
      await Supabase.instance.client
          .from('users')
          .update({'is_banned': newStatus})
          .eq('id', _client['id']);

      if (mounted) {
        setState(() {
          _isBanned = newStatus;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'Client banni' : 'Client débanni'),
            backgroundColor: newStatus ? AppColors.error : AppColors.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  /// Construit la fiche client avec résumé d'identité, actions de modération et historique d'interventions.
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        title: const Text('Détails Client', style: TextStyle(color: Colors.white)),
        backgroundColor: isDark ? tc.surface : const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditClientDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profil
                  Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: isDark ? tc.primaryLight : AppColors.primaryLight,
                      child: const Icon(Icons.person, size: 40, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      _client['name'] ?? 'Client sans nom',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: tc.textPrimary),
                    ),
                  ),
                  Center(
                    child: Text(
                      _client['phone'] ?? 'Pas de numéro',
                      style: TextStyle(fontSize: 16, color: tc.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _toggleBan,
                      icon: Icon(_isBanned ? Icons.check_circle : Icons.block),
                      label: Text(_isBanned ? 'Débannir le client' : 'Bannir le client'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isBanned ? AppColors.success : AppColors.error,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Text('Historique des missions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: tc.textPrimary)),
                  const SizedBox(height: 16),

                  _missions.isEmpty
                      ? Text('Aucune mission effectuée.', style: TextStyle(color: tc.textSecondary))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _missions.length,
                          itemBuilder: (context, index) {
                            final m = _missions[index];
                            final cat = m['categories']?['name'] ?? 'Service';
                            final status = m['status'] ?? 'pending';
                            final tech = m['technicians']?['name'] ?? 'Aucun';

                            Color statusColor = AppColors.textSecondary;
                            if (status == 'pending') statusColor = AppColors.warning;
                            if (status == 'in_progress') statusColor = Colors.blue;
                            if (status == 'completed' || status == 'paid') statusColor = AppColors.success;
                            if (status == 'cancelled') statusColor = AppColors.error;

                            return Card(
                              color: isDark ? tc.surface : Colors.white,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: isDark ? tc.border : Colors.transparent),
                              ),
                              child: ListTile(
                                title: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(cat, style: TextStyle(fontWeight: FontWeight.bold, color: tc.textPrimary)),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                subtitle: Text('Technicien: $tech\nProblème: ${m['problem_description']}', style: TextStyle(color: tc.textSecondary)),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  /// Ouvre un dialogue modal permettant à l'administrateur de rectifier le nom ou le numéro de téléphone du client.
  Future<void> _showEditClientDialog() async {
    final nameController = TextEditingController(text: _client['name'] ?? '');
    final phoneController = TextEditingController(text: _client['phone'] ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: const Text('Modifier le client'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
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

        await Supabase.instance.client
            .from('users')
            .update({
              'name': newName,
              'phone': newPhone,
            })
            .eq('id', _client['id']);

        if (mounted) {
          setState(() {
            _client['name'] = newName;
            _client['phone'] = newPhone;
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour avec succès'),
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
