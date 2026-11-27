import 'dart:math' as math;
import 'dart:typed_data';

import 'package:three_js/three_js.dart' as three;

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../providers/store_provider.dart';
import 'product_package.dart';
import 'scene_config.dart';
import 'scene_kit.dart';
import 'scene_textures.dart';

/// A rectangle the shopper cannot walk into (x/z, metres).
class Collider {
  const Collider(this.minX, this.maxX, this.minZ, this.maxZ);
  final double minX, maxX, minZ, maxZ;
}

/// One side of a shelf unit holding one category.
class ShelfFace {
  const ShelfFace(this.category, this.x, this.side, this.unitX);
  final Category category;
  final double x; // centre of the boards on this face
  final int side; // +1 faces +x, -1 faces -x
  final double unitX; // x of the unit's back panel
}

class ProductSpot {
  const ProductSpot(
    this.product,
    this.position,
    this.side, {
    this.faceZ = false,
  });
  final Product product;
  final three.Vector3 position;
  final int side;

  /// True for counter items that face the shopper along +z (not a shelf face).
  final bool faceZ;
}

/// All shelf copies of one product (one InstancedMesh). A copy can be hidden
/// when the shopper picks it up and shown again when it is put back.
class ProductGroup {
  ProductGroup(this.mesh, this.spots, this.per)
    : _base = Float32List.fromList(
        List<double>.from(mesh.instanceMatrix!.array),
      );

  final three.InstancedMesh mesh;
  final List<ProductSpot> spots;

  /// Instances per spot (fruit is drawn as a small pile of spheres).
  final int per;
  final Float32List _base;

  /// Spots currently picked up, in the order they were taken.
  final List<int> hidden = [];

  void setHidden(int spot, bool hide) {
    final arr = mesh.instanceMatrix!.array;
    for (var k = 0; k < per; k++) {
      final o = (spot * per + k) * 16;
      if (hide) {
        for (var i = 0; i < 12; i++) {
          arr[o + i] = 0.0; // collapse to a point
        }
      } else {
        for (var i = 0; i < 12; i++) {
          arr[o + i] = _base[o + i];
        }
      }
    }
    mesh.instanceMatrix!.needsUpdate = true;
  }
}

/// Everything the scene controller needs to know about the built world.
class StoreBuild {
  StoreBuild(this.root);
  final three.Group root;
  final List<three.Object3D> doors = [];
  final List<ShelfFace> faces = [];
  final List<Collider> colliders = [];
  final Map<String, ProductGroup> groups = {};
}

class _Place {
  _Place(this.product, this.x, this.y, this.z, this.side, {this.faceZ = false});
  final Product product;
  final double x, y, z;
  final int side;
  final bool faceZ;
}

/// Builds the static store: floor, walls, gate, shelves, fridges, plants, products.
/// Look: warm oak and walnut with black metal accents and warm pendant lamps.
class StoreBuilder {
  StoreBuilder(this.catalog, this.textures);
  final StoreCatalog catalog;
  final SceneTextures textures;

  late final StoreBuild _out;
  final List<_Place> _places = [];
  final Map<String, List<List<double>>> _tags = {}; // productId -> [x, y, z]
  final Map<String, List<List<double>>> _tagsZ = {}; // counter tags facing +z
  three.Group get _root => _out.root;

  late final three.Material _oak = _wood(textures.oak);
  late final three.Material _walnut = _wood(textures.walnut, 0.6);

  three.Material _wood(three.Texture t, [double rough = 0.55]) =>
      three.MeshStandardMaterial({
        three.MaterialProperty.map: t,
        three.MaterialProperty.roughness: rough,
      });

  StoreBuild build() {
    _out = StoreBuild(three.Group());
    _outside();
    _shell();
    _gate();
    _fridges();
    _serviceCounter();
    _counter();
    _plants();
    _shelves();
    _buildProducts();
    return _out;
  }

  three.Mesh _add(
    three.BufferGeometry g,
    three.Material m,
    double x,
    double y,
    double z, {
    String? name,
  }) {
    final mesh = SceneKit.mesh(g, m, x: x, y: y, z: z);
    if (name != null) mesh.name = name;
    _root.add(mesh);
    return mesh;
  }

  // ---- outside -----------------------------------------------------------
  void _outside() {
    final ground = _add(
      SceneKit.plane(160, 160),
      SceneKit.mat(AppColors.groundOutside, roughness: 1),
      0,
      -0.03,
      0,
      name: 'ground',
    );
    ground.rotation.x = -1.5708;
    final plaza = _add(
      SceneKit.plane(30, 16),
      SceneKit.mat(AppColors.plaza, roughness: 0.9),
      0,
      -0.01,
      15,
      name: 'ground',
    );
    plaza.rotation.x = -1.5708;
    final path = _add(
      SceneKit.plane(5.0, 16),
      SceneKit.mat(AppColors.aisleRunner, roughness: 0.9),
      0,
      0.0,
      14,
      name: 'ground',
    );
    path.rotation.x = -1.5708;
    final trunk = SceneKit.mat(AppColors.trunk);
    for (final t in const [
      [-10.0, 10.0],
      [10.0, 10.0],
      [-13.0, 15.0],
      [13.0, 15.0],
      [-9.0, 21.0],
      [9.0, 21.0],
      [-16.0, 5.0],
      [16.0, 5.0],
    ]) {
      _add(SceneKit.cyl(0.22, 0.28, 2.4), trunk, t[0], 1.2, t[1]);
      _add(
        SceneKit.sphere(1.5, 12),
        SceneKit.mat(AppColors.leaves, roughness: 1),
        t[0],
        3.3,
        t[1],
      );
      _add(
        SceneKit.sphere(1.1, 12),
        SceneKit.mat(0x4A8B49, roughness: 1),
        t[0] + 0.5,
        4.2,
        t[1] - 0.3,
      );
      _add(
        SceneKit.sphere(0.9, 12),
        SceneKit.mat(0x366F38, roughness: 1),
        t[0] - 0.6,
        3.9,
        t[1] + 0.4,
      );
    }
    // wooden planters with shrubs flanking the door
    for (final x in const [-3.8, 3.8]) {
      _add(
        SceneKit.box(1.2, 0.6, 1.2),
        _walnut,
        x,
        0.3,
        SceneConfig.frontZ + 1.3,
      );
      for (final o in const [
        [0.0, 0.0, 0.5],
        [-0.3, 0.1, 0.38],
        [0.3, -0.1, 0.4],
      ]) {
        _add(
          SceneKit.sphere(o[2], 10),
          SceneKit.mat(AppColors.leaves, roughness: 1),
          x + o[0],
          0.85 + o[2] * 0.5,
          SceneConfig.frontZ + 1.3 + o[1],
        );
      }
    }
  }

