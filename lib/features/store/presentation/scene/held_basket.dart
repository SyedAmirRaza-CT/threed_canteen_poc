import 'dart:math' as math;

import 'package:three_js/three_js.dart' as three;

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/basket.dart';
import 'product_package.dart';
import 'scene_kit.dart';
import 'scene_textures.dart';

class _Fall {
  _Fall(this.obj, this.toY);
  final three.Object3D obj;
  final double toY;
  double t = -0.35; // waits for the hand to rise first
}

/// A red plastic supermarket hand basket held by the shopper's hand, attached
/// to the camera. It only appears when something is picked up: the hand rises
/// from the bottom of the screen, the item drops in, then it lowers again.
///
/// Real size of a hand basket is about 42 x 30 x 20 cm (the model uses metres).
class HeldBasket {
  HeldBasket(this._textures) {
    _buildBasket();
    _buildHand();
    rig.visible = false;
  }

  /// Add this to the camera.
  final three.Group rig = three.Group();
  final three.Group _contents = three.Group();
  final List<_Fall> _falls = [];
  final SceneTextures _textures;

  static const int maxShown = 16;
  static const double _itemScale = 0.4;
  static const double _floorY = -0.09;
  static const double _rimY = 0.1;
  static const double _gripY = 0.315;

  /// Rest spots inside the basket: x, z, level.
  static const _slots = <List<double>>[
    [-0.135, -0.05, 0],
    [-0.045, -0.05, 0],
    [0.045, -0.05, 0],
    [0.135, -0.05, 0],
    [-0.135, 0.05, 0],
    [-0.045, 0.05, 0],
    [0.045, 0.05, 0],
    [0.135, 0.05, 0],
    [-0.09, -0.05, 1],
    [0.0, -0.05, 1],
    [0.09, -0.05, 1],
    [-0.14, 0.0, 1],
    [-0.09, 0.05, 1],
    [0.0, 0.05, 1],
    [0.09, 0.05, 1],
    [0.14, 0.0, 1],
  ];

  /// 0 = hand hidden below the screen, 1 = basket raised in view.
  double _presence = 0;
  double _holdTimer = 0;
  static const double _holdSeconds = 2.6;
  double _sway = 0;
  double _lastYaw = 0;
  double _bobY = 0;
  double _newestY = _floorY;

  bool get isShown => _presence > 0.02;

  // ---- model -----------------------------------------------------------------

  void _buildBasket() {
    final red = SceneKit.mat(AppColors.basketRed, roughness: 0.45);
    final dark = SceneKit.mat(AppColors.basketDark, roughness: 0.6);
    final silver = SceneKit.mat(
      AppColors.doorSilver,
      metalness: 0.85,
      roughness: 0.25,
    );

    // tapered rectangular body: a 4-sided open cone, turned square, stretched along x
    final body = three.Group()..scale.x = 1.4;
    final outer = SceneKit.mesh(
      three.CylinderGeometry(0.212, 0.17, 0.2, 4, 1, true),
      red,
    );
    outer.rotation.y = math.pi / 4;
    body.add(outer);
    final innerMat = three.MeshStandardMaterial({
      three.MaterialProperty.color: AppColors.basketDark,
      three.MaterialProperty.roughness: 0.7,
      three.MaterialProperty.side: three.BackSide,
    });
    final inner = SceneKit.mesh(
      three.CylinderGeometry(0.205, 0.164, 0.196, 4, 1, true),
      innerMat,
    );
    inner.rotation.y = math.pi / 4;
    body.add(inner);
    rig.add(body);
    final floor = SceneKit.mesh(
      SceneKit.plane(0.3, 0.2),
      dark,
      y: _floorY + 0.004,
    );
    floor.rotation.x = -math.pi / 2;
    rig.add(floor);

    // vent slots on both long sides
    final slot = SceneKit.mat(0x2A0D0C);
    for (final z in const [0.137, -0.137]) {
      for (final x in const [-0.15, -0.075, 0.0, 0.075, 0.15]) {
        rig.add(
          SceneKit.mesh(
            SceneKit.box(0.034, 0.09, 0.006),
            slot,
            x: x,
            y: 0.0,
            z: z,
          ),
        );
      }
    }

    // rim
    for (final z in const [0.157, -0.157]) {
      rig.add(
        SceneKit.mesh(SceneKit.box(0.45, 0.022, 0.022), red, y: _rimY, z: z),
      );
    }
    for (final x in const [0.222, -0.222]) {
      rig.add(
        SceneKit.mesh(SceneKit.box(0.022, 0.022, 0.33), red, x: x, y: _rimY),
      );
    }

    // metal arch handle over the opening + rubber grip
    final arch = SceneKit.mesh(
      three.TorusGeometry(0.22, 0.008, 8, 28, math.pi),
      silver,
      y: _rimY,
    );
    rig.add(arch);
    final grip = SceneKit.mesh(
      SceneKit.cyl(0.02, 0.02, 0.13, 14),
      SceneKit.mat(0x1E1E20, roughness: 0.9),
      y: _gripY + 0.005,
    );
    grip.rotation.z = math.pi / 2;
    rig.add(grip);

    rig.add(_contents);
  }

