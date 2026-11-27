import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:material_ui/material_ui.dart' show Widget;
import 'package:three_js/three_js.dart' as three;

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/basket.dart';
import '../../domain/entities/product.dart';
import '../providers/store_provider.dart';
import 'held_basket.dart';
import 'product_package.dart';
import 'scene_config.dart';
import 'scene_kit.dart';
import 'scene_textures.dart';
import 'store_builder.dart';

/// Owns the 3D world: builds it, moves the first-person camera, picks
/// products, runs the door-opening walk-in and shows the basket in the
/// shopper's hand when something is picked up.
///
/// Controls: one-finger swipe or scroll to walk and slide, two fingers or the
/// turn buttons to look around, tap the floor to walk there, tap a product.
class StoreScene {
  StoreScene({
    required this.catalog,
    required this.pixelRatio,
    required this.onProductTapped,
    required this.onBasketTapped,
    required this.onAisleChanged,
    required this.onPhaseChanged,
    required this.onReady,
  });

  final StoreCatalog catalog;
  final double pixelRatio;
  final void Function(Product product) onProductTapped;
  final void Function() onBasketTapped;
  final void Function(String aisle) onAisleChanged;
  final void Function(StorePhase phase) onPhaseChanged;
  final void Function() onReady;

  /// Created once. Never recreate it: that would restart setup and show the loader again.
  late final three.ThreeJS threeJs = three.ThreeJS(
    settings: three.Settings(
      enableShadowMap: false,
      stencil: false,
      antialias: true,
      screenResolution: pixelRatio.clamp(1.0, 2.0),
    ),
    onSetupComplete: _markReady,
    setup: _setup,
  );

  StoreBuild? _build;
  SceneTextures? _textures;

  // Product showcase: the tapped item lifts off its shelf, spins and settles
  // in the centre of the view while the detail sheet is open.
  three.Group? _showcase;
  ProductGroup? _showcaseGroup;
  int _showcaseIdx = -1;
  double _showcaseT = 0;
  double _showcaseSpin = 0;
  final three.Vector3 _showcaseFrom = three.Vector3();

  /// Landscape: the detail panel takes the right side, so the item rests in
  /// the free area on the left. Portrait: above the bottom sheet.
  bool get _showcaseLandscape => threeJs.width > threeJs.height;
  HeldBasket? _held;
  three.Mesh? _marker;
  List<BasketLine>? _pendingLines;
  Map<String, int>? _pendingShelf;
  ({String id, int index})? _lastTap;
  final three.Raycaster _ray = three.Raycaster();
  bool _readyCalled = false;
  bool _disposed = false;

  StorePhase _phase = StorePhase.outside;

  // Camera state. The real yaw eases towards [_yawTarget] for smooth turning.
  double _yaw = 0; // 0 faces -z
  double _yawTarget = 0;
  double _pitch = SceneConfig.lookPitch;
  double _pitchTarget = SceneConfig.lookPitch;
  double _fov = SceneConfig.fov; // diagonal angle; pinch zoom changes this
  double _vfov = SceneConfig.fov; // vertical angle derived from it each frame
  final three.Vector3 _pos = three.Vector3(
    0,
    SceneConfig.eyeHeight,
    SceneConfig.startZ,
  );
  three.Vector3? _target;
  ProductSpot? _pendingSpot;
  double _walkPhase = 0;
  double _moveTimer = 0; // > 0 while moving (head bob)
  double _clock = 0;

  // Movement inputs
  double _pendingForward =
      0; // metres still to walk from swipes/scroll (eased out)
  double _pendingStrafe = 0; // metres still to slide sideways (right is +)
  double _keyForward = 0, _keyStrafe = 0, _keyTurn = 0;
  double _moveX = 0,
      _moveY = 0; // touch joystick: x strafe right, y forward (-1..1)
  double _velF = 0, _velS = 0; // smoothed velocity (m/s)

  // Door: 0 closed .. 1 open
  double _doorOpen = 0;
  bool _opening = false;
  double _closeAfter =
      0; // seconds until the doors swing shut behind the shopper