  // ---- building shell ----------------------------------------------------
  void _shell() {
    const w = SceneConfig.halfWidth;
    const h = SceneConfig.wallHeight;
    const depth = SceneConfig.frontZ - SceneConfig.backZ;
    const cz = (SceneConfig.frontZ + SceneConfig.backZ) / 2;
    final wallMat = SceneKit.mat(AppColors.wall, roughness: 0.95);

    // wood plank floor (one texture covers 1.2 m: planks 30 cm wide, running to the back)
    textures.floor.repeat.setValues(w * 2 / 1.2, depth / 1.2);
    final floorMat = three.MeshStandardMaterial({
      three.MaterialProperty.map: textures.floor,
      three.MaterialProperty.roughness: 0.5,
    });
    final floor = _add(
      SceneKit.plane(w * 2, depth),
      floorMat,
      0,
      0.0,
      cz,
      name: 'floor',
    );
    floor.rotation.x = -1.5708;

    _add(SceneKit.box(0.3, h, depth + 0.3), wallMat, -w - 0.15, h / 2, cz);
    _add(SceneKit.box(0.3, h, depth + 0.3), wallMat, w + 0.15, h / 2, cz);
    _add(
      SceneKit.box(w * 2 + 0.6, h, 0.3),
      wallMat,
      0,
      h / 2,
      SceneConfig.backZ - 0.15,
    );
    // modern storefront: wood-slat base, big black-framed glass windows, plaster band above
    const half = SceneConfig.gateHalfWidth;
    const fz = SceneConfig.frontZ + 0.15;
    textures.slats.repeat.setValues(14, 1);
    final facadeWood = _wood(textures.slats, 0.65);
    final blackFrame = SceneKit.mat(
      AppColors.metalBlack,
      roughness: 0.4,
      metalness: 0.5,
    );
    final windowGlass = SceneKit.glass(AppColors.glass, 0.22);
    for (final sd in const [-1.0, 1.0]) {
      const winW = w - half; // 8 m of facade each side of the door
      final cx = sd * (half + winW / 2);
      _add(SceneKit.box(winW, 0.9, 0.3), facadeWood, cx, 0.45, fz); // wood base
      _add(SceneKit.box(winW, 1.6, 0.3), wallMat, cx, 3.8, fz); // plaster band
      _add(
        SceneKit.box(winW, 2.1, 0.03),
        windowGlass,
        cx,
        1.95,
        fz,
      ); // window glass
      for (var k = 0; k <= 4; k++) {
        _add(
          SceneKit.box(0.1, 2.1, 0.12),
          blackFrame,
          sd * (half + winW * k / 4),
          1.95,
          fz,
        ); // mullions
      }
      _add(SceneKit.box(winW, 0.1, 0.12), blackFrame, cx, 1.95, fz); // transom
    }
    _add(
      SceneKit.box(half * 2, h - 3.4, 0.3),
      wallMat,
      0,
      3.4 + (h - 3.4) / 2,
      fz,
    );
    // dark awning over the whole front with warm downlights
    _add(
      SceneKit.box(w * 2 + 0.6, 0.1, 1.6),
      blackFrame,
      0,
      3.7,
      SceneConfig.frontZ + 1.0,
    );
    final spots = three.InstancedMesh(
      SceneKit.sphere(0.06, 8),
      SceneKit.basic(AppColors.lampWarm),
      11,
    );
    final sm = three.Matrix4();
    for (var i = 0; i < 11; i++) {
      sm.makeTranslation(-10.0 + i * 2.0, 3.63, SceneConfig.frontZ + 1.2);
      spots.setMatrixAt(i, sm);
    }
    spots.frustumCulled = false;
    spots.instanceMatrix!.needsUpdate = true;
    _root.add(spots);
    // oak benches on the pavement
    for (final bx in const [-6.5, 6.5]) {
      _add(
        SceneKit.box(1.8, 0.08, 0.5),
        _oak,
        bx,
        0.46,
        SceneConfig.frontZ + 3.0,
      );
      for (final lx in const [-0.7, 0.7]) {
        _add(
          SceneKit.box(0.06, 0.44, 0.44),
          blackFrame,
          bx + lx,
          0.22,
          SceneConfig.frontZ + 3.0,
        );
      }
    }

    // vertical wood-slat cladding on the side walls (lower 2.5 m) with a brass line
    textures.slats.repeat.setValues(14, 1);
    final slats = _wood(textures.slats, 0.65);
    final brass = SceneKit.mat(AppColors.brass, metalness: 0.7, roughness: 0.3);
    for (final s in const [-1.0, 1.0]) {
      _add(SceneKit.box(0.06, 2.5, depth), slats, s * (w - 0.03), 1.25, cz);
      _add(SceneKit.box(0.08, 0.03, depth), brass, s * (w - 0.04), 2.52, cz);
    }
    final skirt = SceneKit.mat(AppColors.skirting);
    _add(
      SceneKit.box(w * 2, 0.12, 0.05),
      skirt,
      0,
      0.06,
      SceneConfig.backZ + 0.025,
    );

    // back wall: wood slat feature panel above the fridges with a sign
    _add(
      SceneKit.box(w * 2, 1.5, 0.08),
      slats,
      0,
      3.85,
      SceneConfig.backZ + 0.04,
    );
    final three.Texture? fresh = null; // replaced by the menu screens
    if (fresh != null) {
      _add(
        SceneKit.plane(7.0, 1.0),
        three.MeshBasicMaterial({three.MaterialProperty.map: fresh}),
        0,
        3.85,
        SceneConfig.backZ + 0.1,
      );
    }

    // dark ceiling with oak beams and warm pendant lamps (instanced)
    _add(
      SceneKit.box(w * 2 + 0.6, 0.2, depth + 0.6),
      SceneKit.mat(AppColors.ceiling, roughness: 1),
      0,
      h + 0.1,
      cz,
    );
    for (final z in const [-10.0, -6.0, -2.0, 2.0, 5.0]) {
      _add(SceneKit.box(w * 2, 0.22, 0.3), _oak, 0, h - 0.11, z);
    }
    final lamps = <List<double>>[
      for (final x in const [-6.35, 0.0, 6.35])
        for (final z in const [-8.0, -4.0, 0.0, 3.0])
          if (!(x.abs() < 1 && z < -6)) [x, z],
    ];
    final cords = three.InstancedMesh(
      SceneKit.cyl(0.008, 0.008, 0.9, 6),
      SceneKit.mat(AppColors.metalBlack),
      lamps.length,
    );
    final shades = three.InstancedMesh(
      SceneKit.cyl(0.1, 0.3, 0.26, 18),
      SceneKit.mat(AppColors.metalBlack, roughness: 0.5, metalness: 0.4),
      lamps.length,
    );
    final bulbs = three.InstancedMesh(
      SceneKit.sphere(0.09, 10),
      SceneKit.basic(AppColors.lampWarm),
      lamps.length,
    );
    final m = three.Matrix4();
    for (var i = 0; i < lamps.length; i++) {
      m.makeTranslation(lamps[i][0], h - 0.45, lamps[i][1]);
      cords.setMatrixAt(i, m);
      m.makeTranslation(lamps[i][0], h - 0.98, lamps[i][1]);
      shades.setMatrixAt(i, m);
      m.makeTranslation(lamps[i][0], h - 1.06, lamps[i][1]);
      bulbs.setMatrixAt(i, m);
    }
    for (final im in [cords, shades, bulbs]) {
      im.frustumCulled = false;
      im.instanceMatrix!.needsUpdate = true;
      _root.add(im);
    }
  }

