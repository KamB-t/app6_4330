import 'package:flutter/material.dart';

// =============================================================================
// Meal Planner design system — ONE file.
//
//   1. AppColors  — the palette (from Coolors)
//   2. AppTheme   — ThemeData built from that palette
//   3. Shared widgets and helpers used by every screen
//
// Change the palette later by changing AppColors (and the ColorScheme below).
// Screens read colors from Theme.of(context).colorScheme, never hard-coded.
// =============================================================================

/// Palette
///   220901  Coffee Bean  — near-black brown: text
///   621708  Dark Garnet  — deep brown-red: app bar, headings
///   941B0C  Oxblood      — primary red: main buttons, selected states
///   BC3908  Rusty Spice  — secondary: FAB, accents, icons
///   F6AA1C  Orange       — warm amber: highlights, nav indicator
/// Cream (#FFF6EC) is a tint of Orange used as the page background so white
/// cards read clearly.
class AppColors {
  static const coffeeBean = Color(0xFF220901);
  static const darkGarnet = Color(0xFF621708);
  static const oxblood = Color(0xFF941B0C);
  static const rustySpice = Color(0xFFBC3908);
  static const orange = Color(0xFFF6AA1C);

  static const cream = Color(0xFFFFF6EC);
  static const creamDark = Color(0xFFFBEEDD);
  static const mutedBrown = Color(0xFF7A4A3A);
  static const softOrange = Color(0xFFFDEBC8);
  static const softRed = Color(0xFFFBE3DE);
  static const border = Color(0xFFEBD8C6);

  // Translucent versions as constants (no deprecated withOpacity calls).
  static const outlineSoft = Color(0x33220901); // Coffee Bean 20%
  static const dividerSoft = Color(0x1F220901); // Coffee Bean 12%
  static const hintBrown = Color(0xCC7A4A3A); // Muted brown 80%
  static const navIndicator = Color(0x59F6AA1C); // Orange 35%
}

class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.oxblood,
      onPrimary: Colors.white,
      primaryContainer: AppColors.softRed,
      onPrimaryContainer: AppColors.darkGarnet,
      secondary: AppColors.rustySpice,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.softOrange,
      onSecondaryContainer: AppColors.coffeeBean,
      tertiary: AppColors.orange,
      onTertiary: AppColors.coffeeBean,
      error: AppColors.oxblood,
      onError: Colors.white,
      errorContainer: AppColors.softRed,
      onErrorContainer: AppColors.darkGarnet,
      surface: Colors.white,
      onSurface: AppColors.coffeeBean,
      onSurfaceVariant: AppColors.mutedBrown,
      outlineVariant: AppColors.border,
      surfaceContainerLow: Colors.white,
      surfaceContainerHighest: AppColors.creamDark,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      canvasColor: AppColors.cream,

      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.coffeeBean,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: TextStyle(
          color: AppColors.coffeeBean,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: AppColors.coffeeBean,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: AppColors.coffeeBean,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: AppColors.darkGarnet,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: AppColors.coffeeBean),
        bodyMedium: TextStyle(color: AppColors.coffeeBean),
        bodySmall: TextStyle(color: AppColors.mutedBrown),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkGarnet,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),

      // Every ElevatedButton: tall, filled Oxblood, rounded.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.oxblood,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.oxblood,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.oxblood,
          side: const BorderSide(color: AppColors.oxblood, width: 1.5),
          minimumSize: const Size(64, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.rustySpice,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 78,
        backgroundColor: Colors.white,
        elevation: 2,
        indicatorColor: AppColors.navIndicator,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: AppColors.oxblood,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            );
          }
          return const TextStyle(
            color: AppColors.mutedBrown,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.oxblood);
          }
          return const IconThemeData(color: AppColors.mutedBrown);
        }),
      ),

      // Every TextField: roomy white box with a soft outline.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        labelStyle: const TextStyle(color: AppColors.darkGarnet),
        hintStyle: const TextStyle(color: AppColors.hintBrown),
        prefixIconColor: AppColors.rustySpice,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outlineSoft),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.oxblood, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.oxblood, width: 1.5),
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.oxblood;
          }
          return Colors.white;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppColors.rustySpice, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.rustySpice,
        textColor: AppColors.coffeeBean,
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.dividerSoft,
        thickness: 1,
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: TextStyle(
          color: AppColors.coffeeBean,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        showDragHandle: true,
      ),

      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.coffeeBean,
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.rustySpice,
        linearTrackColor: AppColors.creamDark,
      ),
    );
  }
}

// =============================================================================
// Shared helpers and widgets
// =============================================================================

/// 500.0 -> "500", 1.5 -> "1.5"
String formatQty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// "ground beef" -> "Ground beef"
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// One consistent card used across the app: white, thin warm border.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final double radius; // corner radius; 0 = square corners

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.color,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: margin,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: color ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: borderColor ?? scheme.outlineVariant,
          width: borderWidth,
        ),
      ),
      child: onTap == null ? child : InkWell(onTap: onTap, child: child),
    );
  }
}

/// Small rounded label, e.g. "25 min", "dinner", "1.5 lbs".
class InfoChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  const InfoChip({super.key, this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: scheme.secondary),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section heading inside forms and detail pages.
class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: AppColors.darkGarnet, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// Inline error message with an icon, tinted so it is easy to notice.
class ErrorBanner extends StatelessWidget {
  final String message;
  const ErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 15, color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty screen: big icon, headline, a sentence, and an optional button.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: scheme.secondary),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