  /// A right hand curled around the grip (fingers over the top, curled under),
  /// with a watch, white cuff and a sleeve coming from the bottom of the screen.
  void _buildHand() {
    final skin = SceneKit.mat(AppColors.skin, roughness: 0.55);
    final shade = SceneKit.mat(AppColors.skinShade, roughness: 0.6);
    const g = _gripY + 0.005;
    final hand = three.Group()..position.setValues(0, g, 0);
    const r = 0.0105;

    hand.add(
      SceneKit.mesh(SceneKit.box(0.096, 0.03, 0.085), skin, y: 0.034, z: 0.052),
    ); // palm / back of hand
    for (final x in const [-0.0405, -0.0135, 0.0135, 0.0405]) {
      final len = x.abs() < 0.02 ? 1.0 : 0.88; // middle fingers are longer
      hand.add(
        SceneKit.mesh(SceneKit.sphere(r, 8), skin, x: x, y: 0.034, z: 0.012),
      ); // knuckle
      final p = SceneKit.mesh(
        SceneKit.cyl(r, r, 0.05, 8),
        skin,
        x: x,
        y: 0.034,
        z: -0.014,
      );
      p.rotation.x = math.pi / 2;
      hand.add(p); // proximal: over the top of the grip
      hand.add(
        SceneKit.mesh(SceneKit.sphere(r, 8), skin, x: x, y: 0.034, z: -0.04),
      );
      hand.add(
        SceneKit.mesh(
          SceneKit.cyl(r, r, 0.052 * len, 8),
          skin,
          x: x,
          y: 0.007,
          z: -0.04,
        ),
      ); // middle: down the far side
      hand.add(
        SceneKit.mesh(
          SceneKit.sphere(r, 8),
          shade,
          x: x,
          y: -0.02 - 0.0 * len,
          z: -0.04,
        ),
      );
      final d = SceneKit.mesh(
        SceneKit.cyl(r * 0.95, r * 0.95, 0.04 * len, 8),
        skin,
        x: x,
        y: -0.028,
        z: -0.022,
      );
      d.rotation.x = math.pi / 2;
      hand.add(d); // distal: curls under the grip
    }
    // thumb wraps from the near side underneath
    hand.add(
      SceneKit.mesh(
        SceneKit.sphere(0.0125, 8),
        skin,
        x: -0.055,
        y: 0.026,
        z: 0.062,
      ),
    );
    final t1 = SceneKit.mesh(
      SceneKit.cyl(0.0125, 0.0115, 0.06, 8),
      skin,
      x: -0.05,
      y: 0.0,
      z: 0.052,
    );
    t1.rotation.x = 0.35;
    hand.add(t1);
    final t2 = SceneKit.mesh(
      SceneKit.cyl(0.0115, 0.0105, 0.05, 8),
      skin,
      x: -0.04,
      y: -0.03,
      z: 0.03,
    );
    t2.rotation.x = math.pi / 2 - 0.2;
    hand.add(t2);
    hand.add(
      SceneKit.mesh(
        SceneKit.sphere(0.0105, 8),
        shade,
        x: -0.04,
        y: -0.034,
        z: 0.002,
      ),
    );
    rig.add(hand);

    // arm: wrist -> cuff -> sleeve, pointing toward the camera and down
    final arm = three.Group();
    arm.position.setValues(0.0, g + 0.04, 0.1);
    arm.rotation.x = 1.9;
    arm.rotation.z = -0.35;
    arm.add(SceneKit.mesh(SceneKit.cyl(0.028, 0.033, 0.12, 12), skin, y: 0.06));
    final watch = SceneKit.mesh(
      SceneKit.cyl(0.036, 0.036, 0.03, 16),
      SceneKit.mat(0x15171A, roughness: 0.4),
      y: 0.085,
    );
    arm.add(watch);
    arm.add(
      SceneKit.mesh(
        SceneKit.box(0.045, 0.004, 0.035),
        SceneKit.mat(AppColors.doorSilver, metalness: 0.9, roughness: 0.2),
        y: 0.085,
        z: 0.034,
      )..rotation.x = 0,
    );
    arm.add(
      SceneKit.mesh(
        SceneKit.cyl(0.043, 0.045, 0.04, 14),
        SceneKit.mat(AppColors.cuff, roughness: 0.9),
        y: 0.14,
      ),
    );
    arm.add(
      SceneKit.mesh(
        SceneKit.cyl(0.05, 0.07, 0.7, 14),
        SceneKit.mat(AppColors.sleeve, roughness: 0.95),
        y: 0.51,
      ),
    );
    rig.add(arm);
  }