  // ---- gate --------------------------------------------------------------
  /// Two hinged glass doors in a black metal frame that swing open.
  void _gate() {
    final frame = SceneKit.mat(
      AppColors.doorFrame,
      roughness: 0.4,
      metalness: 0.4,
    );
    const z = SceneConfig.frontZ + 0.15;
    const half = SceneConfig.gateHalfWidth;
    for (final s in const [-1.0, 1.0]) {
      _add(SceneKit.box(0.3, 3.4, 0.55), frame, s * (half + 0.15), 1.7, z);
    }
    _add(SceneKit.box(half * 2 + 0.6, 0.35, 0.55), frame, 0, 3.55, z);
    // walnut fascia sign above the door
    _add(
      SceneKit.box(6.2, 1.5, 0.22),
      _walnut,
      0,
      5.3,
      SceneConfig.frontZ + 0.3,
    );
    final canteen = textures.sign('canteen');
    if (canteen != null) {
      final sign = _add(
        SceneKit.plane(6.0, 1.5),
        three.MeshBasicMaterial({three.MaterialProperty.map: canteen}),
        0,
        5.3,
        SceneConfig.frontZ + 0.42,
      );
      sign.name = 'sign';
    }
    final glass = SceneKit.glass(AppColors.glass, 0.3);
    final brass = SceneKit.mat(
      AppColors.brass,
      metalness: 0.8,
      roughness: 0.25,
    );
    for (final hinge in const [-1.0, 1.0]) {
      final pivot = three.Group();
      pivot.name = 'gate';
      pivot.position.setValues(hinge * half, 0, SceneConfig.frontZ + 0.15);
      final panel = three.Group();
      panel.position.setValues(-hinge * 1.0, 0, 0);
      panel.add(SceneKit.mesh(SceneKit.box(1.9, 3.1, 0.03), glass, y: 1.7));
      panel.add(SceneKit.mesh(SceneKit.box(2.0, 0.12, 0.08), frame, y: 0.1));
      panel.add(SceneKit.mesh(SceneKit.box(2.0, 0.12, 0.08), frame, y: 3.3));
      for (final sx in const [-0.95, 0.95]) {
        panel.add(
          SceneKit.mesh(SceneKit.box(0.1, 3.3, 0.08), frame, x: sx, y: 1.65),
        );
      }
      final handleX = -hinge * 0.78;
      for (final hz in const [0.1, -0.1]) {
        panel.add(
          SceneKit.mesh(
            SceneKit.cyl(0.02, 0.02, 1.0, 10),
            brass,
            x: handleX,
            y: 1.2,
            z: hz,
          ),
        );
      }
      if (hinge > 0) {
        final open = textures.sign('open');
        if (open != null) {
          panel.add(
            SceneKit.mesh(
              SceneKit.plane(0.8, 0.2),
              three.MeshBasicMaterial({three.MaterialProperty.map: open}),
              y: 2.0,
              z: 0.025,
            ),
          );
        }
      }
      pivot.add(panel);
      _root.add(pivot);
      _out.doors.add(pivot);
    }
    final mat = _add(
      SceneKit.plane(3.6, 1.8),
      SceneKit.mat(AppColors.skirting, roughness: 1),
      0,
      0.02,
      SceneConfig.frontZ + 1.5,
      name: 'ground',
    );
    mat.rotation.x = -1.5708;
    final inner = _add(
      SceneKit.plane(3.6, 1.4),
      SceneKit.mat(AppColors.skirting, roughness: 1),
      0,
      0.02,
      SceneConfig.frontZ - 1.0,
      name: 'floor',
    );
    inner.rotation.x = -1.5708;
  }

