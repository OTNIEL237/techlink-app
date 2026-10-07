// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : tracking_review_card.dart
// Rôle          : Carte interactive d'évaluation et de dépôt d'avis (étoiles et commentaire)
//                 affichée à la fin d'une mission terminée pour noter le technicien.
// Module        : Présentation Client (Widgets Suivi de Mission)
// Dépendances   : flutter/material.dart, supabase_flutter, app_colors.dart
// Sécurité/RLS  : Insertion sécurisée dans la table `ratings` restreinte au
//                 client authentifié ayant participé à la mission.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';

/// Carte permettant au client de noter et commenter la prestation du technicien.
class TrackingReviewCard extends StatefulWidget {
  /// Identifiant de la mission terminée
  final String missionId;

  /// Identifiant de l'artisan / technicien évalué
  final String technicianId;

  /// Nom d'affichage du technicien
  final String technicianName;

  /// Callback exécuté suite à l'enregistrement réussi de la note
  final VoidCallback onRated;

  /// Constructeur constant de la carte d'avis de mission
  const TrackingReviewCard({
    super.key,
    required this.missionId,
    required this.technicianId,
    required this.technicianName,
    required this.onRated,
  });

  @override
  State<TrackingReviewCard> createState() => _TrackingReviewCardState();
}

class _TrackingReviewCardState extends State<TrackingReviewCard> {
  /// Note sélectionnée sur 5 étoiles (0 par défaut)
  int _rating = 0;

  /// Contrôleur du champ de saisie du commentaire facultatif
  final _commentController = TextEditingController();

  /// Indicateur d'enregistrement en cours dans Supabase
  bool _isSubmitting = false;

  /// Enregistre l'avis dans la table Supabase `ratings`
  Future<void> _submitReview() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner au moins une étoile.', style: TextStyle(color: Colors.white)), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final clientId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('ratings').insert({
        'mission_id': widget.missionId,
        'client_id': clientId,
        'technician_id': widget.technicianId,
        'score': _rating,
        'comment': _commentController.text.trim(),
      });
      widget.onRated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.stars_rounded, color: Colors.amber, size: 48),
          const SizedBox(height: 12),
          Text('Évaluez ${widget.technicianName}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: tc.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text('Comment s\'est passée l\'intervention ?',
            style: TextStyle(color: tc.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(
                  index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: Colors.amber,
                  size: 36,
                ),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Laissez un commentaire (facultatif)...',
              hintStyle: TextStyle(color: tc.textSecondary),
              filled: true,
              fillColor: tc.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Envoyer l\'avis', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