  String _lastAisle = '';

  Widget build() => threeJs.build();

  void _markReady() {
    if (_readyCalled || _disposed) return;
    _readyCalled = true;
    onReady();
  }

  Future<void> _setup() async {
    try {
      threeJs.scene = three.Scene();
      threeJs.scene.background = three.Color.fromHex32(AppColors.skyColor);
      threeJs.camera = three.PerspectiveCamera(
        SceneConfig.fov,
        threeJs.width / threeJs.height,
        0.1,
        140,
      );

      threeJs.scene.add(
        three.HemisphereLight(0xFFFFFF, 0xF4F2EE, SceneConfig.hemiIntensity),
      );
      final sun = three.DirectionalLight(0xFFF1DC, SceneConfig.sunIntensity);
      sun.position.setValues(6, 14, 10);
      threeJs.scene.add(sun);

      final textures = await SceneTextures.create({
        for (final c in catalog.categories)
          c.id: (
            text: '${c.emoji} ${c.name}',
            bg: AppColors.charcoal,
            fg: 0xFFFFFF,
          ),
        'canteen': (text: 'CANTEEN', bg: 0x3B2A1E, fg: 0xF5E6CC),
        'open': (text: 'OPEN', bg: 0x2E9E4F, fg: 0xFFFFFF),
        'fresh': (text: 'Fresh every day', bg: 0x3B2A1E, fg: 0xE9C98A),
        'menu_video': (text: 'LIVE KITCHEN', bg: 0x2A2D31, fg: 0xFFFFFF),
        'menu_a': (text: 'MENU - Snacks', bg: 0xF7EBCB, fg: 0x5A3D27),
        'menu_b': (text: 'MENU - Chinese Station', bg: 0xF7EBCB, fg: 0x5A3D27),
        'menu_cake': (text: 'Fresh Cakes', bg: 0x2A2D31, fg: 0xFFFFFF),
      }, catalog.products);
      _textures = textures;
      _build = StoreBuilder(catalog, textures).build();
      threeJs.scene.add(_build!.root);
      if (_pendingShelf != null) syncShelf(_pendingShelf!);

      // tap-to-walk marker on the floor
      final marker = SceneKit.mesh(
        SceneKit.torus(0.2, 0.022),
        SceneKit.basic(0xFFFFFF),
      );
      marker.rotation.x = math.pi / 2;
      marker.visible = false;
      threeJs.scene.add(marker);
      _marker = marker;

      _held = HeldBasket(textures);
      threeJs.scene.add(threeJs.camera);
      threeJs.camera.add(_held!.rig);
      if (_pendingLines != null) _held!.sync(_pendingLines!);

      _applyCamera();
      threeJs.addAnimationEvent(_update);
    } catch (e, st) {
      debugPrint('StoreScene setup failed: $e\n$st');
    } finally {
      _markReady();
    }
  }

  // ---- public input ------------------------------------------------------

  /// Right-thumb drag (like PUBG): turn left/right and look up/down.
  /// Slower while zoomed in.
  void look(Offset delta) {
    final k = SceneConfig.lookSensitivity * (_fov / SceneConfig.fov);
    _yawTarget -= delta.dx * k;
    _pitchTarget = (_pitchTarget - delta.dy * k).clamp(
      -SceneConfig.maxPitch,
      SceneConfig.maxPitch,
    );
  }

  /// Left-thumb floating joystick: [x] slides right, [y] walks forward
  /// (both -1..1, the push distance sets the speed).
  void setMove(double x, double y) {
    _moveX = x;
    _moveY = y;
    if (x != 0 || y != 0) _clearTarget();
  }

  /// Pinch: [ratio] > 1 zooms in (spread), < 1 zooms out.
  void zoomBy(double ratio) {
    if (ratio <= 0) return;
    _fov = (_fov / ratio).clamp(SceneConfig.minFov, SceneConfig.maxFov);
  }

