import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Certaraos design tokens ────────────────────────────────────────────────────
// Sourced from packages/frontend/ui-kit/src/theme/tokens.ts

// Primary – Blue 500 family
const _primary = Color(0xFF3B82F6);
const _primaryLight = Color(0xFF60A5FA);
const _primaryDark = Color(0xFF2563EB);

// Secondary – Blue 900 family (deep navy)
const _secondary = Color(0xFF1E3A8A);
const _secondaryLight = Color(0xFF1E40AF);

// Neutral – Dark mode (default)
const _background = Color(0xFF171717); // Near-black scaffold
const _surface = Color(0xFF262626); // Card / panel
const _surfaceLow = Color(0xFF1F1F1F); // Sidebar, sunken areas
const _surfaceHigh = Color(0xFF303030); // Elevated / hover state
const _border = Color(0xFF404040); // Dividers and outlines
const _borderSubtle = Color(0xFF2D2D2D); // Very subtle borders

// Text
const _textPrimary = Color(0xFFE5E5E5);
const _textSecondary = Color(0xFFA3A3A3);
const _textDisabled = Color(0xFF737373);

// Semantic
const _success = Color(0xFF16A34A);
const _warning = Color(0xFFEA580C);
const _error = Color(0xFFEF4444);

// ── Color scheme ───────────────────────────────────────────────────────────────

const _colorScheme = ColorScheme(
  brightness: Brightness.dark,
  // Primary
  primary: _primary,
  onPrimary: Colors.white,
  primaryContainer: _secondary,
  onPrimaryContainer: _primaryLight,
  // Secondary
  secondary: _primaryLight,
  onSecondary: Colors.white,
  secondaryContainer: _secondaryLight,
  onSecondaryContainer: _primaryLight,
  // Surface hierarchy
  surface: _surface,
  onSurface: _textPrimary,
  surfaceContainerLowest: _background,
  surfaceContainerLow: _surfaceLow,
  surfaceContainer: _surface,
  surfaceContainerHigh: _surfaceHigh,
  surfaceContainerHighest: Color(0xFF3A3A3A),
  // Outline
  outline: _border,
  outlineVariant: _borderSubtle,
  // On-variants
  onSurfaceVariant: _textSecondary,
  // Error
  error: _error,
  onError: Colors.white,
  errorContainer: Color(0xFF7F1D1D),
  onErrorContainer: Color(0xFFFCA5A5),
  // Misc
  shadow: Colors.black,
  scrim: Colors.black87,
  inverseSurface: _textPrimary,
  onInverseSurface: _background,
  inversePrimary: _primaryDark,
  tertiary: _success,
  onTertiary: Colors.white,
);

// ── Theme ──────────────────────────────────────────────────────────────────────

ThemeData buildAppTheme() {
  final assistantText = GoogleFonts.assistantTextTheme(ThemeData(brightness: Brightness.dark).textTheme).apply(
    bodyColor: _textPrimary,
    displayColor: _textPrimary,
    decorationColor: _textSecondary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: _colorScheme,
    scaffoldBackgroundColor: _background,
    textTheme: assistantText,

    // ── AppBar ────────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: _surface,
      foregroundColor: _textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.assistant(
        color: _textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      iconTheme: const IconThemeData(color: _textSecondary, size: 20),
      actionsIconTheme: const IconThemeData(color: _textSecondary, size: 20),
      shape: const Border(bottom: BorderSide(color: _border, width: 1)),
    ),

    // ── Cards ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _border, width: 1),
      ),
    ),

    // ── Inputs ────────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _surfaceLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _error),
      ),
      labelStyle: const TextStyle(color: _textSecondary),
      hintStyle: const TextStyle(color: _textDisabled),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),

    // ── Buttons ───────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: _surfaceHigh,
        disabledForegroundColor: _textDisabled,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.assistant(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _primary,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: GoogleFonts.assistant(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: _primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: GoogleFonts.assistant(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),

    // ── Dividers ──────────────────────────────────────────────────────────────
    dividerTheme: const DividerThemeData(
      color: _border,
      thickness: 1,
      space: 1,
    ),

    // ── List tiles ────────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      selectedTileColor: _secondary.withAlpha(120),
      iconColor: _textSecondary,
      textColor: _textPrimary,
      subtitleTextStyle: GoogleFonts.assistant(fontSize: 13, color: _textSecondary),
      titleTextStyle: GoogleFonts.assistant(fontSize: 15, color: _textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),

    // ── Checkbox ──────────────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return _primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: _border, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // ── Icons & tooltips ──────────────────────────────────────────────────────
    iconTheme: const IconThemeData(color: _textSecondary, size: 20),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: _surfaceHigh,
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(80), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      textStyle: GoogleFonts.assistant(color: _textPrimary, fontSize: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    // ── Snackbar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: _surfaceHigh,
      contentTextStyle: GoogleFonts.assistant(color: _textPrimary, fontSize: 14),
      actionTextColor: _primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: _border)),
      behavior: SnackBarBehavior.floating,
    ),

    // ── Chip ──────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: _surfaceLow,
      selectedColor: _secondary,
      side: const BorderSide(color: _border),
      labelStyle: GoogleFonts.assistant(fontSize: 13, color: _textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    // ── Progress indicator ────────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),

    // ── Scrollbar ─────────────────────────────────────────────────────────────
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(_border),
      trackColor: WidgetStateProperty.all(_surfaceLow),
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.all(4),
    ),
  );
}

/// Semantic colors for direct use in widgets.
abstract class AppColors {
  static const success = _success;
  static const warning = _warning;
  static const error = _error;
  static const primary = _primary;
  static const primaryLight = _primaryLight;
  static const surface = _surface;
  static const surfaceLow = _surfaceLow;
  static const surfaceHigh = _surfaceHigh;
  static const border = _border;
  static const textPrimary = _textPrimary;
  static const textSecondary = _textSecondary;
  static const textDisabled = _textDisabled;

  /// Blue glow box-shadow, mirroring certaraos effect tokens.
  static List<BoxShadow> glowSm = [BoxShadow(color: Color(0xFF3B82F6).withAlpha(76), blurRadius: 10)];
  static List<BoxShadow> glowMd = [BoxShadow(color: Color(0xFF3B82F6).withAlpha(102), blurRadius: 20)];
}
