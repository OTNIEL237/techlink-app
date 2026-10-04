import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class TrackingQuoteCard extends StatelessWidget {
  final Map<String, dynamic> mission;
  final Map<String, dynamic> quote;
  final String status;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onPay;
  final bool isLoading;

  const TrackingQuoteCard({
    super.key,
    required this.mission,
    required this.quote,
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onPay,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    
    final linesList = quote['lines'];
    List<Map<String, dynamic>> lines = [];
    if (linesList is List) {
      for (var item in linesList) {
        if (item is Map) {
          lines.add(Map<String, dynamic>.from(item));
        }
      }
    }
    
    final subtotal = double.tryParse(quote['subtotal']?.toString() ?? '0') ?? 0.0;
    final total = subtotal;
    final quoteStatus = quote['status']?.toString() ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: quoteStatus == 'accepted'
              ? AppColors.success.withOpacity(0.4)
              : AppColors.warning.withOpacity(0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================== EN-TÊTE DEVIS ==================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: quoteStatus == 'accepted'
                  ? AppColors.success.withOpacity(0.08)
                  : AppColors.warning.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Icon(
                  quoteStatus == 'accepted' ? Icons.check_circle : Icons.receipt_long,
                  color: quoteStatus == 'accepted' ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    quoteStatus == 'accepted'
                        ? 'Devis accepté ✓'
                        : '📋 Devis reçu — Votre avis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: quoteStatus == 'accepted' ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================== LIGNES DU DEVIS ==================
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...lines.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              line['description'] as String? ?? '',
                              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: tc.textPrimary)),
                            Text(
                              'Qté: ${line['quantity']} × ${line['unit_price']} FCFA',
                              style: TextStyle(color: tc.textSecondary, fontSize: 11)),
                          ],
                        ),
                      ),
                      Text(
                        '${(line['total'] as num?)?.toStringAsFixed(0) ?? 0} F',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: tc.textPrimary)),
                    ],
                  ),
                )),

                const Divider(),
                _QuoteRow('Total à payer', '${total.toStringAsFixed(0)} FCFA',
                    isBold: true, color: AppColors.primary),
              ],
            ),
          ),

          // ================== BOUTONS (SI EN ATTENTE) ==================
          if (quoteStatus == 'pending')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onReject,
                      icon: const Icon(Icons.close, color: AppColors.error, size: 16),
                      label: const Text('Refuser', style: TextStyle(color: AppColors.error)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: isLoading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, color: Colors.white, size: 16),
                      label: const Text('Accepter le devis',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ Bouton Payer quand le devis est accepté mais non payé
          if (quoteStatus == 'accepted' && status != 'paid' && status != 'completed')
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ElevatedButton.icon(
                onPressed: onPay,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text(
                  '💳 Payer maintenant (MTN / Orange)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? color;
  const _QuoteRow(this.label, this.value,
      {this.isBold = false, this.color});

  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color ?? tc.textSecondary,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 15 : 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              color: color ?? tc.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }
}
