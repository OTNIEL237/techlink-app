// =============================================================================
// FICHIER : quote_builder_screen.dart
// RÔLE : Éditeur et générateur de devis d'intervention par le technicien
// MODULE : Presentation / Technician
// DÉPENDANCES : flutter/material.dart, go_router, supabase_flutter, app_colors.dart
// SÉCURITÉ / RLS : Authentification technicien requise. Insertion sécurisée dans 'quotes' et transition d'état de 'missions' vers 'quote_sent'.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

/// Écran permettant au technicien de formaliser et chiffrer un devis d'intervention.
///
/// Permet de détailler les coûts par type (main d'œuvre, pièces détachées, frais de déplacement),
/// d'ajuster les quantités et montants unitaires, et de soumettre la proposition financière au client.
class QuoteBuilderScreen extends StatefulWidget {
  /// Données complètes de la mission ciblée par le devis.
  final Map<String, dynamic> mission;

  /// Constructeur constant du widget [QuoteBuilderScreen].
  const QuoteBuilderScreen({super.key, required this.mission});

  @override
  State<QuoteBuilderScreen> createState() => _QuoteBuilderScreenState();
}

/// État associé à l'éditeur de devis technicien.
///
/// Gère la collection des lignes tarifaires, le calcul en temps réel du sous-total
/// et du net artisan, ainsi que l'enregistrement du devis dans Supabase.
class _QuoteBuilderScreenState extends State<QuoteBuilderScreen> {
  /// Liste des postes de dépenses / prestations composant le devis.
  final List<Map<String, dynamic>> _lines = [];

  /// Indicateur d'opération asynchrone d'envoi en cours.
  bool _isSending = false;

  /// Ajoute une nouvelle ligne vierge de type main d'œuvre au devis.
  void _addLine() {
    setState(() => _lines.add({
      'description': '',
      'type': 'labor',
      'quantity': 1,
      'unit_price': 0,
    }));
  }

  /// Supprime la ligne de devis située à l'index [index].
  void _removeLine(int index) {
    setState(() => _lines.removeAt(index));
  }

  /// Calcule la somme totale de l'ensemble des lignes du devis en FCFA.
  double get _subtotal => _lines.fold(0, (sum, line) {
    final qty = (line['quantity'] as num?)?.toDouble() ?? 1;
    final price = (line['unit_price'] as num?)?.toDouble() ?? 0;
    return sum + (qty * price);
  });

  /// Calcule le montant net reversé au technicien (hors commissions plateforme éventuelles).
  double get _netTechnician => _subtotal;

