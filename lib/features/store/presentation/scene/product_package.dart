import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import '../../domain/entities/product.dart';
import 'scene_kit.dart';
import 'scene_textures.dart';

/// Size and real shape of a product. Bottles, cans, cups, tubs, cakes,
/// cupcakes and burgers are turned (lathe) shapes; pizza is a round disc;
/// donuts and croissants are torus shapes; chips come in a pillow-shaped bag
/// and milk in a gable-top carton; fruit is a pile of spheres or bananas.
/// Used for the packed shelves (instanced) and the items in the basket.
class PackageSpec {
  const PackageSpec._(
    this.kind,
    this.width,
    this.height,
    this.depth, {
    this.cluster,
    this.clusterBaseY = 0.07,
    this.labelYaw = 0,
  });

  final ProductKind kind;
  final double width;
  final double height;
  final double depth;

  /// Loose fruit: [cluster] pieces per slot instead of one package.
  final List<List<double>>? cluster;
  final double clusterBaseY;

  /// Extra yaw so a lathe shape's label (centred at the back by default) faces the front.
  final double labelYaw;

  bool get isFruit => cluster != null;

  static const _applePile = <List<double>>[
    [-0.075, 0.0, 0.0],
    [0.075, 0.0, 0.0],
    [0.0, 0.0, 0.09],
    [0.0, 0.0, -0.09],
    [-0.04, 0.12, 0.0],
    [0.04, 0.12, 0.04],
    [0.0, 0.12, -0.05],
  ];
  static const _bananas = <List<double>>[
    [0.0, 0.0, 0.035],
    [0.0, 0.05, 0.0],
    [0.0, 0.1, -0.035],
  ];

  static PackageSpec of(Product p) => switch (p.kind) {
    ProductKind.cake => const PackageSpec._(
      ProductKind.cake,
      0.3,
      0.12,
      0.3,
      labelYaw: math.pi,
    ),
    ProductKind.cupcake => const PackageSpec._(
      ProductKind.cupcake,
      0.16,
      0.13,
      0.16,
      labelYaw: math.pi,
    ),
    ProductKind.donut => const PackageSpec._(ProductKind.donut, 0.3, 0.09, 0.3),
    ProductKind.bun => const PackageSpec._(ProductKind.bun, 0.27, 0.14, 0.09),
    ProductKind.pizza => const PackageSpec._(ProductKind.pizza, 0.5, 0.5, 0.03),
    ProductKind.burger => const PackageSpec._(
      ProductKind.burger,
      0.28,
      0.16,
      0.28,
      labelYaw: math.pi,
    ),
    ProductKind.sandwich => const PackageSpec._(
      ProductKind.sandwich,
      0.33,
      0.285,
      0.1,
    ),
    ProductKind.bottle => const PackageSpec._(
      ProductKind.bottle,
      0.13,
      0.42,
      0.13,
      labelYaw: math.pi,
    ),
    ProductKind.can => const PackageSpec._(
      ProductKind.can,
      0.1,
      0.2,
      0.1,
      labelYaw: math.pi,
    ),
    ProductKind.cup => const PackageSpec._(
      ProductKind.cup,
      0.15,
      0.24,
      0.15,
      labelYaw: math.pi,
    ),
    ProductKind.chips => const PackageSpec._(
      ProductKind.chips,
      0.27,
      0.4,
      0.08,
    ),
    ProductKind.bar => const PackageSpec._(ProductKind.bar, 0.17, 0.3, 0.05),
    ProductKind.carton => const PackageSpec._(
      ProductKind.carton,
      0.12,
      0.34,
      0.09,
    ),
    ProductKind.tub => const PackageSpec._(
      ProductKind.tub,
      0.19,
      0.14,
      0.19,
      labelYaw: math.pi,
    ),
    ProductKind.iceCream => const PackageSpec._(
      ProductKind.iceCream,
      0.22,
      0.16,
      0.22,
      labelYaw: math.pi,
    ),
    ProductKind.fruit => const PackageSpec._(
      ProductKind.fruit,
      0.32,
      0.26,
      0.3,
      cluster: _applePile,
      clusterBaseY: 0.075,
    ),
    ProductKind.banana => const PackageSpec._(
      ProductKind.banana,
      0.3,
      0.2,
      0.14,
      cluster: _bananas,
      clusterBaseY: 0.085,
    ),
  };

