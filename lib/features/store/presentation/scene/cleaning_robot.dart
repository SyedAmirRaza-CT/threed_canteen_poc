import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:three_js/three_js.dart' as three;

import 'scene_kit.dart';

class _Dust {
  _Dust(this.mesh, this.x, this.z, this.size);
  final three.Mesh mesh;
  final double x, z, size;
  bool cleaning = false;
  bool cleaned = false;
  double scale = 1;
}

/// A robot vacuum loaded from a GLB that roams the open floor lane in front of
/// the service counter, sweeping up little patches of dust as it passes over
/// them. The file has no baked animation, so the driving is done in code.
///
/// Model: assets/models/cleaning_robot.glb (see assets/models/CREDITS.md).
class CleaningRobot {
  static const asset = 'assets/models/cleaning_robot.glb';

  // The model's raw bounds (units are arbitrary): ~24.9 wide, base at y = -1.57.
  static const _rawWidth = 24.86;
  static const _rawCx = 0.496, _rawCz = 1.471, _rawMinY = -1.5705;
  static const _diameter = 0.36; // metres

  static const _speed = 0.55; // m/s
  static const _cleanRadius = 0.3;

  final three.Group root = three.Group();
  final List<_Dust> _dust = [];
  List<List<double>> _path = [];
  int _seg = 0;
  bool _loaded = false;
  double _x = 0, _z = 0, _heading = 0, _clock = 0, _pause = 0;
  late three.Object3D _pivot;
  three.Object3D? _scene;

  bool get isLoaded => _loaded;

  /// Loads the GLB and adds the robot (and its dust patches) to [scene].
  Future<void> load(three.Object3D scene) async {
    try {
      _scene = scene;
      final data = await three.GLTFLoader().fromAsset(asset);
      final model = data?.scene;
      if (model == null) return;
      const s = _diameter / _rawWidth;
      model.scale.setValues(s, s, s);
      model.position.setValues(-_rawCx * s, -_rawMinY * s, -_rawCz * s);
      _pivot = three.Group()..add(model);
      root.add(_pivot);
      scene.add(root);
      _buildPath();
      _spawnDust();
      _x = _path.first[0];
      _z = _path.first[1];
      _place();
      _loaded = true;
    } catch (e, st) {
      debugPrint('CleaningRobot failed to load: $e\n$st');
    }
  }

  /// Back-and-forth sweeps down the open lane (clear of shelves and counter).
  void _buildPath() {
    const lanes = [-1.8, -0.6, 0.6, 1.8];
    const zNear = 4.0, zFar = -9.6;
    _path = [];
    for (var i = 0; i < lanes.length; i++) {
      final up = i.isEven;
      _path.add([lanes[i], up ? zNear : zFar]);
      _path.add([lanes[i], up ? zFar : zNear]);
    }
    _seg = 1;
  }

  void _spawnDust() {
    for (final d in _dust) {
      _scene?.remove(d.mesh);
    }
    _dust.clear();
    var seed = 7;
    double rnd() {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed / 0x7fffffff;
    }

    final mat = SceneKit.mat(0x6B5B4B, roughness: 1);
    for (var i = 0; i < 40; i++) {
      final x = -2.0 + rnd() * 4.0;
      final z = -9.4 + rnd() * 13.0;
      final size = 0.04 + rnd() * 0.05;
      final m = three.Mesh(SceneKit.cyl(1, 1, 0.004, 10), mat);
      m.scale.setValues(size, 1, size * (0.7 + rnd() * 0.6));
      m.position.setValues(x, 0.012, z);
      _scene?.add(m);
      _dust.add(_Dust(m, x, z, size));
    }
  }

  void _place() {
    root.position.setValues(_x, 0, _z);
    _pivot.rotation.y = _heading;
  }

  void update(double dt) {
    if (!_loaded) return;
    _clock += dt;
    if (_pause > 0) {
      _pause -= dt;
    } else {
      final t = _path[_seg];
      final dx = t[0] - _x, dz = t[1] - _z;
      final dist = math.sqrt(dx * dx + dz * dz);
      if (dist < 0.05) {
        _seg++;
        if (_seg >= _path.length) {
          // one full sweep done: rest a moment, dirty the floor, go back
          _path = _path.reversed.toList();
          _seg = 1;
          _pause = 2.5;
          _spawnDust();
        }
      } else {
        final want = math.atan2(dx, dz);
        var err = want - _heading;
        err = (err + math.pi) % (2 * math.pi) - math.pi;
        if (err < -math.pi) err += 2 * math.pi;
        _heading += err * math.min(1, dt * 5);
        // slow down while turning so corners look natural
        final speed = _speed * (1 - math.min(1, err.abs() / 1.2) * 0.85);
        final step = math.min(dist, speed * dt);
        _x += math.sin(want) * step;
        _z += math.cos(want) * step;
      }
    }
    _place();
    // a little bob while it works
    _pivot.position.y = math.sin(_clock * 18) * 0.002;

    for (final d in _dust) {
      if (d.cleaned) continue;
      if (!d.cleaning) {
        final dx = d.x - _x, dz = d.z - _z;
        if (dx * dx + dz * dz < _cleanRadius * _cleanRadius) d.cleaning = true;
      } else {
        d.scale -= dt * 3;
        if (d.scale <= 0) {
          d.cleaned = true;
          d.mesh.visible = false;
        } else {
          d.mesh.scale.setValues(d.size * d.scale, 1, d.size * d.scale);
        }
      }
    }
  }
}
