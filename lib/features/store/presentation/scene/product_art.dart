import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../domain/entities/product.dart';

/// Bold, high-resolution artwork for each product shape, so items stay
/// readable from across the shop. Lathe shapes (bottle, can, cup, tub, cake,
/// cupcake, burger) are painted in bands from top to bottom of the image;
/// the 3D shape maps the image's top to the product's top.
class ProductArt {
  ProductArt._();

  /// Image sizes (width, height) for [kind].
  static (int, int) sizeOf(ProductKind kind) => switch (kind) {
    ProductKind.pizza || ProductKind.sandwich => (512, 512),
    ProductKind.donut || ProductKind.bun => (512, 256),
    ProductKind.bottle ||
    ProductKind.chips ||
    ProductKind.bar ||
    ProductKind.carton => (384, 576),
    _ => (512, 512),
  };

  static ui.Picture paint(Product p) {
    final (w, h) = sizeOf(p.kind);
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    final art = _Art(c, w.toDouble(), h.toDouble(), p);
    switch (p.kind) {
      case ProductKind.bottle:
        art.bottle();
      case ProductKind.can:
        art.can();
      case ProductKind.cup:
        art.cup();
      case ProductKind.tub:
      case ProductKind.iceCream:
        art.tub();
      case ProductKind.cake:
        art.cake();
      case ProductKind.cupcake:
        art.cupcake();
      case ProductKind.burger:
        art.burger();
      case ProductKind.pizza:
        art.pizza();
      case ProductKind.donut:
        art.donut();
      case ProductKind.bun:
        art.croissant();
      case ProductKind.sandwich:
        art.sandwich();
      case ProductKind.chips:
        art.pack(foil: true);
      case ProductKind.carton:
      case ProductKind.bar:
        art.pack();
      case ProductKind.fruit:
      case ProductKind.banana:
        art.pack();
    }
    return rec.endRecording();
  }
}

class _Art {
  _Art(this.c, this.w, this.h, this.p);
  final ui.Canvas c;
  final double w, h;
  final Product p;

  ui.Color col(int rgb, [double a = 1]) =>
      ui.Color(0xFF000000 | rgb).withValues(alpha: a);
  ui.Color shade(int rgb, double f) => f < 0
      ? ui.Color.lerp(col(rgb), const ui.Color(0xFF000000), -f)!
      : ui.Color.lerp(col(rgb), const ui.Color(0xFFFFFFFF), f)!;

  /// Image y for a lathe height t (0 = bottom, 1 = top).
  double ty(double t) => (1 - (0.033 + 0.934 * t)) * h;

  void fill(ui.Color color, [ui.Rect? r]) =>
      c.drawRect(r ?? ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = color);

  void band(double t0, double t1, ui.Color color) =>
      fill(color, ui.Rect.fromLTRB(0, ty(t1), w, ty(t0)));