  // ---- geometry ---------------------------------------------------------------

  static final Map<ProductKind, three.BufferGeometry> _cache = {};

  three.BufferGeometry geometry() => _cache.putIfAbsent(kind, _make);

  three.BufferGeometry _make() {
    switch (kind) {
      case ProductKind.bottle:
        return _lathe(height, (t) {
          const r = 0.062;
          if (t < 0.05) return r * (0.78 + 0.22 * (t / 0.05));
          if (t < 0.6) return r;
          if (t < 0.76) return r + (0.026 - r) * _smooth((t - 0.6) / 0.16);
          if (t < 0.9) return 0.026;
          if (t < 0.995) return 0.032; // cap
          return 0.02;
        });
      case ProductKind.can:
        return _lathe(height, (t) {
          const r = 0.05;
          if (t < 0.03) return r * (0.88 + 0.12 * (t / 0.03));
          if (t > 0.96) return r * (0.88 + 0.12 * ((1 - t) / 0.04));
          return r;
        });
      case ProductKind.cup:
        return _lathe(height, (t) {
          if (t < 0.84) return 0.045 + (0.068 - 0.045) * (t / 0.84);
          if (t < 0.88) return 0.074; // lid flange
          final u = (t - 0.88) / 0.12;
          return 0.012 + 0.06 * math.sqrt(math.max(0.0, 1 - u * u));
        });
      case ProductKind.tub:
        return _lathe(height, (t) {
          if (t < 0.8) return 0.075 + 0.015 * (t / 0.8);
          if (t < 0.86) return 0.098;
          return 0.095;
        });
      case ProductKind.iceCream:
        return _lathe(height, (t) {
          if (t < 0.8) return 0.085 + 0.017 * (t / 0.8);
          if (t < 0.86) return 0.112;
          return 0.108;
        });
      case ProductKind.cake:
        return _lathe(height, (t) {
          const r = 0.15;
          if (t < 0.04) return r * (0.92 + 0.08 * (t / 0.04));
          if (t > 0.96) return r * 0.97;
          return r;
        });
      case ProductKind.cupcake:
        return _lathe(height, (t) {
          if (t < 0.42) return 0.042 + 0.02 * (t / 0.42);
          final u = (t - 0.42) / 0.58;
          return 0.078 * math.sqrt(math.max(0.0, 1 - math.pow(u, 2.0)));
        });
      case ProductKind.burger:
        return _lathe(height, (t) {
          if (t < 0.22) return 0.11 + 0.018 * (t / 0.22);
          if (t < 0.42) return 0.135;
          if (t < 0.47) return 0.14;
          if (t < 0.6) return 0.14 + 0.008 * math.sin(t * 120);
          final u = (t - 0.6) / 0.4;
          return 0.13 * math.sqrt(math.max(0.0, 1 - math.pow(u, 2.2)));
        }, n: 40);
      case ProductKind.pizza:
        return three.CylinderGeometry(0.25, 0.25, 0.03, 32)
          ..rotateX(math.pi / 2);
      case ProductKind.donut:
        return three.TorusGeometry(0.1, 0.045, 12, 24)..rotateX(math.pi / 2);
      case ProductKind
          .bun: // croissant: a crescent standing up facing the front
        return three.TorusGeometry(0.09, 0.04, 10, 20, math.pi * 1.2)
          ..rotateZ(-math.pi * 0.1)
          ..translate(0, -0.03, 0);
      case ProductKind
          .sandwich: // triangular wedge, cross-section facing the front
        return three.CylinderGeometry(0.19, 0.19, 0.1, 3)
          ..rotateX(math.pi / 2)
          ..rotateZ(math.pi)
          ..translate(0, -0.0475, 0);
      case ProductKind.chips: // pillow-shaped foil bag, crimped at both ends
        return _deform(three.BoxGeometry(width, height, depth, 6, 14, 2), (
          x,
          y,
          z,
        ) {
          final ny = y / (height / 2);
          final bulge = 1 - ny * ny;
          return [
            x * (1 - 0.06 * math.pow(ny.abs(), 4)),
            y,
            z * (0.22 + 0.78 * bulge),
          ];
        });
      case ProductKind.carton: // gable-top milk carton
        return _deform(three.BoxGeometry(width, height, depth, 1, 5, 1), (
          x,
          y,
          z,
        ) {
          final roof = y - 0.3 * height;
          if (roof <= 0) return [x, y, z];
          final t = (roof / (0.2 * height)).clamp(0.0, 1.0);
          return [x, y, z * (1 - t)];
        });
      case ProductKind.bar:
        return SceneKit.box(width, height, depth);
      case ProductKind.fruit:
        return SceneKit.sphere(0.075, 14);
      case ProductKind.banana:
        return three.TorusGeometry(0.11, 0.024, 8, 14, math.pi * 0.7)
          ..rotateZ(-math.pi * 0.85)
          ..translate(0, 0.08, 0);
    }
  }

