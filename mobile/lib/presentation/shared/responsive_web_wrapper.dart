import 'package:flutter/material.dart';

// =========================================================================
// WRAPPER RESPONSIVE WEB
// =========================================================================
// Conteneur utilisé pour centrer et limiter la largeur maximale du contenu
// sur les grands écrans (Web/Desktop), avec une ombre et une bordure légères.

class ResponsiveWebWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ResponsiveWebWrapper({
    super.key,
    required this.child,
    this.maxWidth = 800,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: MediaQuery.of(context).size.width > maxWidth
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
          border: MediaQuery.of(context).size.width > maxWidth
              ? Border.all(
                  color: Colors.grey.withOpacity(0.1),
                  width: 1,
                )
              : null,
        ),
        child: child,
      ),
    );
  }
}
