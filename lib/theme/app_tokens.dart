import 'package:material_ui/material_ui.dart';

/// Colores del camino nocturno que no tienen un rol equivalente en [ColorScheme].
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.night,
    required this.card,
    required this.cardShadow,
    required this.raised,
    required this.node,
    required this.nodeShadow,
    required this.line,
    required this.path,
    required this.text,
    required this.textMuted,
    required this.textSoft,
    required this.amber,
    required this.amberShadow,
    required this.onAmber,
    required this.amberText,
    required this.green,
    required this.greenShadow,
    required this.onGreen,
    required this.greenText,
    required this.blue,
    required this.blueShadow,
    required this.onBlue,
    required this.danger,
  });

  /// Fondo de las pantallas.
  final Color night;

  /// Tarjetas y su sombra inferior.
  final Color card;
  final Color cardShadow;

  /// Fila o pestaña elegida y botones secundarios dentro de una tarjeta.
  final Color raised;

  /// Retos aún por jugar y su sombra.
  final Color node;
  final Color nodeShadow;

  /// Bordes de las barras superior e inferior.
  final Color line;

  /// Trazo punteado del camino.
  final Color path;

  /// Texto principal, secundario y sobre nodos bloqueados.
  final Color text;
  final Color textMuted;
  final Color textSoft;

  /// Acción principal, reto actual y puntos.
  final Color amber;
  final Color amberShadow;
  final Color onAmber;
  final Color amberText;

  /// Retos respondidos y respuestas correctas.
  final Color green;
  final Color greenShadow;
  final Color onGreen;
  final Color greenText;

  /// Reto semanal, avatar y puesto.
  final Color blue;
  final Color blueShadow;
  final Color onBlue;

  /// Respuesta incorrecta, tiempo a punto de acabar y acciones destructivas.
  final Color danger;

  static const dark = AppTokens(
    night: Color(0xFF10162B),
    card: Color(0xFF18223F),
    cardShadow: Color(0xFF0A0F20),
    raised: Color(0xFF24315A),
    node: Color(0xFF2B3A66),
    nodeShadow: Color(0xFF1A2547),
    line: Color(0xFF1F2A4A),
    path: Color(0xFF3A4A75),
    text: Color(0xFFEEF2FF),
    textMuted: Color(0xFF9AA6D1),
    textSoft: Color(0xFFC9D3F5),
    amber: Color(0xFFFFB547),
    amberShadow: Color(0xFFC27A10),
    onAmber: Color(0xFF3A2400),
    amberText: Color(0xFFFFD27A),
    green: Color(0xFF3DDC97),
    greenShadow: Color(0xFF1E8A5F),
    onGreen: Color(0xFF0A2A1D),
    greenText: Color(0xFF7EF0C0),
    blue: Color(0xFF9AB8FF),
    blueShadow: Color(0xFF5B78C4),
    onBlue: Color(0xFF10162B),
    danger: Color(0xFFFF8A95),
  );

  static AppTokens of(BuildContext context) => Theme.of(context).extension<AppTokens>()!;

  @override
  AppTokens copyWith({
    Color? night,
    Color? card,
    Color? cardShadow,
    Color? raised,
    Color? node,
    Color? nodeShadow,
    Color? line,
    Color? path,
    Color? text,
    Color? textMuted,
    Color? textSoft,
    Color? amber,
    Color? amberShadow,
    Color? onAmber,
    Color? amberText,
    Color? green,
    Color? greenShadow,
    Color? onGreen,
    Color? greenText,
    Color? blue,
    Color? blueShadow,
    Color? onBlue,
    Color? danger,
  }) =>
      AppTokens(
        night: night ?? this.night,
        card: card ?? this.card,
        cardShadow: cardShadow ?? this.cardShadow,
        raised: raised ?? this.raised,
        node: node ?? this.node,
        nodeShadow: nodeShadow ?? this.nodeShadow,
        line: line ?? this.line,
        path: path ?? this.path,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        textSoft: textSoft ?? this.textSoft,
        amber: amber ?? this.amber,
        amberShadow: amberShadow ?? this.amberShadow,
        onAmber: onAmber ?? this.onAmber,
        amberText: amberText ?? this.amberText,
        green: green ?? this.green,
        greenShadow: greenShadow ?? this.greenShadow,
        onGreen: onGreen ?? this.onGreen,
        greenText: greenText ?? this.greenText,
        blue: blue ?? this.blue,
        blueShadow: blueShadow ?? this.blueShadow,
        onBlue: onBlue ?? this.onBlue,
        danger: danger ?? this.danger,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      night: mix(night, other.night),
      card: mix(card, other.card),
      cardShadow: mix(cardShadow, other.cardShadow),
      raised: mix(raised, other.raised),
      node: mix(node, other.node),
      nodeShadow: mix(nodeShadow, other.nodeShadow),
      line: mix(line, other.line),
      path: mix(path, other.path),
      text: mix(text, other.text),
      textMuted: mix(textMuted, other.textMuted),
      textSoft: mix(textSoft, other.textSoft),
      amber: mix(amber, other.amber),
      amberShadow: mix(amberShadow, other.amberShadow),
      onAmber: mix(onAmber, other.onAmber),
      amberText: mix(amberText, other.amberText),
      green: mix(green, other.green),
      greenShadow: mix(greenShadow, other.greenShadow),
      onGreen: mix(onGreen, other.onGreen),
      greenText: mix(greenText, other.greenText),
      blue: mix(blue, other.blue),
      blueShadow: mix(blueShadow, other.blueShadow),
      onBlue: mix(onBlue, other.onBlue),
      danger: mix(danger, other.danger),
    );
  }
}

/// Espaciado en múltiplos de 4.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Margen lateral de las pantallas.
  static const page = 20.0;
}

/// Radios de las esquinas.
abstract final class Corner {
  static const card = 24.0;
  static const button = 16.0;
  static const chip = 14.0;
  static const icon = 12.0;
}