  static double _smooth(double t) => t * t * (3 - 2 * t);

  /// A shape turned around the vertical axis. [r] gives the radius at height t (0..1).
  static three.BufferGeometry _lathe(
    double h,
    double Function(double t) r, {
    int n = 28,
    int segments = 28,
  }) {
    final pts = <three.Vector>[three.Vector2(0.0001, -h / 2)];
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      pts.add(three.Vector2(math.max(r(t), 0.0005), -h / 2 + t * h));
    }
    pts.add(three.Vector2(0.0001, h / 2));
    return three.LatheGeometry(pts, segments: segments);
  }

  /// Moves every vertex of [g]: [f] gets x, y, z and returns the new x, y, z.
  static three.BufferGeometry _deform(
    three.BufferGeometry g,
    List<double> Function(double x, double y, double z) f,
  ) {
    final arr = g.getAttributeFromString('position').array;
    for (var i = 0; i < arr.length; i += 3) {
      final v = f(
        arr[i].toDouble(),
        arr[i + 1].toDouble(),
        arr[i + 2].toDouble(),
      );
      arr[i] = v[0];
      arr[i + 1] = v[1];
      arr[i + 2] = v[2];
    }
    g.computeVertexNormals();
    return g;
  }

  // ---- material / models -------------------------------------------------------

  /// Loose fruit uses plain colour; everything else a printed texture.
  three.Material material(Product p, SceneTextures textures) {
    final tex = textures.label(p.id);
    if (tex == null) return SceneKit.mat(p.color, roughness: 0.4);
    return three.MeshStandardMaterial({
      three.MaterialProperty.map: tex,
      three.MaterialProperty.roughness: kind == ProductKind.can ? 0.3 : 0.5,
      three.MaterialProperty.metalness: kind == ProductKind.can ? 0.35 : 0.0,
    });
  }

  /// One product, used for items inside the basket.
  three.Object3D build(Product p, SceneTextures textures, {double scale = 1}) {
    final g = three.Group();
    final mat = material(p, textures);
    final c = cluster;
    if (c != null) {
      for (final o in c.take(kind == ProductKind.banana ? 3 : 4)) {
        g.add(
          SceneKit.mesh(
            geometry(),
            mat,
            x: o[0],
            y: o[1] + clusterBaseY,
            z: o[2],
          ),
        );
      }
    } else {
      final m = SceneKit.mesh(geometry(), mat, y: height / 2);
      m.rotation.y = labelYaw;
      g.add(m);
    }
    g.scale.setValues(scale, scale, scale);
    return g;
  }
}
