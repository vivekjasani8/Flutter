import 'package:flutter/material.dart';

/// Idle Miner Sim brand: deep navy (trust, like finance apps) and gold
/// (mining, rewards). Dark is the signature look; light keeps the same brand
/// on white cards with navy actions. Colours are set explicitly, not seeded,
/// so text contrast is predictable (the accessibility tests check it in both
/// modes).
abstract final class AppTheme {
  static ThemeData get dark => _build(_darkScheme, AppColors.dark);
  static ThemeData get light => _build(_lightScheme, AppColors.light);

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFF2B544),
    onPrimary: Color(0xFF2B1E03),
    primaryContainer: Color(0xFF4A3A12),
    onPrimaryContainer: Color(0xFFFFE1A3),
    secondary: Color(0xFF9DB8F2),
    onSecondary: Color(0xFF0B1E40),
    secondaryContainer: Color(0xFF24365A),
    onSecondaryContainer: Color(0xFFDCE6FF),
    tertiary: Color(0xFFFF9A62),
    onTertiary: Color(0xFF3D1400),
    tertiaryContainer: Color(0xFF5A2A12),
    onTertiaryContainer: Color(0xFFFFDCC9),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF4A0F0B),
    errorContainer: Color(0xFF5C1A16),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF0E1726),
    onSurface: Color(0xFFF4F1E8),
    onSurfaceVariant: Color(0xFFA6B1C4),
    surfaceContainerLowest: Color(0xFF0A111D),
    surfaceContainerLow: Color(0xFF16233A),
    surfaceContainer: Color(0xFF1A2842),
    surfaceContainerHigh: Color(0xFF1E2E4B),
    surfaceContainerHighest: Color(0xFF243656),
    outline: Color(0xFF7D8AA3),
    outlineVariant: Color(0xFF2A3B58),
    inverseSurface: Color(0xFFF4F1E8),
    onInverseSurface: Color(0xFF16233A),
    inversePrimary: Color(0xFF8A5A00),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF23397A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDDE5FF),
    onPrimaryContainer: Color(0xFF0F1F4D),
    secondary: Color(0xFF8A5A00),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFCEBC7),
    onSecondaryContainer: Color(0xFF4A3203),
    tertiary: Color(0xFFB4441A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFDCC9),
    onTertiaryContainer: Color(0xFF3D1400),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    surface: Color(0xFFF5F6FA),
    onSurface: Color(0xFF131A2B),
    onSurfaceVariant: Color(0xFF4E566A),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFEEF0F6),
    surfaceContainerHigh: Color(0xFFE8EBF3),
    surfaceContainerHighest: Color(0xFFE1E5EE),
    outline: Color(0xFF737B8F),
    outlineVariant: Color(0xFFDCE0EA),
    inverseSurface: Color(0xFF1B2433),
    onInverseSurface: Color(0xFFF4F1E8),
    inversePrimary: Color(0xFFF2B544),
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  static ThemeData _build(ColorScheme scheme, AppColors brand) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    const tabular = [FontFeature.tabularFigures()];
    final t = base.textTheme;
    final text = t.copyWith(
      displayMedium: t.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          fontFeatures: tabular),
      headlineMedium: t.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
      headlineSmall: t.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w700, fontFeatures: tabular),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: t.titleMedium
          ?.copyWith(fontWeight: FontWeight.w600, fontFeatures: tabular),
      titleSmall: t.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: t.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final buttonShape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: [brand],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 6),
        shape: cardShape,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: brand.accentTint,
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? brand.accent
                  : scheme.onSurfaceVariant,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => text.labelMedium?.copyWith(
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: states.contains(WidgetState.selected)
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                )),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: text.labelLarge),
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 24),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          selectedBackgroundColor: brand.accentTint,
          selectedForegroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// Brand colours that Material's ColorScheme has no slot for.
/// Read with `AppColors.of(context)`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.accent,
    required this.accentTint,
    required this.coinFace,
    required this.coinRim,
    required this.coinMark,
  });

  /// Gold for highlights (icons, key numbers). Darker in light mode so it
  /// stays readable on white.
  final Color accent;

  /// Soft gold background for selected tabs, icon tiles, unlocked items.
  final Color accentTint;

  /// The SimCoin itself: same gold in both modes.
  final Color coinFace;
  final Color coinRim;
  final Color coinMark;

  static const dark = AppColors(
    accent: Color(0xFFF2B544),
    accentTint: Color(0xFF3A2F14),
    coinFace: Color(0xFFF2B544),
    coinRim: Color(0xFFC98A1B),
    coinMark: Color(0xFF5A3D06),
  );

  static const light = AppColors(
    // Amber 700: still 4.9:1 on white, warmer than the old brown.
    accent: Color(0xFFA16207),
    accentTint: Color(0xFFFCEBC7),
    coinFace: Color(0xFFF2B544),
    coinRim: Color(0xFFC98A1B),
    coinMark: Color(0xFF5A3D06),
  );

  static AppColors of(BuildContext context) =>
      Theme.of(context).extension<AppColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  AppColors copyWith({
    Color? accent,
    Color? accentTint,
    Color? coinFace,
    Color? coinRim,
    Color? coinMark,
  }) =>
      AppColors(
        accent: accent ?? this.accent,
        accentTint: accentTint ?? this.accentTint,
        coinFace: coinFace ?? this.coinFace,
        coinRim: coinRim ?? this.coinRim,
        coinMark: coinMark ?? this.coinMark,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      accentTint: Color.lerp(accentTint, other.accentTint, t)!,
      coinFace: Color.lerp(coinFace, other.coinFace, t)!,
      coinRim: Color.lerp(coinRim, other.coinRim, t)!,
      coinMark: Color.lerp(coinMark, other.coinMark, t)!,
    );
  }
}