  // ---- behaviour ----------------------------------------------------------------

  /// Keep the basket on screen in portrait, landscape, phone and tablet.
  void layout(double aspect, double fovDeg) {
    const d = 0.8;
    final halfH = d * math.tan(fovDeg * math.pi / 360);
    final halfW = halfH * aspect;
    final scale = math.min(0.8, halfW / 0.6);
    final x = math.min(halfW * 0.42, 0.3);
    final y = -halfH * 0.62;
    final lift = (1 - _ease(_presence)) * -halfH * 0.95;
    rig.position.setValues(x, y + _bobY + lift, -d);
    rig.scale.setValues(scale, scale, scale);
    rig.rotation.x = 0.55;
    rig.rotation.y = -0.2;
    rig.rotation.z = _sway;
  }

  double _ease(double t) => t * t * (3 - 2 * t);

  void update(
    double dt, {
    required double yaw,
    required double walkPhase,
    required bool walking,
  }) {
    if (_holdTimer > 0) _holdTimer -= dt;
    final goal = _holdTimer > 0 ? 1.0 : 0.0;
    _presence += (goal - _presence).clamp(-dt / 0.4, dt / 0.35);
    rig.visible = isShown;
    _bobY = walking ? math.sin(walkPhase * 9) * 0.012 : _bobY * 0.8;
    var dyaw = yaw - _lastYaw;
    _lastYaw = yaw;
    if (dyaw > math.pi) dyaw -= 2 * math.pi;
    if (dyaw < -math.pi) dyaw += 2 * math.pi;
    final target = (-dyaw / math.max(dt, 0.001) * 0.04).clamp(-0.25, 0.25);
    _sway += (target - _sway) * math.min(1, dt * 8);
    for (final f in List.of(_falls)) {
      f.t = math.min(1, f.t + dt / 0.45);
      final e = 1 - math.pow(1 - f.t.clamp(0, 1), 3);
      f.obj.position.y = f.toY + (1 - e) * 0.55;
      if (f.t >= 1) _falls.remove(f);
    }
  }

  /// Rebuilds what is shown inside. When [justAdded] is set, its newest copy
  /// drops in from above and the hand rises to show it.
  void sync(List<BasketLine> lines, {String? justAdded}) {
    for (final c in List.of(_contents.children)) {
      _contents.remove(c);
    }
    _falls.clear();
    var k = 0;
    three.Object3D? newest;
    for (final line in lines) {
      for (var q = 0; q < line.quantity && k < maxShown; q++, k++) {
        final s = _slots[k];
        final obj = PackageSpec.of(line.product)
            .build(line.product, _textures, scale: _itemScale);
        final y = _floorY + 0.008 + s[2] * 0.11;
        obj.position.setValues(s[0], y, s[1]);
        obj.rotation.y =
            ((k * 37) % 21 - 10) * 0.03; // slightly messy, like real items
        _contents.add(obj);
        if (line.product.id == justAdded) {
          newest = obj;
          _newestY = y;
        }
      }
    }
    if (justAdded != null) _holdTimer = _holdSeconds;
    if (newest != null) {
      _falls.add(_Fall(newest, _newestY));
      newest.position.y = _newestY + 0.55;
    }
  }
}
