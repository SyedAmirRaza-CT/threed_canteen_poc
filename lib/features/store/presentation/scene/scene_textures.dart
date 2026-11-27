import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:three_js/three_js.dart' as three;

import '../../domain/entities/product.dart';
import 'product_art.dart';

/// Textures drawn with Flutter's own canvas (text signs, tile floor), so the
/// 3D store can show readable words without any image assets.
class SceneTextures {
  SceneTextures._(
    this._signs,
    this._labels,
    this._tags,
    this.floor,
    this.oak,
    this.walnut,
    this.slats,
  );

  final Map<String, three.Texture> _signs;
  final Map<String, three.Texture> _labels;
  final Map<String, three.Texture> _tags;

  /// Wood plank floor (repeats), light oak and dark walnut grain for
  /// furniture, and vertical wall slats (repeats).
  final three.Texture floor;
  final three.Texture oak;
  final three.Texture walnut;
  final three.Texture slats;

  three.Texture? sign(String key) => _signs[key];

  /// Printed package label of a product (name + emoji on its colour).
  three.Texture? label(String productId) => _labels[productId];

  /// Shelf-edge price tag of a product (name + price).
  three.Texture? tag(String productId) => _tags[productId];

  /// Set to true if signs show up upside down on a platform.
  static const bool _flipRows = true;

  /// [signs] maps a key to (text, background 0xRRGGBB, foreground 0xRRGGBB).
  static Future<SceneTextures> create(
    Map<String, ({String text, int bg, int fg})> signs,
    List<Product> products,
  ) async {
    final out = <String, three.Texture>{};
    for (final e in signs.entries) {
      out[e.key] = await _sign(e.value.text, e.value.bg, e.value.fg);
    }
    final labels = <String, three.Texture>{};
    final tags = <String, three.Texture>{};
    for (final p in products) {
      if (!_isFruit(p.kind)) labels[p.id] = await _label(p);
      tags[p.id] = await _tag(p);
    }
    return SceneTextures._(
      out,
      labels,
      tags,
      _grain(
        const [0xC9A06A, 0xBF9560, 0xD2A672, 0xB98C58, 0xC59A66],
        planks: 4,
        joints: true,
      ),
      _grain(const [0xC99B63, 0xBF9059, 0xD2A672], planks: 6, joints: false),
      _grain(const [0x6B4A2E, 0x5F4028, 0x73512F], planks: 6, joints: false),
      _grain(
        const [0xC4965F, 0xB98B56, 0xCDA06B],
        planks: 10,
        joints: false,
        n: 128,
      ),
    );
  }