  void text(
    String t,
    double size,
    double cx,
    double top,
    ui.Color color, {
    double? width,
    int lines = 1,
    double weight = 800,
  }) {
    final bw = width ?? w * 0.46;
    final weightStyle =
        ui.FontWeight.values[((weight / 100).round() - 1).clamp(0, 8)];
    var fs = size;
    late ui.Paragraph para;
    // shrink the font until the text fits the width (long words, round shapes)
    for (var i = 0; i < 10; i++) {
      final pb =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(
                textAlign: ui.TextAlign.center,
                maxLines: lines,
                ellipsis: '…',
              ),
            )
            ..pushStyle(
              ui.TextStyle(
                color: color,
                fontSize: fs,
                fontWeight: weightStyle,
                height: 1.0,
              ),
            )
            ..addText(t);
      para = pb.build()..layout(ui.ParagraphConstraints(width: bw));
      if (para.longestLine <= bw + 0.5 && !para.didExceedMaxLines) break;
      fs *= 0.88;
    }
    c.drawParagraph(para, ui.Offset(cx - bw / 2, top));
  }

  /// Big emoji "photo" with a soft white disc behind it.
  void emoji(double cx, double cy, double size, {bool disc = true}) {
    if (disc) {
      c.drawCircle(
        ui.Offset(cx, cy),
        size * 0.62,
        ui.Paint()..color = const ui.Color(0xF2FFFFFF),
      );
    }
    text(
      p.emoji,
      size,
      cx,
      cy - size * 0.58,
      const ui.Color(0xFF000000),
      width: size * 1.5,
      weight: 400,
    );
  }

  // ---- lathe shapes ------------------------------------------------------

  void bottle() {
    fill(col(p.color));
    band(0.6, 0.93, shade(p.color, 0.3)); // shoulder + neck
    band(0.9, 1.0, col(p.accent)); // cap
    band(0.12, 0.56, const ui.Color(0xFFFFFFFF)); // wrap-around label
    band(0.12, 0.15, col(p.accent));
    band(0.53, 0.56, col(p.accent));
    emoji(w / 2, ty(0.43), 150, disc: false);
    text(
      p.name,
      45,
      w / 2,
      ty(0.28),
      col(p.color).withValues(alpha: 1),
      width: w * 0.36,
      lines: 2,
    );
  }

  void can() {
    fill(col(p.color));
    band(0.0, 0.05, const ui.Color(0xFFC9CED4));
    band(0.94, 1.0, const ui.Color(0xFFC9CED4));
    band(0.3, 0.74, const ui.Color(0xFFFFFFFF));
    band(0.3, 0.34, col(p.accent));
    band(0.7, 0.74, col(p.accent));
    emoji(w / 2, ty(0.6), 140, disc: false);
    text(p.name, 49, w / 2, ty(0.43), col(p.color), width: w * 0.36, lines: 2);
  }

  void cup() {
    fill(col(p.color));
    band(0.86, 1.0, const ui.Color(0xFFF4F1EA)); // lid
    band(0.22, 0.7, col(p.accent)); // sleeve
    emoji(w / 2, ty(0.56), 150);
    text(
      p.name,
      45,
      w / 2,
      ty(0.34),
      const ui.Color(0xFF2B2118),
      width: w * 0.36,
      lines: 2,
    );
  }

  void tub() {
    fill(col(p.color));
    band(0.8, 1.0, col(p.accent)); // lid
    c.drawOval(
      ui.Rect.fromCenter(
        center: ui.Offset(w / 2, ty(0.4)),
        width: w * 0.5,
        height: h * 0.55,
      ),
      ui.Paint()..color = const ui.Color(0xF2FFFFFF),
    );
    emoji(w / 2, ty(0.5), 150, disc: false);
    text(
      p.name,
      45,
      w / 2,
      ty(0.3),
      const ui.Color(0xFF2B2118),
      width: w * 0.36,
      lines: 2,
    );
  }

  void cake() {
    fill(col(p.color)); // sponge
    band(0.42, 0.5, const ui.Color(0xFFFFF3D6)); // cream layer
    band(0.7, 1.0, col(p.accent)); // frosting
    final r = math.Random(7);
    for (var i = 0; i < 18; i++) {
      final x = i * w / 17;
      c.drawOval(
        ui.Rect.fromLTWH(x - 26, ty(0.7) - 6, 52, 30 + r.nextDouble() * 46),
        ui.Paint()..color = col(p.accent),
      );
    }
    for (var i = 0; i < 14; i++) {
      c.drawCircle(
        ui.Offset(r.nextDouble() * w, ty(0.9) + r.nextDouble() * 60),
        8,
        ui.Paint()..color = col(0xFFFFFF, 0.8),
      );
    }
  }

  void cupcake() {
    fill(col(p.color)); // muffin top
    final r = math.Random(3);
    for (var i = 0; i < 60; i++) {
      c.drawCircle(
        ui.Offset(r.nextDouble() * w, ty(0.45) - r.nextDouble() * (h * 0.45)),
        8 + r.nextDouble() * 6,
        ui.Paint()..color = col(p.accent, 0.9),
      );
    }
    for (var x = 0.0; x < w; x += 32) {
      final even = (x / 32).round().isEven;
      fill(
        even ? col(p.accent) : const ui.Color(0xFFFFFFFF),
        ui.Rect.fromLTRB(x, ty(0.42), x + 32, ty(0.0)),
      );
    }
  }

  void burger() {
    band(0.0, 0.22, const ui.Color(0xFFD9A04F)); // bottom bun
    band(0.22, 0.42, const ui.Color(0xFF55301F)); // patty
    band(0.42, 0.47, const ui.Color(0xFFFFC83D)); // cheese
    band(0.47, 0.6, col(0x5FAE3E)); // lettuce
    band(0.6, 1.0, const ui.Color(0xFFE0A04D)); // top bun
    for (var x = 0.0; x < w; x += 40) {
      c.drawRect(
        ui.Rect.fromLTWH(x, ty(0.5), 20, 10),
        ui.Paint()..color = col(0x3E8E2E),
      );
    }
    final r = math.Random(5);
    for (var i = 0; i < 70; i++) {
      c.save();
      c.translate(
        r.nextDouble() * w,
        ty(0.99) + r.nextDouble() * (ty(0.62) - ty(0.99)),
      );
      c.rotate(r.nextDouble() * math.pi);
      c.drawOval(
        const ui.Rect.fromLTWH(-9, -5, 18, 10),
        ui.Paint()..color = const ui.Color(0xFFFFF1C9),
      );
      c.restore();
    }
  }

  // ---- flat / other shapes -------------------------------------------------

  void pizza() {
    final cx = w / 2, cy = h / 2, R = w * 0.5;
    c.drawCircle(
      ui.Offset(cx, cy),
      R,
      ui.Paint()..color = const ui.Color(0xFFD9A860),
    ); // crust
    c.drawCircle(
      ui.Offset(cx, cy),
      R * 0.86,
      ui.Paint()..color = const ui.Color(0xFFC8402B),
    ); // sauce
    c.drawCircle(
      ui.Offset(cx, cy),
      R * 0.8,
      ui.Paint()..color = col(p.color),
    ); // cheese
    final r = math.Random(11);
    for (var i = 0; i < 12; i++) {
      final a = r.nextDouble() * math.pi * 2,
          d = math.sqrt(r.nextDouble()) * R * 0.66;
      final o = ui.Offset(cx + math.cos(a) * d, cy + math.sin(a) * d);
      c.drawCircle(o, 34, ui.Paint()..color = col(p.accent));
      c.drawCircle(
        o,
        34,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = shade(p.accent, -0.25),
      );
    }
    for (var i = 0; i < 18; i++) {
      final a = r.nextDouble() * math.pi * 2,
          d = math.sqrt(r.nextDouble()) * R * 0.7;
      c.drawCircle(
        ui.Offset(cx + math.cos(a) * d, cy + math.sin(a) * d),
        9,
        ui.Paint()..color = const ui.Color(0xFFFFE9A8),
      );
    }
  }

  void donut() {
    fill(col(p.color));
    final r = math.Random(2);
    const colors = [0xFFFFFF, 0xFFD93D, 0x4FC3F7, 0x66BB6A, 0xEF5350];
    for (var i = 0; i < 150; i++) {
      c.save();
      c.translate(r.nextDouble() * w, r.nextDouble() * h);
      c.rotate(r.nextDouble() * math.pi);
      c.drawRRect(
        ui.RRect.fromRectAndRadius(
          const ui.Rect.fromLTWH(-14, -4, 28, 8),
          const ui.Radius.circular(4),
        ),
        ui.Paint()..color = col(colors[r.nextInt(colors.length)]),
      );
      c.restore();
    }
    fill(col(0xFFFFFF, 0.18), ui.Rect.fromLTWH(0, h * 0.18, w, h * 0.12));
  }

  void croissant() {
    fill(col(p.color));
    for (var x = -h; x < w; x += 46) {
      c.drawLine(
        ui.Offset(x, 0),
        ui.Offset(x + h * 0.7, h),
        ui.Paint()
          ..strokeWidth = 12
          ..color = shade(p.color, -0.28),
      );
    }
    fill(col(0xFFFFFF, 0.14), ui.Rect.fromLTWH(0, h * 0.15, w, h * 0.14));
  }

  void sandwich() {
    // image top = apex; layers bottom-up: bread, lettuce, tomato, cheese, lettuce, bread
    fill(const ui.Color(0xFFF0D9A8));
    final layers = [
      (0.0, 0.18, 0xF0D9A8),
      (0.18, 0.3, 0x5FAE3E),
      (0.3, 0.44, 0xD93A2B),
      (0.44, 0.54, 0xFFC83D),
      (0.54, 0.66, 0x5FAE3E),
      (0.66, 1.0, 0xF0D9A8),
    ];
    for (final (a, b, rgb) in layers) {
      fill(col(rgb), ui.Rect.fromLTRB(0, h * (1 - b), w, h * (1 - a)));
    }
    c.drawLine(
      ui.Offset(0, h * 0.18),
      ui.Offset(w, h * 0.18),
      ui.Paint()
        ..strokeWidth = 8
        ..color = col(0xB88A4A),
    );
  }

  /// A printed pack front: gradient colour, brand ribbon, emoji, name.
  void pack({bool foil = false}) {
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()
        ..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, h), [
          col(p.color),
          shade(p.color, -0.3),
        ]),
    );
    final top = foil ? h * 0.07 : 0.0;
    if (foil) {
      fill(const ui.Color(0xFFD9DDE2), ui.Rect.fromLTWH(0, 0, w, top));
      fill(const ui.Color(0xFFD9DDE2), ui.Rect.fromLTWH(0, h - top, w, top));
      for (var x = 0.0; x < w; x += 14) {
        c.drawLine(
          ui.Offset(x, 0),
          ui.Offset(x, top),
          ui.Paint()
            ..strokeWidth = 3
            ..color = const ui.Color(0x33000000),
        );
        c.drawLine(
          ui.Offset(x, h - top),
          ui.Offset(x, h),
          ui.Paint()
            ..strokeWidth = 3
            ..color = const ui.Color(0x33000000),
        );
      }
    }
    fill(const ui.Color(0xFFFFFFFF), ui.Rect.fromLTWH(0, top, w, h * 0.12));
    fill(col(p.accent), ui.Rect.fromLTWH(0, top + h * 0.12, w, h * 0.02));
    text(
      'CANTEEN',
      h * 0.075,
      w / 2,
      top + h * 0.02,
      const ui.Color(0xFF2E3338),
      width: w * 0.9,
    );
    emoji(w / 2, h * 0.42, w * 0.5);
    fill(
      const ui.Color(0xCC000000),
      ui.Rect.fromLTWH(0, h * 0.66, w, h * 0.22),
    );
    text(
      p.name,
      w * 0.12,
      w / 2,
      h * 0.675,
      const ui.Color(0xFFFFFFFF),
      width: w * 0.92,
      lines: 2,
    );
    text(
      '${p.calories} kcal',
      h * 0.04,
      w / 2,
      h * 0.9,
      const ui.Color(0xFFFFFFFF),
      width: w * 0.9,
    );
  }
}
