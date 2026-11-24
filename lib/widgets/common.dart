import 'dart:ui' show PathMetric;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';
import 'pixel_art.dart';

/// Tarjeta azul noche con esquinas redondeadas. Con [lifted] proyecta una
/// sombra sólida hacia abajo, como las piezas principales de cada pantalla.
class NightCard extends StatelessWidget {
  const NightCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.lifted = false, this.color, this.radius = Corner.card});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool lifted;
  final Color? color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? tokens.card,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: lifted ? [BoxShadow(color: tokens.cardShadow, offset: const Offset(0, 6))] : null,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Rótulo pequeño en mayúsculas encima de un dato o un título.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color));
}

/// Colores de un [PushButton].
enum ButtonTone { amber, blue, green, danger }

/// Botón con relieve: una sombra sólida debajo que desaparece al pulsarlo.
class PushButton extends StatefulWidget {
  const PushButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = ButtonTone.amber,
    this.busy = false,
    this.height = 54,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonTone tone;
  final bool busy;
  final double height;
  final bool expand;

  @override
  State<PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<PushButton> {
  bool pressed = false;

  bool get enabled => widget.onPressed != null && !widget.busy;

  void _setPressed(bool value) {
    if (pressed != value) setState(() => pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    // Relleno, sombra y texto. El de peligro va solo con borde, sin relieve.
    final (Color fill, Color? shadow, Color foreground) = switch (widget.tone) {
      ButtonTone.amber => (tokens.amber, tokens.amberShadow, tokens.onAmber),
      ButtonTone.blue => (tokens.blue, tokens.blueShadow, tokens.onBlue),
      ButtonTone.green => (tokens.green, tokens.greenShadow, tokens.onGreen),
      ButtonTone.danger => (Colors.transparent, null, tokens.danger),
    };
    final depth = shadow == null ? 0.0 : (pressed ? 1.0 : 5.0);

    final content = widget.busy
        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: foreground))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: foreground), const SizedBox(width: Gap.sm)],
            Flexible(child: Text(widget.label.toUpperCase(), overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge!.copyWith(color: foreground))),
          ]);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy ? '${widget.label}, cargando' : widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapCancel: () => _setPressed(false),
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTap: enabled
            ? () {
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled || widget.busy ? 1 : 0.5,
          // El hueco de la sombra se reserva siempre para que el botón no empuje lo de abajo.
          child: Padding(
            padding: EdgeInsets.only(top: 5 - depth, bottom: depth),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              padding: const EdgeInsets.symmetric(horizontal: Gap.lg + 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(Corner.button),
                border: shadow == null ? Border.all(color: foreground, width: 2) : null,
                boxShadow: shadow == null ? null : [BoxShadow(color: shadow, offset: Offset(0, depth))],
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado de icono sobre fondo elevado, como el de editar o cerrar.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.size = 44, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        label: tooltip,
        excludeSemantics: true,
        child: Opacity(
          opacity: onPressed != null ? 1 : 0.35,
          child: Material(
            color: tokens.raised,
            borderRadius: BorderRadius.circular(Corner.icon),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(Corner.icon),
              child: SizedBox(width: size, height: size, child: Icon(icon, size: 20, color: color ?? tokens.amberText)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Marca de la app: un cofre de tesoro en pixel.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.pixel = 6, this.locked = false});
  final double pixel;

  /// Cofre apagado, por abrir.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return PixelArt(
      Sprites.chest,
      pixel: pixel,
      fill: locked ? const Color(0xFF4A5784) : tokens.amber,
      highlight: locked ? tokens.textMuted : null,
      semanticLabel: locked ? 'Cofre cerrado' : 'Cofre',
    );
  }
}

/// Avatar redondo con las iniciales. Con [glow] lleva un halo, como en el perfil.
class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.initials, this.size = 48, this.glow = false});
  final String initials;
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: glow ? tokens.blue : tokens.node,
        boxShadow: glow
            ? [BoxShadow(color: tokens.raised, spreadRadius: 5), BoxShadow(color: tokens.blue.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 5)]
            : null,
      ),
      child: Text(initials,
          style: Theme.of(context).textTheme.titleLarge!.copyWith(fontSize: size * 0.38, height: 1, color: glow ? tokens.onBlue : tokens.textSoft)),
    );
  }
}

/// Barra de progreso redondeada.
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({super.key, required this.value, required this.color, this.height = 8});

  /// De 0 a 1.
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(color: AppTokens.of(context).node, borderRadius: radius),
      alignment: Alignment.centerLeft,
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 250),
        widthFactor: value.clamp(0, 1),
        child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: radius), child: const SizedBox.expand()),
      ),
    );
  }
}

/// Estado de un reto en el camino.
enum TrailState { done, current, locked }

/// Parada del camino: verde si ya se respondió, ámbar con halo si es la
/// siguiente y apagada, con un candado si es grande, si está por llegar.
class TrailNode extends StatelessWidget {
  const TrailNode({super.key, required this.state, required this.number, this.size = 68, this.onPressed, this.semanticLabel});
  final TrailState state;
  final int number;
  final double size;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    final depth = size >= 56 ? 6.0 : 3.0;
    final (Color fill, Color? shadow) = switch (state) {
      TrailState.done => (tokens.green, tokens.greenShadow),
      TrailState.current => (tokens.amber, tokens.amberShadow),
      TrailState.locked => (tokens.node, size >= 56 ? tokens.nodeShadow : null),
    };