  // ---- fridges: open glass-door display coolers ----------------------------
  void _fridges() {
    // Back-wall corners keep their bays; the three bays that made way for the
    // service counter moved onto the side walls near the entrance corners.
    _fridgeBay(x: -7.6, z: SceneConfig.backZ, yaw: 0, width: 3.6);
    _fridgeBay(x: 7.6, z: SceneConfig.backZ, yaw: 0, width: 3.6);
    const wall = SceneConfig.halfWidth - 0.06;
    _fridgeBay(x: -wall, z: 0.65, yaw: math.pi / 2, width: 2.9);
    _fridgeBay(x: -wall, z: 3.65, yaw: math.pi / 2, width: 2.9);
    _fridgeBay(x: wall, z: 0.65, yaw: -math.pi / 2, width: 2.9);
    _out.colliders.add(
      const Collider(-9.5, 9.5, SceneConfig.backZ, SceneConfig.backZ + 1.1),
    );
  }

  /// One open glass-door cooler. Built facing +z at the origin, then the whole
  /// group is rotated and moved into place ([yaw] pi/2 faces +x, -pi/2 faces -x).
  void _fridgeBay({
    required double x,
    required double z,
    required double yaw,
    required double width,
  }) {
    final body = SceneKit.mat(AppColors.fridgeBody, roughness: 0.5);
    final glass = SceneKit.glass(AppColors.glass, 0.16);
    final brass = SceneKit.mat(
      AppColors.brass,
      metalness: 0.8,
      roughness: 0.25,
    );
    final led = SceneKit.basic(AppColors.lampWarm);
    const shelfYs = [0.45, 1.05, 1.65, 2.25];
    final colors = <int>[
      for (final c in catalog.categories) c.color,
      0xFFFFFF,
      0xE8E0D2,
    ];
    final g = three.Group();
    void add(
      three.BufferGeometry geo,
      three.Material mat,
      double px,
      double py,
      double pz,
    ) => g.add(SceneKit.mesh(geo, mat, x: px, y: py, z: pz));

    add(SceneKit.box(width, 2.9, 0.05), body, 0, 1.45, 0.03); // back
    for (final s in const [-1.0, 1.0]) {
      add(
        SceneKit.box(0.06, 2.9, 0.95),
        body,
        s * (width / 2 - 0.03),
        1.45,
        0.5,
      ); // sides
    }
    add(SceneKit.box(width, 0.3, 0.95), body, 0, 0.15, 0.5); // plinth
    add(SceneKit.box(width, 0.25, 0.95), _oak, 0, 2.85, 0.5); // oak top
    add(SceneKit.box(width - 0.2, 0.05, 0.05), led, 0, 2.68, 0.95); // LED strip
    final goods = <List<double>>[];
    for (final y in shelfYs) {
      add(SceneKit.box(width - 0.12, 0.03, 0.9), _oak, 0, y, 0.5);
      var gx = -width / 2 + 0.25;
      var i = 0;
      while (gx < width / 2 - 0.25) {
        final h = 0.26 + ((i * 7 + y * 13).floor() % 3) * 0.05;
        goods.add([
          gx,
          y + 0.015 + h / 2,
          0.78,
          h,
          colors[(i + (y * 10).floor()) % colors.length].toDouble(),
        ]);
        gx += 0.17;
        i++;
      }
    }
    add(
      SceneKit.box(width - 0.1, 2.5, 0.03),
      glass,
      0,
      1.5,
      1.0,
    ); // glass front
    for (final s in const [-0.55, 0.55]) {
      add(
        SceneKit.box(0.04, 1.0, 0.06),
        brass,
        s * (width / 3.6),
        1.5,
        1.05,
      ); // handles
    }
    final inst = three.InstancedMesh(
      SceneKit.box(0.13, 1.0, 0.2),
      SceneKit.mat(0xFFFFFF, roughness: 0.5),
      goods.length,
    );
    inst.frustumCulled = false;
    final m = three.Matrix4();
    for (var i = 0; i < goods.length; i++) {
      final gd = goods[i];
      m.makeScale(1, gd[3], 1);
      m.setPosition(gd[0], gd[1], gd[2]);
      inst.setMatrixAt(i, m);
      inst.setColorAt(i, three.Color.fromHex32(gd[4].toInt()));
    }
    inst.instanceMatrix!.needsUpdate = true;
    inst.instanceColor!.needsUpdate = true;
    g.add(inst);
    g.position.setValues(x, 0, z);
    g.rotation.y = yaw;
    _root.add(g);

    if (yaw != 0) {
      // side-wall bay: footprint is 1.1 deep in x and [width] long in z
      final dir = yaw > 0 ? 1.0 : -1.0;
      final x2 = x + dir * 1.1;
      _out.colliders.add(
        Collider(
          x < x2 ? x : x2,
          x < x2 ? x2 : x,
          z - width / 2,
          z + width / 2,
        ),
      );
    }
  }

