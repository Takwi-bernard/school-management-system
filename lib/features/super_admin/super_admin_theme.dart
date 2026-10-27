import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Design tokens for the whole Super Admin portal. The portal never reads
/// school branding: it has one fixed, professional look.
class Sa {
  static const bg = Color(0xFF0F172A);
  static const sidebar = Color(0xFF0B1220);
  static const card = Color(0xFF1E293B);
  static const cardHi = Color(0xFF243247);
  static const border = Color(0x1AFFFFFF);
  static const text = Color(0xFFF8FAFC);
  static const muted = Color(0xFF94A3B8);
  static const faint = Color(0xFF64748B);
  static const primary = Color(0xFF6366F1);
  static const primaryHi = Color(0xFF818CF8);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);
  static const danger = Color(0xFFF87171);
  static const info = Color(0xFF38BDF8);
  static const double radius = 16;
}

ThemeData superAdminTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Sa.primary,
    brightness: Brightness.dark,
    surface: Sa.bg,
  ).copyWith(primary: Sa.primary, secondary: Sa.primaryHi, error: Sa.danger);

  OutlineInputBorder border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Sa.bg,
    colorScheme: scheme,
    visualDensity: VisualDensity.standard,
    splashFactory: InkRipple.splashFactory,
    dividerColor: Sa.border,
    dividerTheme: const DividerThemeData(color: Sa.border, space: 1, thickness: 1),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.4, color: Sa.text),
      titleLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Sa.text),
      titleMedium: TextStyle(fontWeight: FontWeight.w700, color: Sa.text),
      bodyMedium: TextStyle(color: Sa.text, height: 1.4),
      bodySmall: TextStyle(color: Sa.muted, height: 1.4),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Sa.sidebar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Sa.text, fontSize: 17, fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.04),
      labelStyle: const TextStyle(color: Sa.muted),
      hintStyle: const TextStyle(color: Sa.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(Sa.border),
      enabledBorder: border(Sa.border),
      focusedBorder: border(Sa.primaryHi, 1.5),
      errorBorder: border(Sa.danger),
      focusedErrorBorder: border(Sa.danger, 1.5),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Sa.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Sa.border)),
      titleTextStyle: const TextStyle(color: Sa.text, fontSize: 18, fontWeight: FontWeight.w800),
      contentTextStyle: const TextStyle(color: Sa.muted, fontSize: 14, height: 1.45),
    ),
    cardTheme: CardThemeData(
      color: Sa.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Sa.radius), side: const BorderSide(color: Sa.border)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Sa.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Sa.text,
        minimumSize: const Size(44, 46),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        side: const BorderSide(color: Sa.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Sa.primaryHi,
        minimumSize: const Size(44, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: Sa.muted),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      selectedColor: Sa.primary,
      side: const BorderSide(color: Sa.border),
      labelStyle: const TextStyle(color: Sa.muted, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF334155),
      contentTextStyle: const TextStyle(color: Sa.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Sa.cardHi,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Sa.border)),
      textStyle: const TextStyle(color: Sa.text, fontSize: 14),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: Sa.text, fontSize: 12),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: Sa.text,
      unselectedLabelColor: Sa.muted,
      indicatorColor: Sa.primaryHi,
      dividerColor: Sa.border,
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : Sa.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Sa.primary : Colors.white12),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Sa.primaryHi),
    scrollbarTheme: ScrollbarThemeData(thumbColor: WidgetStateProperty.all(Colors.white24), radius: const Radius.circular(8)),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}