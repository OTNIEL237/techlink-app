import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/app_colors.dart';

class TrackingReviewCard extends StatefulWidget {
  final String missionId;
  final String technicianId;
  final String technicianName;
  final VoidCallback onRated;

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
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

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