  // ---- service counter island (straight ahead of the door) -----------------
  /// Cream ribbed base, two glass display cabinets (bakery left, snacks right),
  /// a kitchen pass window, frosted side windows, four menu screens and
  /// copper pendant lamps. The cabinet goods are real, buyable products.
  void _serviceCounter() {
    const zBack = SceneConfig.backZ;
    const cz = zBack + 0.95; // island centre
    const depth = 1.5;
    const front = cz + depth / 2; // z of the glass front
    const baseH = 0.85;
    const cabW = 3.0;
    const midW = 1.2;
    const cabCx = midW / 2 + cabW / 2;
    const half = midW / 2 + cabW;
    final cream = SceneKit.mat(0xEFE2C8, roughness: 0.8);
    final creamDark = SceneKit.mat(0xDCC9A6, roughness: 0.8);
    final black = SceneKit.mat(0x14161A, roughness: 0.35, metalness: 0.4);
    final steel = SceneKit.mat(0xC9CDD2, roughness: 0.3, metalness: 0.8);
    final glass = SceneKit.glass(AppColors.glass, 0.12);
    final copper = SceneKit.mat(0xB87333, roughness: 0.3, metalness: 0.85);

    // ribbed base: slats over a solid core, centre block taller
    for (final side in const [-1.0, 1.0]) {
      _add(
        SceneKit.box(cabW, baseH - 0.05, depth - 0.06),
        creamDark,
        side * cabCx,
        (baseH - 0.05) / 2,
        cz,
      );
      for (var i = 0; i < 20; i++) {
        final x = side * cabCx - cabW / 2 + 0.075 + i * (cabW - 0.15) / 19;
        _add(
          SceneKit.box(0.06, baseH - 0.05, 0.05),
          cream,
          x,
          (baseH - 0.05) / 2,
          front + 0.02,
        );
      }
    }
    _add(SceneKit.box(midW, 1.25, depth), creamDark, 0, 0.625, cz);
    for (var i = 0; i < 12; i++) {
      final x = -midW / 2 + 0.06 + i * (midW - 0.12) / 11;
      _add(SceneKit.box(0.06, 1.2, 0.05), cream, x, 0.62, front + 0.03);
    }
    _add(SceneKit.box(midW + 0.1, 0.05, depth + 0.1), cream, 0, 1.275, cz);

    // glass cabinets
    const shelfYs = [0.98, 1.3, 1.62];
    final specs = <({double side, List<String> ids})>[
      (side: -1.0, ids: ['cake', 'donut', 'croissant', 'muffin']),
      (side: 1.0, ids: ['sandwich', 'burger', 'yogurt', 'orange']),
    ];
    for (final c in specs) {
      final cx = c.side * cabCx;
      const top = baseH + 1.12;
      _add(SceneKit.box(cabW, 0.05, depth), black, cx, baseH + 0.025, cz);
      _add(SceneKit.box(cabW, 0.05, depth + 0.06), black, cx, top + 0.025, cz);
      for (final sx in const [-1.0, 1.0]) {
        _add(
          SceneKit.box(0.05, 1.12, 0.05),
          black,
          cx + sx * (cabW / 2 - 0.025),
          baseH + 0.56,
          front - 0.03,
        );
        _add(
          SceneKit.box(0.03, 1.12, depth - 0.1),
          glass,
          cx + sx * (cabW / 2 - 0.02),
          baseH + 0.56,
          cz,
          name: 'glass',
        );
      }
      _add(
        SceneKit.box(cabW - 0.1, 0.9, 0.04),
        SceneKit.mat(0xE9E4DA, roughness: 0.6),
        cx,
        baseH + 0.6,
        zBack + 0.35,
      );
      for (final y in shelfYs) {
        _add(
          SceneKit.box(cabW - 0.1, 0.025, depth - 0.2),
          steel,
          cx,
          y,
          cz - 0.02,
        );
      }
      _add(
        SceneKit.box(cabW - 0.1, 1.07, 0.025),
        glass,
        cx,
        baseH + 0.575,
        front - 0.03,
        name: 'glass',
      );

      final items = <Product>[
        for (final id in c.ids)
          for (final p in catalog.products)
            if (p.id == id) p,
      ];
      if (items.isEmpty) continue;
      for (var l = 0; l < shelfYs.length; l++) {
        final y0 = shelfYs[l] + 0.0125;
        var x = cx - cabW / 2 + 0.22;
        final xEnd = cx + cabW / 2 - 0.22;
        var k = l;
        var item = items[k % items.length];
        var run = 0;
        var runStart = true;
        while (true) {
          final spec = PackageSpec.of(item);
          if (x + spec.width > xEnd) break;
          _places.add(
            _Place(
              item,
              x + spec.width / 2,
              y0 + spec.height / 2,
              front - 0.2 - spec.depth / 2,
              0,
              faceZ: true,
            ),
          );
          if (runStart) {
            (_tagsZ[item.id] ??= []).add([
              x + 0.11,
              shelfYs[l] + 0.045,
              front - 0.06,
            ]);
            runStart = false;
          }
          x += spec.width + 0.03;
          run++;
          if (run >= 3) {
            run = 0;
            k++;
            item = items[k % items.length];
            runStart = true;
            x += 0.06;
          }
        }
      }
    }
    _out.colliders.add(Collider(-half - 0.1, half + 0.1, zBack, front + 0.05));

    // kitchen pass window on the wall above the island
    const wz = zBack + 0.07;
    _add(
      SceneKit.box(7.4, 1.3, 0.04),
      SceneKit.mat(0xE4E0D8),
      0,
      2.3,
      zBack + 0.03,
    );
    for (final y in const [1.62, 2.98]) {
      _add(SceneKit.box(7.6, 0.1, 0.1), black, 0, y, wz);
    }
    for (final x in const [-3.75, 3.75]) {
      _add(SceneKit.box(0.1, 1.46, 0.1), black, x, 2.3, wz);
    }
    _add(SceneKit.box(7.2, 0.05, 0.5), steel, 0, 1.7, zBack + 0.3);
    for (final x in const [-1.2, 0.9]) {
      final shirt = SceneKit.mat(x < 0 ? 0x5A1E2B : 0xF2F2F0);
      _add(SceneKit.box(0.5, 0.65, 0.3), shirt, x, 2.1, zBack + 0.5);
      _add(
        SceneKit.sphere(0.13),
        SceneKit.mat(AppColors.skin),
        x,
        2.57,
        zBack + 0.5,
      );
      _add(
        SceneKit.cyl(0.14, 0.15, 0.14, 12),
        SceneKit.mat(0xF4F4F2),
        x,
        2.74,
        zBack + 0.5,
      );
    }
    _add(
      SceneKit.box(0.45, 0.25, 0.3),
      SceneKit.mat(0x2A2D31, metalness: 0.4),
      2.4,
      1.85,
      zBack + 0.35,
    );

    // frosted side windows
    final frost = SceneKit.glass(0xDCE6EA, 0.55);
    for (final s in const [-1.0, 1.0]) {
      final x = s * 4.7;
      _add(SceneKit.box(1.8, 1.8, 0.03), frost, x, 1.85, zBack + 0.05);
      for (final y in const [0.93, 2.77]) {
        _add(SceneKit.box(1.9, 0.08, 0.08), black, x, y, zBack + 0.06);
      }
      for (final dx in const [-0.95, 0.95]) {
        _add(SceneKit.box(0.08, 1.9, 0.08), black, x + dx, 1.85, zBack + 0.06);
      }
    }

    // four menu screens on the slat panel
    const labels = ['menu_video', 'menu_a', 'menu_b', 'menu_cake'];
    for (var i = 0; i < 4; i++) {
      final x = -2.445 + i * 1.63;
      _add(SceneKit.box(1.58, 0.92, 0.05), black, x, 3.78, zBack + 0.1);
      final tex = textures.sign(labels[i]);
      _add(
        SceneKit.plane(1.5, 0.84),
        tex != null
            ? three.MeshBasicMaterial({three.MaterialProperty.map: tex})
            : SceneKit.basic(0x2A2D31),
        x,
        3.78,
        zBack + 0.14,
      );
    }

    // copper cone pendants over the island
    for (final x in const [-2.4, 0.0, 2.4]) {
      const h = SceneConfig.wallHeight;
      _add(SceneKit.cyl(0.008, 0.008, 1.3, 6), black, x, h - 0.65, cz);
      _add(SceneKit.cyl(0.05, 0.22, 0.4, 18), copper, x, h - 1.5, cz);
      _add(
        SceneKit.sphere(0.07, 10),
        SceneKit.basic(AppColors.lampWarm),
        x,
        h - 1.68,
        cz,
      );
    }
  }

