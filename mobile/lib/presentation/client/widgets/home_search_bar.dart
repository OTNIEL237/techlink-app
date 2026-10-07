// =============================================================================
// TECHLINK - APPLICATION MOBILE FLUTTER
// =============================================================================
// Fichier       : home_search_bar.dart
// Rôle          : Barre de recherche interactive intégrée sur l'écran d'accueil
//                 avec saisie instantanée, effacement et déclencheur vocal.
// Module        : Présentation Client (Widgets Accueil)
// Dépendances   : flutter/material.dart, go_router, app_localizations.dart,
//                 neumorphic_styles.dart
// Sécurité/RLS  : Widget de présentation client sans restriction d'accès.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:techlink/l10n/app_localizations.dart';
import '../../../../core/theme/neumorphic_styles.dart';

/// Barre de recherche active avec saisie textuelle ou déclenchement vocal direct.
class ClientHomeSearchBar extends StatefulWidget {
  /// Constructeur constant de la barre de recherche d'accueil
  const ClientHomeSearchBar({super.key});

  @override
  State<ClientHomeSearchBar> createState() => _ClientHomeSearchBarState();
}

class _ClientHomeSearchBarState extends State<ClientHomeSearchBar> {
  /// Contrôleur du champ texte de la barre de recherche
  final TextEditingController _controller = TextEditingController();

  /// Nœud de focus pour la gestion de l'interaction clavier
  final FocusNode _focusNode = FocusNode();

  /// Indique si du texte est actuellement présent dans le champ de recherche
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText && mounted) {
        setState(() => _hasText = has);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Soumet le texte saisi et redirige vers l'écran de déclaration de problème
  void _submitSearch(String query) {
    final text = query.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    context.push('/client/problem', extra: {
      'query': text,
      'autofocus': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final fieldBg = isDark ? NeumorphicTheme.darkField : NeumorphicTheme.lightField;
    final hintColor = isDark ? NeumorphicTheme.darkTextSecondary : NeumorphicTheme.lightTextSecondary;
    final iconColor = isDark ? const Color(0xFF7E8FA8) : const Color(0xFF6B7A99);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: NeumorphicTheme.debossedShadows(isDark),
          border: Border.all(
            color: isDark
                ? const Color(0xFF333333)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            InkWell(
              onTap: () => _focusNode.requestFocus(),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.search_rounded, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: _submitSearch,
                style: TextStyle(
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF0F172A),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: l10n?.searchHint ?? 'Rechercher un service, une panne...',
                  hintStyle: TextStyle(
                    color: hintColor.withOpacity(0.75),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_hasText)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: hintColor,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _controller.clear();
                },
              ),
            Container(
              width: 1,
              height: 20,
              color: isDark ? const Color(0xFF333333) : const Color(0xFFE2E8F0),
              margin: const EdgeInsets.symmetric(horizontal: 8),
            ),
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                context.push('/client/problem', extra: {'voice': true});
              },
              icon: const Icon(
                Icons.mic_none_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
              tooltip: 'Décrire par la voix',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