  /// Valide et transmet le devis au client via Supabase.
  ///
  /// Contrôle que les descriptions sont non-vides, insère l'entrée dans la table `quotes`,
  /// et bascule le statut de la mission associée à `'quote_sent'`.
  Future<void> _sendQuote() async {
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez au moins une ligne au devis'),
          backgroundColor: AppColors.error),
      );
      return;
    }

    for (final line in _lines) {
      if ((line['description'] as String).trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Remplissez toutes les descriptions'),
            backgroundColor: AppColors.error),
        );
        return;
      }
    }

    setState(() => _isSending = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      // Préparer les lignes
      final formattedLines = _lines.map((line) {
        final qty = (line['quantity'] as num?)?.toDouble() ?? 1;
        final price = (line['unit_price'] as num?)?.toDouble() ?? 0;
        return {
          'type': line['type'],
          'description': line['description'],
          'quantity': qty,
          'unit_price': price,
          'total': qty * price,
        };
      }).toList();

      // Créer le devis
      await Supabase.instance.client.from('quotes').insert({
        'mission_id': widget.mission['id'],
        'technician_id': userId,
        'lines': formattedLines,
        'subtotal': _subtotal,
        'commission_rate': 0.0,
        'commission_amount': 0.0,
        'net_technician': _netTechnician,
        'status': 'pending',
      });


      // Mettre à jour le statut de la mission
      await Supabase.instance.client
          .from('missions')
          .update({'status': 'quote_sent'})
          .eq('id', widget.mission['id']);

      if (mounted) {
        // ✅ SnackBar amélioré avec icône et message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('✅ Devis envoyé au client !'),
              ],
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Construit la vue d'édition de devis avec la liste dynamique des postes et le bouton d'envoi.
  @override
  Widget build(BuildContext context) {
    final tc = Theme.of(context).extension<TechLinkColors>()!;

    return Scaffold(
      backgroundColor: tc.background,
      appBar: AppBar(
        backgroundColor: tc.background,
        title: Text('Créer le devis', style: TextStyle(color: tc.textPrimary)),
        iconTheme: IconThemeData(color: tc.textPrimary),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Devis pour le client',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary)),
                              Text(
                                widget.mission['categories']
                                        ?['name'] as String? ??
                                    'Mission',
                                style: TextStyle(
                                  color: tc.textSecondary,
                                  fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Lignes du devis',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: tc.textPrimary)),
                      TextButton.icon(
                        onPressed: _addLine,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Ajouter'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_lines.isEmpty)
                    GestureDetector(
                      onTap: _addLine,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: tc.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: tc.border,
                              style: BorderStyle.solid),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_circle_outline,
                                color: AppColors.primary, size: 36),
                            const SizedBox(height: 8),
                            Text('Appuyez pour ajouter une ligne',
                              style: TextStyle(
                                color: tc.textSecondary)),
                          ],
                        ),
                      ),
                    ),

                  ..._lines.asMap().entries.map((entry) =>
                      _QuoteLine(
                        index: entry.key,
                        line: entry.value,
                        tc: tc,
                        onRemove: () => _removeLine(entry.key),
                        onChanged: (updated) => setState(
                            () => _lines[entry.key] = updated),
                      )),

                  if (_lines.isNotEmpty) ...[
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: tc.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: tc.border),
                      ),
                      child: Column(
                        children: [
                          _SummaryRow('Sous-total',
                              '${_subtotal.toStringAsFixed(0)} FCFA',
                              isBold: false, tc: tc),
                          const SizedBox(height: 8),
                          _SummaryRow(
                              'Vous recevrez',
                              '${_netTechnician.toStringAsFixed(0)} FCFA',
                              isBold: true,
                              color: AppColors.success,
                              tc: tc),
                          const SizedBox(height: 4),
                          _SummaryRow(
                              'Total client',
                              '${_subtotal.toStringAsFixed(0)} FCFA',
                              isBold: true,
                              color: AppColors.primary,
                              tc: tc),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tc.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4)),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendQuote,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _isSending
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_outlined),
              label: Text(
                _isSending ? 'Envoi...' : 'Envoyer le devis au client',
                style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte de saisie d'un poste de devis individuel (type, libellé, quantité, prix unitaire).
class _QuoteLine extends StatelessWidget {
  /// Position ordinale de la ligne dans le devis (0-indexée).
  final int index;

  /// Données brutes représentant la ligne tarifaire.
  final Map<String, dynamic> line;

  /// Callback invoqué lors de la suppression de la ligne.
  final VoidCallback onRemove;

  /// Callback invoqué lors de la modification des attributs de la ligne.
  final Function(Map<String, dynamic>) onChanged;

  /// Palette des couleurs personnalisées de l'application TechLink.
  final TechLinkColors tc;

  /// Constructeur constant du widget [_QuoteLine].
  const _QuoteLine({
    required this.index, required this.line,
    required this.onRemove, required this.onChanged,
    required this.tc,
  });

  @override
  Widget build(BuildContext context) {
    final types = {
      'labor': 'Main d\'œuvre',
      'parts': 'Pièces',
      'travel': 'Déplacement',
      'other': 'Autre',
    };

    final qty = (line['quantity'] as num?)?.toDouble() ?? 1;
    final price = (line['unit_price'] as num?)?.toDouble() ?? 0;
    final total = qty * price;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tc.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Ligne ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, color: tc.textPrimary)),
              const Spacer(),
              DropdownButton<String>(
                value: line['type'] as String? ?? 'labor',
                underline: const SizedBox(),
                dropdownColor: tc.surface,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
                items: types.entries.map((e) =>
                  DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value))).toList(),
                onChanged: (v) => onChanged({...line, 'type': v}),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.delete_outline,
                    color: AppColors.error, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            initialValue: line['description'] as String? ?? '',
            style: TextStyle(color: tc.textPrimary),
            decoration: InputDecoration(
              hintText: 'Description...',
              hintStyle: TextStyle(color: tc.textSecondary.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => onChanged({...line, 'description': v}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: line['quantity'].toString(),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Qté',
                    labelStyle: TextStyle(color: tc.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => onChanged({
                    ...line,
                    'quantity': double.tryParse(v) ?? 1,
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: line['unit_price'].toString(),
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: tc.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Prix unitaire (FCFA)',
                    labelStyle: TextStyle(color: tc.textSecondary),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => onChanged({
                    ...line,
                    'unit_price': double.tryParse(v) ?? 0,
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${total.toStringAsFixed(0)} F',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Ligne de récapitulatif financier affichant un intitulé et un montant chiffré.
class _SummaryRow extends StatelessWidget {
  /// Libellé descriptif (ex: Sous-total, Total client).
  final String label;

  /// Montant formaté en FCFA.
  final String value;

  /// Indique si la ligne doit être rendue en gras avec une taille de police accrue.
  final bool isBold;

  /// Couleur personnalisée optionnelle appliquée au texte.
  final Color? color;

  /// Palette de couleurs du thème actif.
  final TechLinkColors tc;

  /// Constructeur constant de la ligne récapitulative [_SummaryRow].
  const _SummaryRow(this.label, this.value,
      {this.isBold = false, this.color, required this.tc});

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}