  // ---- checkout counter ---------------------------------------------------
  void _counter() {
    _add(SceneKit.box(3.0, 1.0, 1.0), _walnut, 7.0, 0.5, 3.6);
    _add(SceneKit.box(3.2, 0.06, 1.2), _oak, 7.0, 1.03, 3.6);
    _add(
      SceneKit.box(1.4, 0.04, 0.5),
      SceneKit.mat(0x1E2125),
      6.5,
      1.08,
      3.6,
    ); // belt
    _add(
      SceneKit.box(0.35, 0.28, 0.04),
      SceneKit.mat(0x111315),
      7.8,
      1.3,
      3.4,
    ); // POS screen
    _add(
      SceneKit.box(0.06, 0.2, 0.06),
      SceneKit.mat(AppColors.doorSilver),
      7.8,
      1.17,
      3.4,
    );
    _out.colliders.add(const Collider(5.4, 8.6, 2.9, 4.3));
  }

  // ---- plants: pots with real leaves ---------------------------------------
  void _plants() {
    const spots = [
      [9.0, 4.8, 1.0],
      [-9.0, -10.6, 1.2],
      [9.0, -10.6, 1.2],
      [-2.9, 4.9, 0.8],
      [2.9, 4.9, 0.8],
      [-5.4, -10.7, 0.9],
      [5.4, -10.7, 0.9],
    ];
    final leaves = <three.Matrix4>[];
    final colors = <int>[];
    const greens = [0x2F6B34, 0x3E8A43, 0x4F9E4B, 0x2A5E32];
    final potA = SceneKit.mat(AppColors.charcoal, roughness: 0.4);
    final potB = SceneKit.mat(AppColors.terracotta, roughness: 0.7);
    final soil = SceneKit.mat(0x3A2A1E, roughness: 1);
    var seed = 0;
    var n = 0;
    for (final s in spots) {
      final x = s[0], z = s[1], k = s[2];
      final pot = (n++ % 2 == 0) ? potA : potB;
      _add(SceneKit.cyl(0.26 * k, 0.19 * k, 0.5 * k, 16), pot, x, 0.25 * k, z);
      _add(SceneKit.cyl(0.25 * k, 0.25 * k, 0.02, 16), soil, x, 0.5 * k, z);
      _add(SceneKit.torus(0.25 * k, 0.018 * k), pot, x, 0.5 * k, z).rotation.x =
          math.pi / 2;
      for (var i = 0; i < 16; i++) {
        seed++;
        final r = (math.sin(seed * 12.9898) * 43758.5453).abs() % 1;
        final yaw = i * 2.39996;
        final tilt = 0.18 + (i % 4) * 0.16 + r * 0.1;
        final len = (0.55 + r * 0.45 + (i % 3) * 0.12) * k;
        final m = three.Matrix4().makeTranslation(x, 0.5 * k, z);
        m.multiply(three.Matrix4().makeRotationY(yaw));
        m.multiply(three.Matrix4().makeRotationX(tilt));
        m.multiply(three.Matrix4().makeTranslation(0, len / 2, 0));
        m.multiply(three.Matrix4().makeScale(0.075 * k, len / 2, 0.02));
        leaves.add(m);
        colors.add(greens[i % greens.length]);
      }
      _out.colliders.add(
        Collider(x - 0.3 * k, x + 0.3 * k, z - 0.3 * k, z + 0.3 * k),
      );
    }
    final mesh = three.InstancedMesh(
      SceneKit.sphere(1, 10),
      SceneKit.mat(0xFFFFFF, roughness: 0.6),
      leaves.length,
    );
    mesh.frustumCulled = false;
    for (var i = 0; i < leaves.length; i++) {
      mesh.setMatrixAt(i, leaves[i]);
      mesh.setColorAt(i, three.Color.fromHex32(colors[i]));
    }
    mesh.instanceMatrix!.needsUpdate = true;
    mesh.instanceColor!.needsUpdate = true;
    _root.add(mesh);
  }