  /// Mouse wheel / trackpad scroll: vertical walks, horizontal slides.
  void scroll(Offset d) {
    if (_phase != StorePhase.inside) {
      _yawTarget -= d.dx * SceneConfig.scrollLookPerPixel;
      return;
    }
    _clearTarget();
    _pendingForward += -d.dy * SceneConfig.scrollWalkPerPixel;
    _pendingStrafe += d.dx * SceneConfig.scrollWalkPerPixel;
  }

  /// Held keys: [forward] -1..1, [strafe] -1 (left)..1 (right), [turn] likewise.
  void setKeys({double? forward, double? strafe, double? turn}) {
    if (forward != null) _keyForward = forward;
    if (strafe != null) _keyStrafe = strafe;
    if (turn != null) _keyTurn = turn;
  }

  /// Dev only: jump inside at (x, z) facing [yaw] (0 faces the back wall).
  void debugPlace(double x, double z, double yaw) {
    _pos.x = x;
    _pos.z = z;
    _yaw = yaw;
    _yawTarget = yaw;
    _doorOpen = 1;
    _opening = false;
    _closeAfter = 0;
    _setPhase(StorePhase.inside);
  }

  void enterStore() {
    if (_phase != StorePhase.outside) return;
    _setPhase(StorePhase.entering);
    _opening = true;
  }

  /// Updates the items in the hand-held basket (the hand rises when [justAdded]).
  void syncBasket(List<BasketLine> lines, {String? justAdded}) {
    final held = _held;
    if (held == null) {
      _pendingLines = lines;
      return;
    }
    held.sync(lines, justAdded: justAdded);
  }

  /// Hides one shelf copy per unit in the basket (the one you tapped first,
  /// then its neighbours) and puts copies back when they leave the basket.
  void syncShelf(Map<String, int> quantities) {
    final build = _build;
    if (build == null) {
      _pendingShelf = quantities;
      return;
    }
    for (final e in build.groups.entries) {
      final g = e.value;
      final want = (quantities[e.key] ?? 0).clamp(0, g.spots.length);
      while (g.hidden.length < want) {
        final spot = _nextToTake(e.key, g);
        if (spot < 0) break;
        g.hidden.add(spot);
        g.setHidden(spot, true);
      }
      while (g.hidden.length > want) {
        g.setHidden(g.hidden.removeLast(), false);
      }
    }
  }

