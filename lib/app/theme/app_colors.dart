import 'package:flutter/material.dart';

/// Centralised design tokens for the attendance app.
///
/// Palette: warm off-white surfaces, deep navy text, emerald ledger-green
/// accent, restrained amber/rust warnings, clear error red. Keep usage
/// semantic (never scatter literals into widgets).
abstract final class AppColors {
  // Brand / accents.
  static const Color emerald600 = Color(0xFF047857); // primary accent (CTA)
  static const Color emerald700 = Color(0xFF065F46); // pressed accent
  static const Color emerald50 = Color(0xFFECFDF5); // subtle success bg

  // Neutrals — warm off-white family.
  static const Color ink900 = Color(0xFF0F172A); // primary text (slate-900)
  static const Color ink700 = Color(0xFF334155); // strong secondary text
  static const Color ink600 = Color(0xFF475569); // secondary text
  static const Color slate500 = Color(0xFF64748B); // muted text
  static const Color slate400 = Color(0xFF94A3B8); // disabled / faint icons
  static const Color slate200 = Color(0xFFE2E8F0); // faint fills / icons
  static const Color border = Color(0xFFE3EAEE); // card / divider borders
  static const Color background = Color(0xFFF7F9FA); // app background
  static const Color surface = Color(0xFFFFFFFF); // card surface

  // Status.
  static const Color amber600 = Color(0xFFB45309); // restrained warning text
  static const Color amber50 = Color(0xFFFFFBEB); // warning surface
  static const Color rose600 = Color(0xFFBE123C); // error text
  static const Color rose50 = Color(0xFFFFF1F2); // error surface
  static const Color teal600 = Color(0xFF0F766E); // info / attribution

  static const Color onCta = Colors.white;
}