  // ---- shelves ------------------------------------------------------------
  void _shelves() {
    final cats = catalog.categories;
    const wx = SceneConfig.wallShelfX;
    const ix = SceneConfig.innerShelfX;
    final units = <({double x, List<int> sides})>[
      (x: -wx, sides: [1]),
      (x: -ix, sides: [-1, 1]),
      (x: ix, sides: [-1, 1]),
      (x: wx, sides: [-1]),
    ];
    var catIndex = 0;
    for (final u in units) {
      final faces = <ShelfFace>[];
      for (final s in u.sides) {
        final cat = cats[catIndex % cats.length];
        catIndex++;
        faces.add(ShelfFace(cat, u.x + s * SceneConfig.shelfDepth / 2, s, u.x));
      }
      _unit(u.x, faces);
      _out.faces.addAll(faces);
      final minX = u.x - (u.sides.contains(-1) ? SceneConfig.shelfDepth : 0.08);
      final maxX = u.x + (u.sides.contains(1) ? SceneConfig.shelfDepth : 0.08);
      _out.colliders.add(
        Collider(
          minX,
          maxX,
          SceneConfig.shelfZStart - 0.1,
          SceneConfig.shelfZEnd + 0.1,
        ),
      );
      for (final f in faces) {
        _fillFace(f);
      }
    }
  }

  /// A wooden gondola: oak boards, walnut back and base, black metal posts,
  /// a dark rail for the white price tags and a walnut header with the name.
  void _unit(double x0, List<ShelfFace> faces) {
    const len = SceneConfig.shelfZEnd - SceneConfig.shelfZStart;
    const cz = (SceneConfig.shelfZEnd + SceneConfig.shelfZStart) / 2;
    const h = SceneConfig.shelfHeight;
    const d = SceneConfig.shelfDepth;
    final metal = SceneKit.mat(
      AppColors.metalBlack,
      roughness: 0.4,
      metalness: 0.5,
    );
    final unitMinX = x0 - (faces.any((f) => f.side < 0) ? d : 0.06);
    final unitMaxX = x0 + (faces.any((f) => f.side > 0) ? d : 0.06);
    final unitW = unitMaxX - unitMinX;
    final unitCx = (unitMinX + unitMaxX) / 2;
    _add(SceneKit.box(0.08, h, len), _walnut, x0, h / 2, cz);
    for (final z in const [
      SceneConfig.shelfZStart,
      (SceneConfig.shelfZStart + SceneConfig.shelfZEnd) / 2,
      SceneConfig.shelfZEnd,
    ]) {
      _add(SceneKit.box(0.1, h, 0.07), metal, x0, h / 2, z);
    }
    _add(
      SceneKit.box(unitW + 0.04, 0.22, len + 0.04),
      _walnut,
      unitCx,
      0.11,
      cz,
    );
    _add(SceneKit.box(unitW + 0.04, 0.08, len + 0.08), _oak, unitCx, h, cz);
    for (final f in faces) {
      final color = SceneKit.mat(f.category.color);
      final fx = x0 + f.side * d / 2;
      for (final level in SceneConfig.boardHeights) {
        _add(SceneKit.box(d, 0.04, len), _oak, fx, level, cz);
        _add(
          SceneKit.box(0.03, 0.04, len),
          _oak,
          x0 + f.side * (d - 0.015),
          level + 0.025,
          cz,
        );
        _add(
          SceneKit.box(0.02, 0.1, len - 0.06),
          metal,
          x0 + f.side * (d + 0.005),
          level - 0.05,
          cz,
        );
      }
      // oak end caps with a category-colour band so the aisle is recognisable from afar
      for (final z in const [SceneConfig.shelfZStart, SceneConfig.shelfZEnd]) {
        _add(SceneKit.box(d, h, 0.08), _oak, fx, h / 2, z);
        _add(SceneKit.box(d + 0.01, 0.35, 0.09), color, fx, h - 0.35, z);
      }
      // walnut header board with a category-colour stripe and the name
      final hx = x0 + f.side * 0.1;
      _add(SceneKit.box(0.1, 0.95, 4.1), _walnut, hx, h + 0.55, cz);
      _add(SceneKit.box(0.11, 0.1, 4.1), color, hx, h + 0.12, cz);
      final tex = textures.sign(f.category.id);
      if (tex != null) {
        final plane = _add(
          SceneKit.plane(3.7, 0.925),
          three.MeshBasicMaterial({three.MaterialProperty.map: tex}),
          hx + f.side * 0.06,
          h + 0.6,
          cz,
        );
        plane.rotation.y = f.side > 0 ? 1.5708 : -1.5708;
      }
    }
  }

