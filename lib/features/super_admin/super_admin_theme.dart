import 'package:flutter/material.dart';

/// Deliberately hardcoded, fixed design for the whole Super Admin
/// module - unlike every other role in this app, this NEVER reads
/// school branding. One design, built once, never revisited per school.
ThemeData superAdminTheme() {
  const primary = Color(0xFF4F46E5); // indigo
  const surface = Color(0xFF0F172A); // slate-900
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
      surface: surface,
    ),
  );
}