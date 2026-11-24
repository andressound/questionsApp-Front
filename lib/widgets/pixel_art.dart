import 'package:material_ui/material_ui.dart';

import '../theme/app_tokens.dart';

/// Sprites dibujados con caracteres: `o` contorno, `f` relleno, `h` brillo, `.` vacío.
abstract final class Sprites {
  /// Cofre de tesoro, la marca de la app.
  static const chest = [
    '..oooooooooo..',
    '.offffffffffo.',
    'offhffffffhffo',
    'oooooooooooooo',
    'offffooooffffo',
    'offffohhoffffo',
    'oooooohhoooooo',
    'offffooooffffo',
    'offhffffffhffo',
    'oooooooooooooo',
  ];
}

/// Pinta un sprite de [Sprites] con un tamaño de píxel fijo para que no se emborrone.
class PixelArt extends StatelessWidget {
  const PixelArt(this.sprite, {super.key, this.fill, this.outline, this.highlight, this.pixel = 3, this.semanticLabel});
  final List<String> sprite;
  final Color? fill;
  final Color? outline;
  final Color? highlight;
  final double pixel;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AppTokens.of(context);
    final columns = sprite.fold<int>(0, (max, row) => row.length > max ? row.length : max);
    final art = CustomPaint(
      size: Size(columns * pixel, sprite.length * pixel),
      painter: _SpritePainter(sprite, pixel, {'o': outline ?? tokens.cardShadow, 'f': fill ?? tokens.amber, 'h': highlight ?? const Color(0xFFFFF2D6)}),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: art);
    return Semantics(label: semanticLabel, image: true, child: art);
  }
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite, this.pixel, this.palette);
  final List<String> sprite;
  final double pixel;
  final Map<String, Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < sprite.length; y++) {
      final row = sprite[y];
      for (var x = 0; x < row.length; x++) {
        final color = palette[row[x]];
        if (color == null) continue;
        paint.color = color;
        canvas.drawRect(Rect.fromLTWH(x * pixel, y * pixel, pixel, pixel), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter oldDelegate) => oldDelegate.sprite != sprite || oldDelegate.pixel != pixel || oldDelegate.palette.toString() != palette.toString();
}