  // ---- products: packed rows like a real shelf ----------------------------

  /// Fills every board of [f] edge to edge with runs of the same product,
  /// front-facing, like a supermarket gondola, with a price tag per run.
  void _fillFace(ShelfFace f) {
    final items = catalog.productsIn(f.category);
    if (items.isEmpty) return;
    const d = SceneConfig.shelfDepth;
    const zEnd = SceneConfig.shelfZEnd - 0.12;
    var k = 0;
    for (var l = 0; l < SceneConfig.boardHeights.length; l++) {
      final y0 = SceneConfig.boardHeights[l] + 0.022;
      var z = SceneConfig.shelfZStart + 0.12;
      var run = 0;
      var item = items[(k + l) % items.length];
      var runLen = 3 + ((k + l) % 2);
      var runStart = true;
      while (true) {
        final spec = PackageSpec.of(item);
        if (z + spec.width > zEnd) break;
        final x = f.unitX + f.side * (d - 0.035 - spec.depth / 2);
        _places.add(
          _Place(item, x, y0 + spec.height / 2, z + spec.width / 2, f.side),
        );
        if (runStart) {
          (_tags[item.id] ??= []).add([
            f.unitX + f.side * (d + 0.017),
            SceneConfig.boardHeights[l] - 0.058,
            z + 0.11,
          ]);
          runStart = false;
        }
        z += spec.width + 0.015;
        run++;
        if (run >= runLen) {
          run = 0;
          k++;
          item = items[(k + l) % items.length];
          runLen = 3 + ((k + l) % 2);
          runStart = true;
          z += 0.03;
        }
      }
    }
  }

  /// One InstancedMesh per product (one draw call each) + one per price tag.
  void _buildProducts() {
    final byProduct = <String, List<_Place>>{};
    for (final p in _places) {
      byProduct.putIfAbsent(p.product.id, () => []).add(p);
    }
    final m = three.Matrix4();
    final q = three.Quaternion();
    final pos = three.Vector3();
    final scale = three.Vector3(1, 1, 1);
    for (final entry in byProduct.entries) {
      final list = entry.value;
      final product = list.first.product;
      final spec = PackageSpec.of(product);
      final cluster = spec.cluster;
      final per = cluster == null ? 1 : cluster.length;
      final mesh = three.InstancedMesh(
        spec.geometry(),
        spec.material(product, textures),
        list.length * per,
      );
      mesh.name = 'product:${entry.key}';
      mesh.frustumCulled = false;
      var i = 0;
      final spots = <ProductSpot>[];
      for (final pl in list) {
        final yaw =
            (pl.faceZ ? 0.0 : (pl.side > 0 ? math.pi / 2 : -math.pi / 2)) +
            spec.labelYaw;
        q.setFromAxisAngle(three.Vector3(0, 1, 0), yaw);
        if (cluster == null) {
          pos.setValues(pl.x, pl.y, pl.z);
          scale.setValues(1, 1, 1);
          m.compose(pos, q, scale);
          mesh.setMatrixAt(i++, m);
        } else {
          final cy = math.cos(yaw), sy = math.sin(yaw);
          for (final o in cluster) {
            final lx = o[0], lz = o[2];
            pos.setValues(
              pl.x + lx * cy + lz * sy,
              pl.y - spec.height / 2 + spec.clusterBaseY + o[1],
              pl.z - lx * sy + lz * cy,
            );
            scale.setValues(1, 1, 1);
            m.compose(pos, q, scale);
            mesh.setMatrixAt(i++, m);
          }
        }
        spots.add(
          ProductSpot(
            product,
            three.Vector3(pl.x, pl.y, pl.z),
            pl.side,
            faceZ: pl.faceZ,
          ),
        );
      }
      mesh.instanceMatrix!.needsUpdate = true;
      _root.add(mesh);
      _out.groups[entry.key] = ProductGroup(mesh, spots, per);
    }

    // price tags with the product name and price, one instanced mesh per product
    q.setFromAxisAngle(three.Vector3(0, 1, 0), 0);
    scale.setValues(1, 1, 1);
    for (final e in _tags.entries) {
      final tex = textures.tag(e.key);
      if (tex == null) continue;
      final mat = three.MeshBasicMaterial({three.MaterialProperty.map: tex});
      final tags = three.InstancedMesh(
        SceneKit.box(0.012, 0.084, 0.2),
        mat,
        e.value.length,
      );
      tags.name = 'tag';
      tags.frustumCulled = false;
      for (var i = 0; i < e.value.length; i++) {
        pos.setValues(e.value[i][0], e.value[i][1], e.value[i][2]);
        m.compose(pos, q, scale);
        tags.setMatrixAt(i, m);
      }
      tags.instanceMatrix!.needsUpdate = true;
      _root.add(tags);
    }
    for (final e in _tagsZ.entries) {
      final tex = textures.tag(e.key);
      if (tex == null) continue;
      final tags = three.InstancedMesh(
        SceneKit.box(0.2, 0.084, 0.012),
        three.MeshBasicMaterial({three.MaterialProperty.map: tex}),
        e.value.length,
      );
      tags.name = 'tag';
      tags.frustumCulled = false;
      for (var i = 0; i < e.value.length; i++) {
        pos.setValues(e.value[i][0], e.value[i][1], e.value[i][2]);
        m.compose(pos, q, scale);
        tags.setMatrixAt(i, m);
      }
      tags.instanceMatrix!.needsUpdate = true;
      _root.add(tags);
    }
  }
}