  /// The copy to take next: the tapped one, else the closest to it (or to the shopper).
  int _nextToTake(String id, ProductGroup g) {
    final tap = _lastTap;
    if (tap != null && tap.id == id && !g.hidden.contains(tap.index)) {
      return tap.index;
    }
    final ref = (tap != null && tap.id == id)
        ? g.spots[tap.index].position
        : three.Vector3(_pos.x, 0, _pos.z);
    var best = -1;
    var bestD = double.infinity;
    for (var i = 0; i < g.spots.length; i++) {
      if (g.hidden.contains(i)) continue;
      final p = g.spots[i].position;
      final d = (p.x - ref.x) * (p.x - ref.x) + (p.z - ref.z) * (p.z - ref.z);
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    return best;
  }

  void tap(Offset p) {
    final build = _build;
    if (build == null) return;
    final w = threeJs.width, h = threeJs.height;
    _ray.setFromCamera(
      three.Vector2((p.dx / w) * 2 - 1, -(p.dy / h) * 2 + 1),
      threeJs.camera,
    );

    final held = _held;
    if (held != null &&
        held.isShown &&
        _ray.intersectObject(held.rig, true).isNotEmpty) {
      onBasketTapped();
      return;
    }

    final hits = _ray.intersectObject(build.root, true)
      ..sort((a, b) => a.distance.compareTo(b.distance));
    for (final hit in hits) {
      if (hit.object?.name == 'tag' || hit.object?.name == 'glass') {
        continue; // price tags and display glass never block a tap
      }
      final o = _owner(hit.object);
      if (o == null) {
        if (_isFloor(hit.object)) break;
        return; // a wall, shelf part or ceiling blocks the ray
      }
      if (o.startsWith('product:')) {
        if (_phase == StorePhase.inside) {
          _onProductHit(o.substring(8), hit.instanceId ?? 0);
        }
        return;
      }
      if (o == 'gate') {
        enterStore();
        return;
      }
      break;
    }
    if (_phase != StorePhase.inside) return;
    final pt = hits.where((h) => _isFloor(h.object)).firstOrNull?.point;
    if (pt == null) return;
    _pendingSpot = null;
    _setTarget(
      three.Vector3(
        pt.x.clamp(SceneConfig.minX, SceneConfig.maxX),
        SceneConfig.eyeHeight,
        pt.z.clamp(SceneConfig.minZ, SceneConfig.maxZ),
      ),
    );
  }

  void dispose() {
    _disposed = true;
    _removeShowcase(restore: false);
    threeJs.dispose();
    three.loading.clear();
    SceneKit.clear();
  }

  // ---- picking helpers ---------------------------------------------------

  /// Walks up to the named ancestor ('product:..' or 'gate'), or null.
  String? _owner(three.Object3D? o) {
    var n = o;
    while (n != null) {
      if (n.name.startsWith('product:') || n.name == 'gate') return n.name;
      n = n.parent;
    }
    return null;
  }

  bool _isFloor(three.Object3D? o) =>
      o != null && (o.name == 'floor' || o.name == 'ground');

  void _onProductHit(String id, int instance) {
    final group = _build!.groups[id];
    if (group == null) return;
    final idx = (instance ~/ group.per).clamp(0, group.spots.length - 1);
    final spot = group.spots[idx];
    _lastTap = (id: id, index: idx);
    final dx = spot.position.x - _pos.x, dz = spot.position.z - _pos.z;
    if (math.sqrt(dx * dx + dz * dz) <= SceneConfig.openDistance) {
      _faceTowards(spot.position.x, spot.position.z);
      _beginShowcase();
      onProductTapped(spot.product);
      return;
    }
    _pendingSpot = spot; // walk to the front of the item first
    _setTarget(
      three.Vector3(
        (spot.faceZ
                ? spot.position.x
                : spot.position.x + spot.side * SceneConfig.standDistance)
            .clamp(SceneConfig.minX, SceneConfig.maxX),
        SceneConfig.eyeHeight,
        (spot.faceZ
                ? spot.position.z + SceneConfig.standDistance
                : spot.position.z)
            .clamp(SceneConfig.minZ, SceneConfig.maxZ),
      ),
    );
  }

  // ---- frame update ------------------------------------------------------

  void _setPhase(StorePhase p) {
    _phase = p;
    onPhaseChanged(p);
  }

  void _setTarget(three.Vector3 t) {
    _target = t;
    _pendingForward = 0;
    _pendingStrafe = 0;
    _marker?.position.setValues(t.x, 0.03, t.z);
  }

  void _clearTarget() {
    _target = null;
    _pendingSpot = null;
  }

  void _faceTowards(double x, double z) =>
      _yawTarget = _yaw + _angleDiff(_yaw, _yawTo(x - _pos.x, z - _pos.z));

  double _yawTo(double dx, double dz) => math.atan2(-dx, -dz);

  double _angleDiff(double a, double b) {
    var d = (b - a) % (2 * math.pi);
    if (d > math.pi) d -= 2 * math.pi;
    if (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  void _update(double dt) {
    if (_build == null || _disposed) return;
    dt = dt.clamp(0, 0.05);
    _clock += dt;
    _updateGate(dt);
    if (_phase == StorePhase.inside) _updateManual(dt);
    _updateWalk(dt);
    // smooth turning
    _yaw += (_yawTarget - _yaw) * math.min(1, dt * SceneConfig.turnSmoothing);
    _pitch +=
        (_pitchTarget - _pitch) * math.min(1, dt * SceneConfig.turnSmoothing);
    if (_moveTimer > 0) _moveTimer -= dt;
    _applyCamera();
    final held = _held;
    if (held != null) {
      held.update(
        dt,
        yaw: _yaw,
        walkPhase: _walkPhase,
        walking: _moveTimer > 0,
      );
      held.layout(threeJs.width / threeJs.height, _vfov);
    }
    _updateShowcase(dt);
    _updateMarker();
    _updateAisle();
  }

  // ---- product showcase ---------------------------------------------------

  /// Lifts the last tapped product off the shelf and flies it to the centre of
  /// the view (a child of the camera, so it stays put while the sheet is open).
  void _beginShowcase() {
    final tap = _lastTap;
    final tex = _textures;
    if (tap == null || tex == null) return;
    final g = _build?.groups[tap.id];
    if (g == null) return;
    _removeShowcase(restore: true);
    final product = g.spots[tap.index].product;
    final spec = PackageSpec.of(product);
    final maxDim = math.max(spec.width, math.max(spec.height, spec.depth));
    // fraction of the screen height the item should fill (bigger in landscape)
    final half = math.tan(_vfov * math.pi / 360);
    final frac = _showcaseLandscape ? 0.42 : 0.3;
    final s = (frac * 2 * half / maxDim).clamp(0.5, 4.0);
    final model = spec.build(product, tex, scale: s);
    // centre the model on its own origin so it spins around its middle
    model.position.setValues(0, -spec.height * s / 2, 0);
    final wrap = three.Group()..add(model);
    wrap.scale.setValues(0.01, 0.01, 0.01);
    // start where the item sits on the shelf, in camera space
    final sp = g.spots[tap.index].position;
    final dx = sp.x - _pos.x,
        dy = sp.y - SceneConfig.eyeHeight,
        dz = sp.z - _pos.z;
    final cy = math.cos(_yaw), sy = math.sin(_yaw);
    final cp = math.cos(_pitch), spn = math.sin(_pitch);
    final x1 = dx * cy - dz * sy;
    final z1 = dx * sy + dz * cy;
    final ly = dy * cp + z1 * spn;
    final lz = -dy * spn + z1 * cp;
    _showcaseFrom.setValues(x1, ly, lz > -0.3 ? -0.5 : lz);
    wrap.position.setValues(_showcaseFrom.x, _showcaseFrom.y, _showcaseFrom.z);
    threeJs.camera.add(wrap);
    g.setHidden(tap.index, true);
    _showcase = wrap;
    _showcaseGroup = g;
    _showcaseIdx = tap.index;
    _showcaseT = 0;
    _showcaseSpin = 0;
  }

  /// Called when the detail sheet closes. A cancelled product goes back on
  /// the shelf; an added one stays hidden (the basket sync already took it).
  void endShowcase() => _removeShowcase(restore: true);

  void _removeShowcase({required bool restore}) {
    final w = _showcase;
    if (w != null) threeJs.camera.remove(w);
    final g = _showcaseGroup;
    if (restore && g != null && _showcaseIdx >= 0) {
      if (!g.hidden.contains(_showcaseIdx)) g.setHidden(_showcaseIdx, false);
    }
    _showcase = null;
    _showcaseGroup = null;
    _showcaseIdx = -1;
  }

  void _updateShowcase(double dt) {
    final w = _showcase;
    if (w == null) return;
    _showcaseT = math.min(1, _showcaseT + dt / 0.75);
    final t = _showcaseT;
    final e = 1 - math.pow(1 - t, 3).toDouble(); // ease out
    // rest position: upper middle of the view, above the bottom sheet
    const dist = 1.0;
    final half = math.tan(_vfov * math.pi / 360) * dist;
    final aspect = threeJs.width / threeJs.height;
    final land = _showcaseLandscape;
    final tx = land ? -half * aspect * 0.45 : 0.0;
    final ty = land ? 0.0 : half * 0.5;
    w.position.setValues(
      _showcaseFrom.x + (tx - _showcaseFrom.x) * e,
      _showcaseFrom.y + (ty - _showcaseFrom.y) * e,
      _showcaseFrom.z + (-dist - _showcaseFrom.z) * e,
    );
    final sc = 0.01 + 0.99 * e;
    w.scale.setValues(sc, sc, sc);
    // two quick turns while it flies in, then a slow spin
    _showcaseSpin += dt * (t < 1 ? 0 : 1.1);
    w.rotation.y = (1 - e) * 4 * math.pi + _showcaseSpin;
    w.rotation.x = 0.18 * e;
  }

  /// Swipes, scroll and keys feed an eased movement, so starting and
  /// stopping feels soft instead of jumpy.
  void _updateManual(double dt) {
    if (_keyTurn != 0) _yawTarget -= _keyTurn * 1.8 * dt;
    if (_keyForward != 0 || _keyStrafe != 0) _clearTarget();

    final ease = math.min(1, dt * 12);
    var fwd = _pendingForward * ease;
    var str = _pendingStrafe * ease;
    _pendingForward -= fwd;
    _pendingStrafe -= str;
    if (_pendingForward.abs() < 0.001) _pendingForward = 0;
    if (_pendingStrafe.abs() < 0.001) _pendingStrafe = 0;

    // joystick + held keys: smooth velocity (push distance = speed)
    final wantF = (_moveY + _keyForward).clamp(-1.0, 1.0);
    final wantS = (_moveX + _keyStrafe).clamp(-1.0, 1.0);
    final k = math.min(1, dt * SceneConfig.accel);
    _velF += (wantF * SceneConfig.walkSpeed - _velF) * k;
    _velS += (wantS * SceneConfig.walkSpeed * 0.85 - _velS) * k;
    if (_velF.abs() < 0.01 && wantF == 0) _velF = 0;
    if (_velS.abs() < 0.01 && wantS == 0) _velS = 0;
    fwd += _velF * dt;
    str += _velS * dt;
    if (fwd != 0 || str != 0) _moveLocal(fwd, str);
  }

  void _updateGate(double dt) {
    if (_opening) {
      _doorOpen = math.min(1, _doorOpen + dt / 1.4);
    } else if (_closeAfter > 0) {
      _closeAfter -= dt;
    } else if (_doorOpen > 0) {
      _doorOpen = math.max(0, _doorOpen - dt / 1.8); // doors close behind you
    } else {
      return;
    }
    final e = _doorOpen * _doorOpen * (3 - 2 * _doorOpen); // smooth in and out
    final doors = _build!.doors;
    for (var i = 0; i < doors.length; i++) {
      final hinge = i == 0
          ? 1.0
          : -1.0; // left door swings +, right door swings -
      doors[i].rotation.y = hinge * SceneConfig.doorOpenAngle * e;
    }
    if (_opening &&
        _doorOpen >= 0.5 &&
        _target == null &&
        _phase == StorePhase.entering) {
      _target = three.Vector3(
        0,
        SceneConfig.eyeHeight,
        SceneConfig.insideStartZ,
      );
    }
  }

  void _updateWalk(double dt) {
    final t = _target;
    if (t == null) return;
    final dx = t.x - _pos.x, dz = t.z - _pos.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist < 0.06) {
      _arrive();
      return;
    }
    final entering = _phase == StorePhase.entering;
    // ease out near the target so it does not stop abruptly
    final speed = math.min(
      entering ? SceneConfig.enterSpeed : SceneConfig.walkSpeed,
      0.7 + dist * 2.6,
    );
    final step = math.min(speed * dt, dist);
    final nx = _pos.x + dx / dist * step;
    final nz = _pos.z + dz / dist * step;
    var moved = false;
    if (entering || _free(nx, _pos.z)) {
      _pos.x = nx;
      moved = true;
    }
    if (entering || _free(_pos.x, nz)) {
      _pos.z = nz;
      moved = true;
    }
    if (!moved) {
      _clearTarget();
      return;
    }
    _walkPhase += dt;
    _moveTimer = 0.15;
    // turn towards where we are walking
    _yawTarget = _yaw + _angleDiff(_yaw, _yawTo(dx, dz));
  }

  /// Moves [fwd] metres along the facing direction and [str] to the right,
  /// sliding along shelves and walls.
  void _moveLocal(double fwd, double str) {
    if (_phase != StorePhase.inside) return;
    final sy = math.sin(_yaw), cy = math.cos(_yaw);
    final nx = _pos.x - sy * fwd + cy * str;
    final nz = _pos.z - cy * fwd - sy * str;
    var moved = false;
    if (_free(nx, _pos.z)) {
      _pos.x = nx;
      moved = true;
    }
    if (_free(_pos.x, nz)) {
      _pos.z = nz;
      moved = true;
    }
    if (moved) {
      _walkPhase += (fwd.abs() + str.abs()) * 0.45;
      _moveTimer = 0.15;
    } else {
      _velF = 0;
      _velS = 0;
      _pendingForward = 0;
      _pendingStrafe = 0;
    }
  }

  void _arrive() {
    _target = null;
    if (_phase == StorePhase.entering) {
      _setPhase(StorePhase.inside);
      _opening = false;
      _closeAfter = 1.2;
      return;
    }
    final spot = _pendingSpot;
    _pendingSpot = null;
    if (spot == null) return;
    _faceTowards(spot.position.x, spot.position.z);
    _beginShowcase();
    onProductTapped(spot.product);
  }

  bool _free(double x, double z) {
    const r = SceneConfig.playerRadius;
    if (x < SceneConfig.minX ||
        x > SceneConfig.maxX ||
        z < SceneConfig.minZ ||
        z > SceneConfig.maxZ) {
      return false;
    }
    for (final c in _build!.colliders) {
      if (x > c.minX - r &&
          x < c.maxX + r &&
          z > c.minZ - r &&
          z < c.maxZ + r) {
        return false;
      }
    }
    return true;
  }

  void _updateMarker() {
    final m = _marker;
    if (m == null) return;
    final show = _target != null && _phase == StorePhase.inside;
    m.visible = show;
    if (show) {
      final s = 1 + 0.18 * math.sin(_clock * 8);
      m.scale.setValues(s, s, s);
    }
  }

  void _applyCamera() {
    final bob = _moveTimer > 0
        ? math.sin(_walkPhase * SceneConfig.bobSpeed) * SceneConfig.bobHeight
        : 0.0;
    final cam = threeJs.camera;
    final aspect = threeJs.width / threeJs.height;
    // _fov is the diagonal angle, so portrait and landscape show the same amount
    // of the shop (a fixed vertical angle makes portrait look zoomed in).
    final tanV =
        math.tan(_fov * math.pi / 360) / math.sqrt(1 + aspect * aspect);
    _vfov = 2 * math.atan(tanV) * 180 / math.pi;
    var dirty = false;
    if ((cam.aspect - aspect).abs() > 0.001) {
      cam.aspect = aspect;
      dirty = true;
    }
    if ((cam.fov - _vfov).abs() > 0.01) {
      cam.fov = _vfov;
      dirty = true;
    }
    if (dirty) cam.updateProjectionMatrix();
    final cp = math.cos(_pitch);
    cam.position.setValues(_pos.x, SceneConfig.eyeHeight + bob, _pos.z);
    cam.lookAt(
      three.Vector3(
        _pos.x - math.sin(_yaw) * cp,
        SceneConfig.eyeHeight + bob + math.sin(_pitch),
        _pos.z - math.cos(_yaw) * cp,
      ),
    );
  }

  /// Which shelf face is the shopper looking at / standing near.
  void _updateAisle() {
    if (_phase != StorePhase.inside) return;
    final fx = _pos.x - math.sin(_yaw) * 2.5,
        fz = _pos.z - math.cos(_yaw) * 2.5;
    var best = '';
    var bestD = 6.5 * 6.5;
    for (final f in _build!.faces) {
      // only shelf faces turned towards the shopper count
      if (f.side * (_pos.x - f.unitX) <= 0) continue;
      final cz = fz.clamp(SceneConfig.shelfZStart, SceneConfig.shelfZEnd);
      final d = (f.x - fx) * (f.x - fx) + (cz - fz) * (cz - fz);
      if (d < bestD) {
        bestD = d;
        best = f.category.name;
      }
    }
    if (best != _lastAisle) {
      _lastAisle = best;
      onAisleChanged(best);
    }
  }
}