  /// Soft round white-to-transparent gradient (the light pool under a lamp).
  static three.Texture radialGlow() {
    const n = 64;
    final bytes = Uint8List(n * n * 4);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final dx = (x + 0.5) / n * 2 - 1, dy = (y + 0.5) / n * 2 - 1;
        final d = math.sqrt(dx * dx + dy * dy).clamp(0.0, 1.0);
        final a = ((1 - d) * (1 - d) * 255).round();
        final o = (y * n + x) * 4;
        bytes[o] = 255;
        bytes[o + 1] = 255;
        bytes[o + 2] = 255;
        bytes[o + 3] = a;
      }
    }
    return _fromRgba(bytes, n, n);
  }

  static three.Texture _fromRgba(
    Uint8List bytes,
    int w,
    int h, {
    bool repeat = false,
    bool nearest = false,
    bool mipmaps = false,
  }) {
    final t = three.DataTexture(bytes, w, h);
    t.colorSpace = three.SRGBColorSpace;
    t.minFilter = nearest ? three.NearestFilter : three.LinearFilter;
    if (mipmaps) {
      t.generateMipmaps = true;
      t.minFilter = three.LinearMipmapLinearFilter;
    }
    t.magFilter = nearest ? three.NearestFilter : three.LinearFilter;
    if (repeat) {
      t.wrapS = three.RepeatWrapping;
      t.wrapT = three.RepeatWrapping;
    }
    t.needsUpdate = true;
    return t;
  }

  static int _hash(int a, int b) {
    var h = (a * 73856093) ^ (b * 19349663);
    h = (h ^ (h >> 13)) * 1274126177;
    return (h ^ (h >> 16)) & 0x7fffffff;
  }

  /// Wood boards running along the texture's vertical axis: per-plank tone,
  /// streaky grain, dark gaps and (optional) staggered end joints.
  static three.Texture _grain(
    List<int> tones, {
    int planks = 4,
    bool joints = true,
    int n = 256,
  }) {
    final bytes = Uint8List(n * n * 4);
    final pw = n ~/ planks;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final pi = x ~/ pw, lx = x % pw;
        final shift = pi * 83;
        final piece = joints ? ((y + shift) ~/ (n ~/ 2)) : 0;
        final tone = tones[(pi + piece * 2) % tones.length];
        final streak =
            (_hash(x, (y ~/ 18) + pi * 13) % 15) - 7; // long grain streaks
        final fine = (_hash(x * 3, y ~/ 3) % 5) - 2;
        var f = 1 + (streak + fine) / 110;
        final gap = lx < 1;
        final joint = joints && ((y + shift) % (n ~/ 2)) < 2;
        if (gap || joint) f = 0.55;
        final i = (y * n + x) * 4;
        bytes[i] = (((tone >> 16) & 0xFF) * f).round().clamp(0, 255);
        bytes[i + 1] = (((tone >> 8) & 0xFF) * f).round().clamp(0, 255);
        bytes[i + 2] = ((tone & 0xFF) * f).round().clamp(0, 255);
        bytes[i + 3] = 255;
      }
    }
    final t = _fromRgba(bytes, n, n, repeat: true);
    t.generateMipmaps = true;
    t.minFilter = three.LinearMipmapLinearFilter;
    return t;
  }

  static Future<three.Texture> _sign(String text, int bg, int fg) async {
    const w = 512, h = 128;
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    final bgColor = ui.Color(0xFF000000 | bg);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(0, 0, w * 1.0, h * 1.0),
        const ui.Radius.circular(18),
      ),
      ui.Paint()..color = bgColor,
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(8, 8, w - 16.0, h - 16.0),
        const ui.Radius.circular(12),
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = ui.Color(0xFF000000 | fg).withValues(alpha: 0.55),
    );
    var size = 64.0;
    late ui.Paragraph p;
    for (var i = 0; i < 12; i++) {
      final pb =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 1),
            )
            ..pushStyle(
              ui.TextStyle(
                color: ui.Color(0xFF000000 | fg),
                fontSize: size,
                fontWeight: ui.FontWeight.w800,
              ),
            )
            ..addText(text);
      p = pb.build()..layout(const ui.ParagraphConstraints(width: w - 40.0));
      if (p.longestLine <= w - 40.0) break;
      size *= 0.88; // shrink until the whole text fits
    }
    canvas.drawParagraph(p, ui.Offset(20, (h - p.height) / 2));
    return _fromRgba(await _rgba(rec.endRecording(), w, h), w, h);
  }

  static bool _isFruit(ProductKind k) =>
      k == ProductKind.fruit || k == ProductKind.banana;

  static Future<Uint8List> _rgba(ui.Picture pic, int w, int h) async {
    final img = await pic.toImage(w, h);
    final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    final src = bd!.buffer.asUint8List();
    final out = Uint8List(src.length);
    for (var y = 0; y < h; y++) {
      final from = (_flipRows ? (h - 1 - y) : y) * w * 4;
      out.setRange(y * w * 4, (y + 1) * w * 4, src, from);
    }
    return out;
  }

  /// Package artwork for a product (see [ProductArt]), with mipmaps and
  /// anisotropic filtering so it stays crisp from far away and at an angle.
  static Future<three.Texture> _label(Product p) async {
    final (w, h) = ProductArt.sizeOf(p.kind);
    final t = _fromRgba(
      await _rgba(ProductArt.paint(p), w, h),
      w,
      h,
      mipmaps: true,
    );
    t.anisotropy = 8;
    return t;
  }

  /// A shelf-edge price tag: category colour bar, product name, big price.
  static Future<three.Texture> _tag(Product p) async {
    const w = 256, h = 108;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec);
    c.drawRect(
      const ui.Rect.fromLTWH(0, 0, w * 1.0, h * 1.0),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    c.drawRect(
      const ui.Rect.fromLTWH(0, 0, w * 1.0, 12),
      ui.Paint()..color = ui.Color(0xFF000000 | p.accent),
    );
    void text(
      String t,
      double size,
      ui.Offset at,
      double width,
      ui.Color color,
      ui.TextAlign align,
    ) {
      final pb =
          ui.ParagraphBuilder(
              ui.ParagraphStyle(textAlign: align, maxLines: 1, ellipsis: '…'),
            )
            ..pushStyle(
              ui.TextStyle(
                color: color,
                fontSize: size,
                fontWeight: ui.FontWeight.w800,
              ),
            )
            ..addText(t);
      final para = pb.build()..layout(ui.ParagraphConstraints(width: width));
      c.drawParagraph(para, at);
    }

    text(
      p.name,
      26,
      const ui.Offset(10, 18),
      w - 20.0,
      const ui.Color(0xFF2B2118),
      ui.TextAlign.left,
    );
    text(
      '\u20B9${p.price}',
      50,
      const ui.Offset(10, 48),
      w - 20.0,
      const ui.Color(0xFF000000),
      ui.TextAlign.left,
    );
    text(
      '${p.calories} kcal',
      20,
      const ui.Offset(10, 78),
      w - 20.0,
      const ui.Color(0xFF6B6259),
      ui.TextAlign.right,
    );
    return _fromRgba(
      await _rgba(rec.endRecording(), w, h),
      w,
      h,
      mipmaps: true,
    );
  }
}
