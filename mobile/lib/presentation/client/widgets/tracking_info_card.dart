import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TrackingInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const TrackingInfoCard({super.key, required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: tc.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: tc.border),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
