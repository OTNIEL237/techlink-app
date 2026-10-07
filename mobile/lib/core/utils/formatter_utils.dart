// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : formatter_utils.dart
// Rôle          : Fonctions utilitaires de formatage (monnaies FCFA, dates, téléphones).
//                 Standardise la présentation des nombres et dates en français.
// Module        : Core / Utilitaires
// Dépendances   : Aucune
// Sécurité/RLS  : Public / Utilitaire
// =============================================================================

/// [FormatterUtils]
///
/// Outils de formatage des valeurs numériques, temporelles et téléphoniques.
class FormatterUtils {
  /// Formate un montant en Francs CFA (ex: `25 000 FCFA`).
  ///
  /// - [amount] : Montant numérique à formater.
  /// - Retourne : Chaîne formatée avec séparateur d'espace et devise FCFA.
  static String formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    final len = str.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(str[i]);
    }
    return '${buffer.toString()} FCFA';
  }

  /// Formate un numéro de téléphone camerounais au format standard (+237 6XX XX XX XX).
  ///
  /// - [phone] : Chaîne brute du numéro de téléphone.
  /// - Retourne : Numéro formaté lisiblement.
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length >= 9) {
      final local = cleaned.substring(cleaned.length - 9);
      return '+237 ${local.substring(0, 3)} ${local.substring(3, 5)} ${local.substring(5, 7)} ${local.substring(7)}';
    }
    return phone;
  }

  /// Formate une date relative ou absolue en français.
  ///
  /// - [dateTime] : Objet DateTime à formater.
  /// - Retourne : Format lisible (ex: `Il y a 5 min` ou `07/10/2026`).
  static String formatDate(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }
}
