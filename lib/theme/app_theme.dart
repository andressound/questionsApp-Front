import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:material_ui/material_ui.dart';

import 'app_tokens.dart';

abstract final class AppTheme {
  static const _tokens = AppTokens.dark;

  static final colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: _tokens.amber,
    onPrimary: _tokens.onAmber,
    primaryContainer: _tokens.raised,
    onPrimaryContainer: _tokens.text,
    secondary: _tokens.blue,
    onSecondary: _tokens.onBlue,
    error: _tokens.danger,
    onError: _tokens.onBlue,
    errorContainer: const Color(0xFF4A1A24),
    onErrorContainer: _tokens.text,
    surface: _tokens.night,
    onSurface: _tokens.text,
    onSurfaceVariant: _tokens.textMuted,
    surfaceContainerLowest: _tokens.cardShadow,
    surfaceContainerLow: _tokens.night,
    surfaceContainer: _tokens.card,
    surfaceContainerHigh: _tokens.raised,
    surfaceContainerHighest: _tokens.node,
    outline: _tokens.path,
    outlineVariant: _tokens.line,
  );

  static TextTheme get _textTheme {
    const tabular = [FontFeature.tabularFigures()];
    final text = _tokens.text;
    final muted = _tokens.textMuted;
    TextStyle nunito(double size, FontWeight weight, double height, {Color? color, double tracking = 0}) =>
        TextStyle(fontFamily: 'Nunito', fontSize: size, fontWeight: weight, height: height, letterSpacing: tracking, color: color ?? text, fontFeatures: tabular);
    return TextTheme(
      displayLarge: nunito(56, FontWeight.w900, 1.05),
      displayMedium: nunito(40, FontWeight.w900, 1.1),
      displaySmall: nunito(32, FontWeight.w900, 1.15),
      headlineLarge: nunito(28, FontWeight.w900, 1.2),
      headlineMedium: nunito(24, FontWeight.w900, 1.2),
      headlineSmall: nunito(22, FontWeight.w900, 1.25),
      titleLarge: nunito(18, FontWeight.w900, 1.3),
      titleMedium: nunito(17, FontWeight.w900, 1.3),
      titleSmall: nunito(16, FontWeight.w800, 1.3),
      bodyLarge: nunito(17, FontWeight.w700, 1.45),
      bodyMedium: nunito(15, FontWeight.w700, 1.45),
      bodySmall: nunito(14, FontWeight.w700, 1.4, color: muted),
      // Botones: mayúsculas con algo de aire entre letras.
      labelLarge: nunito(17, FontWeight.w900, 1.1, tracking: 1),
      // Rótulos pequeños sobre un dato, también en mayúsculas.
      labelMedium: nunito(13, FontWeight.w800, 1.2, color: muted, tracking: 1),
      labelSmall: nunito(12, FontWeight.w800, 1.2, color: muted, tracking: 0.7),
    );
  }

  static ThemeData get dark {
    final textTheme = _textTheme;
    OutlineInputBorder inputBorder(Color color, [double width = 2]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(Corner.button), borderSide: BorderSide(color: color, width: width));

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Nunito',
      textTheme: textTheme,
      scaffoldBackgroundColor: _tokens.night,
      extensions: const [_tokens],
      iconTheme: IconThemeData(color: _tokens.text),
      dividerTheme: DividerThemeData(color: _tokens.night, thickness: 2, space: 2),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _tokens.amberText,
          textStyle: textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w900),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.chip)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _tokens.night,
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.lg),
        hintStyle: textTheme.bodyMedium!.copyWith(color: _tokens.textMuted.withValues(alpha: 0.75)),
        labelStyle: textTheme.bodyMedium!.copyWith(color: _tokens.textMuted),
        floatingLabelStyle: textTheme.bodyMedium!.copyWith(color: _tokens.amberText),
        prefixIconColor: _tokens.textMuted,
        suffixIconColor: _tokens.textMuted,
        border: inputBorder(_tokens.node),
        enabledBorder: inputBorder(_tokens.node),
        focusedBorder: inputBorder(_tokens.amber),
        errorBorder: inputBorder(_tokens.danger),
        focusedErrorBorder: inputBorder(_tokens.danger),
        errorStyle: textTheme.labelSmall!.copyWith(color: _tokens.danger, letterSpacing: 0),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _tokens.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.card)),
        titleTextStyle: textTheme.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _tokens.raised,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.button)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: _tokens.raised, borderRadius: BorderRadius.circular(Corner.icon)),
        textStyle: textTheme.bodySmall!.copyWith(color: _tokens.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: _tokens.amber, circularTrackColor: Colors.transparent, refreshBackgroundColor: _tokens.card),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
