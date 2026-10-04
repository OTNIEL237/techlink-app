import 'package:flutter/material.dart';
import 'package:techlink/l10n/app_localizations.dart';
import '../../../../core/constants/app_colors.dart';

class TrackingTechnicianCard extends StatelessWidget {
  final Map<String, dynamic> technician;
  final VoidCallback onCall;
  final VoidCallback onVideoCall;
  const TrackingTechnicianCard({super.key, required this.technician, required this.onCall, required this.onVideoCall});

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final name = technician['name']?.toString() ?? 'Technicien';
    final phone = technician['phone']?.toString() ?? '';
    final rating = double.tryParse(technician['rating_average']?.toString() ?? '0') ?? 0.0;
    final missions = int.tryParse(technician['total_missions']?.toString() ?? '0') ?? 0;
    
    List<String> specialties = [];
    final specRaw = technician['specialties'];
    if (specRaw is List) {
      specialties = specRaw.map((e) => e.toString()).toList();
    } else if (specRaw is String) {
      specialties = [specRaw];
    }
    
    final avatarUrlRaw = technician['avatar_url']?.toString();
    final avatarUrl = (avatarUrlRaw != null && avatarUrlRaw.trim().isNotEmpty) ? avatarUrlRaw : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n?.yourTechnician ?? 'Votre technicien',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: tc.textPrimary)),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  color: isDark ? tc.primaryLight : AppColors.primaryLight,
                  shape: BoxShape.circle,
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: NetworkImage(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: avatarUrl == null
                    ? Center(
                        child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'T',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? tc.textPrimary : AppColors.primary)),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: tc.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (rating > 0) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          Text(' ${rating.toStringAsFixed(1)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            '$missions missions',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: tc.textSecondary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    if (specialties.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        specialties.take(2).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]
                  ],
                ),
              ),
              if (phone.isNotEmpty)
                Row(
                  children: [
                    Semantics(
                      label: 'Appeler le technicien en audio',
                      button: true,
                      child: GestureDetector(
                        onTap: onCall,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone, color: AppColors.success, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      label: 'Appeler le technicien en vidéo',
                      button: true,
                      child: GestureDetector(
                        onTap: onVideoCall,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam, color: AppColors.primary, size: 24),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
