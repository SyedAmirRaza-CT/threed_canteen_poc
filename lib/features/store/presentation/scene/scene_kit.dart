import 'package:three_js/three_js.dart' as three;

/// Small helpers that share geometries and materials so the scene stays light
/// on phones.
class SceneKit {
  SceneKit._();

  static final Map<String, three.BufferGeometry> _geos = {};
  static final Map<String, three.Material> _mats = {};

  static three.BufferGeometry box(double w, double h, double d) =>
      _geos.putIfAbsent('b$w,$h,$d', () => three.BoxGeometry(w, h, d));

  static three.BufferGeometry cyl(
    double rTop,
    double rBottom,
    double h, [
    int seg = 14,
  ]) => _geos.putIfAbsent(
    'c$rTop,$rBottom,$h,$seg',
    () => three.CylinderGeometry(rTop, rBottom, h, seg),
  );

  static three.BufferGeometry sphere(double r, [int seg = 14]) =>
      _geos.putIfAbsent(
        's$r,$seg',
        () => three.SphereGeometry(r, seg, seg ~/ 2 + 2),
      );

  static three.BufferGeometry torus(double r, double tube) =>
      _geos.putIfAbsent('t$r,$tube', () => three.TorusGeometry(r, tube, 8, 18));

  static three.BufferGeometry cone(double r, double h, [int seg = 14]) =>
      _geos.putIfAbsent('n$r,$h,$seg', () => three.ConeGeometry(r, h, seg));

  static three.BufferGeometry plane(double w, double h) =>
      _geos.putIfAbsent('p$w,$h', () => three.PlaneGeometry(w, h));

  static three.Material mat(
    int color, {
    double roughness = 0.75,
    double metalness = 0.0,
  }) => _mats.putIfAbsent(
    'm$color,$roughness,$metalness',
    () => three.MeshStandardMaterial.fromMap({
      'color': color,
      'roughness': roughness,
      'metalness': metalness,
    }),
  );

  /// Unlit material (ceiling lights, sign boards).
  static three.Material basic(int color) => _mats.putIfAbsent(
    'u$color',
    () => three.MeshBasicMaterial.fromMap({'color': color}),
  );

  static three.Material glass(int color, double opacity) => _mats.putIfAbsent(
    'g$color,$opacity',
    () => three.MeshStandardMaterial.fromMap({
      'color': color,
      'roughness': 0.1,
      'transparent': true,
      'opacity': opacity,
    }),
  );

  static three.Mesh mesh(
    three.BufferGeometry g,
    three.Material m, {
    double x = 0,
    double y = 0,
    double z = 0,
  }) {
    final mesh = three.Mesh(g, m);
    mesh.position.setValues(x, y, z);
    return mesh;
  }

  static void clear() {
    _geos.clear();
    _mats.clear();
  }
}
