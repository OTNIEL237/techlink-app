import 'package:flutter/material.dart';

class NeonColors {
  // Deep dark backgrounds
  static const Color background = Color(0xFF0B0B0F); // Very dark purple/black
  static const Color sidebar = Color(0xFF101015); // Slightly lighter for sidebar
  static const Color card = Color(0xFF16161D); // Card background
  
  // Neon accents
  static const Color neonMagenta = Color(0xFFFF00FF);
  static const Color neonPink = Color(0xFFFF0080);
  static const Color neonPurple = Color(0xFF8A2BE2);
  static const Color neonCyan = Color(0xFF00E5FF);
  
  // Text
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0A0A0);
  
  // Gradients
  static const LinearGradient magentaGradient = LinearGradient(
    colors: [neonMagenta, neonPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF5C33CF), neonMagenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Border / Glow
  static final Border glassBorder = Border.all(color: Colors.white.withOpacity(0.05), width: 1);
  static final BoxDecoration glassBox = BoxDecoration(
    color: card,
    borderRadius: BorderRadius.circular(16),
    border: glassBorder,
  );
}