    final Widget face = switch (state) {
      TrailState.done => Icon(Icons.check_rounded, size: size * 0.5, color: tokens.onGreen),
      TrailState.current when onPressed != null => Icon(Icons.play_arrow_rounded, size: size * 0.48, color: tokens.onAmber),
      TrailState.current => Text('$number', style: theme.textTheme.titleMedium!.copyWith(fontSize: size * 0.4, color: tokens.onAmber)),
      TrailState.locked => Text('$number', style: theme.textTheme.titleMedium!.copyWith(fontSize: size * 0.36, color: tokens.textSoft)),
    };

    final node = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        boxShadow: [
          if (shadow != null) BoxShadow(color: shadow, offset: Offset(0, depth)),
          if (state == TrailState.current) ...[
            BoxShadow(color: tokens.amber.withValues(alpha: 0.25), spreadRadius: size * 0.1),
            BoxShadow(color: tokens.amber.withValues(alpha: 0.6), blurRadius: size * 0.4),
          ],
        ],
      ),
      child: face,
    );

    // Candado en la esquina de las paradas grandes bloqueadas.
    final Widget marked = state == TrailState.locked && size >= 56
        ? Stack(clipBehavior: Clip.none, children: [
            node,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.36,
                height: size * 0.36,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tokens.night, border: Border.all(color: tokens.node, width: 2)),
                child: Icon(Icons.lock_rounded, size: size * 0.2, color: tokens.textMuted),
              ),
            ),
          ])
        : node;

    return Semantics(
      button: onPressed != null,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        onTap: onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                onPressed!();
              },
        child: marked,
      ),
    );
  }
}

/// Trazo punteado que une los centros de las paradas con una curva suave.
class TrailPainter extends CustomPainter {
  TrailPainter({required this.points, required this.color, this.width = 4, this.gap = 12});
  final List<Offset> points;
  final Color color;
  final double width;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      // Tramo en S: sale y llega en vertical si el camino baja, en horizontal si avanza.
      final vertical = (b.dy - a.dy).abs() > (b.dx - a.dx).abs();
      final mid = vertical ? Offset(0, (b.dy - a.dy) / 2) : Offset((b.dx - a.dx) / 2, 0);
      path.cubicTo(a.dx + mid.dx, a.dy + mid.dy, b.dx - mid.dx, b.dy - mid.dy, b.dx, b.dy);
    }
    final paint = Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += gap) {
        canvas.drawPath(metric.extractPath(d, d + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(TrailPainter oldDelegate) => oldDelegate.points != points || oldDelegate.color != color;
}

/// Estado vacío o de error. Explica qué pasó y, si se puede, ofrece cómo seguir.
class StatusMessage extends StatelessWidget {
  const StatusMessage({super.key, required this.icon, required this.title, required this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = AppTokens.of(context);
    return Padding(
      padding: const EdgeInsets.all(Gap.sm),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: tokens.node, borderRadius: BorderRadius.circular(Corner.button)),
          child: Icon(icon, size: 28, color: tokens.blue),
        ),
        const SizedBox(height: Gap.md),
        Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        const SizedBox(height: Gap.xs),
        Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
        if (actionLabel != null) ...[
          const SizedBox(height: Gap.lg),
          PushButton(label: actionLabel!, onPressed: onAction, tone: ButtonTone.blue, expand: false, height: 48),
        ],
      ]),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
        ?trailing,
      ]);
}

/// Cifra grande con su rótulo debajo, para las fichas de estadísticas.
class StatFigure extends StatelessWidget {
  const StatFigure({super.key, required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: theme.textTheme.headlineMedium!.copyWith(color: color)),
        Text(label, style: theme.textTheme.bodySmall!.copyWith(fontSize: 13)),
      ]),
    );
  }
}

/// Ficha con varias [StatFigure] separadas por líneas finas.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return NightCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: Gap.lg),
      child: IntrinsicHeight(
        child: Row(children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0) VerticalDivider(width: 2, thickness: 2, color: tokens.raised),
            Expanded(child: child),
          ],
        ]),
      ),
    );
  }
}

/// Días que quedan del reto semanal; la semana acaba el domingo.
String weeklyDeadline() {
  // weekday va de 1 (lunes) a 7 (domingo).
  final daysLeft = 8 - DateTime.now().weekday;
  return daysLeft == 1 ? 'Termina hoy' : 'Quedan $daysLeft días';
}

/// Letra de una opción (A–D) en un círculo; verde si es la correcta.
class OptionLetter extends StatelessWidget {
  const OptionLetter({super.key, required this.letter, this.highlighted = false});
  final String letter;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: highlighted ? tokens.green : tokens.node),
      child: Text(letter, style: Theme.of(context).textTheme.titleMedium!.copyWith(color: highlighted ? tokens.onGreen : tokens.text)),
    );
  }
}
