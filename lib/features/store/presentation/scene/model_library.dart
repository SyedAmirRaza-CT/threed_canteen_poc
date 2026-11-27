import 'package:flutter/foundation.dart' show debugPrint;
import 'package:three_js/three_js.dart' as three;

import '../../domain/entities/product.dart';
import 'product_package.dart';

/// Loads every GLB model the store is built from. A model that fails to load
/// is simply missing, and the builder falls back to code-built shapes for it.
///
/// Files are made by tool/gen_models.js and tool/gen_shelf_glb.js and live in
/// assets/models/ (products in assets/models/products/).
class ModelLibrary {
  ModelLibrary._(this.models, this.productCount);

  /// Scene models by file name (without .glb).
  final Map<String, three.Object3D> models;

  /// How many product shapes were loaded from GLB.
  final int productCount;

  static const _names = [
    'shelf_half',
    'service_counter',
    'fridge_bay_36',
    'fridge_bay_29',
    'chef',
    'gate',
    'checkout_counter',
    'plant',
    'outside_ground',
    'tree',
    'planter',
    'bench',
    'lamp',
    'counter_lamp',
    'cake_slices',
    'fruit_muffin',
  ];

  static Future<ModelLibrary> load() async {
    final models = <String, three.Object3D>{};
    for (final n in _names) {
      final scene = await _scene('assets/models/$n.glb');
      if (scene != null) models[n] = scene;
    }
    // products: only the shape comes from the file, the printed label is
    // still drawn in code, so the geometry is handed to PackageSpec.
    var products = 0;
    for (final k in ProductKind.values) {
      final scene = await _scene('assets/models/products/${k.name}.glb');
      three.BufferGeometry? geo;
      scene?.traverse((o) {
        if (geo == null && o is three.Mesh) geo = o.geometry;
      });
      if (geo != null) {
        PackageSpec.glbGeometry[k] = geo!;
        products++;
      }
    }
    return ModelLibrary._(models, products);
  }

  static Future<three.Object3D?> _scene(String asset) async {
    try {
      return (await three.GLTFLoader().fromAsset(asset))?.scene;
    } catch (e) {
      debugPrint('GLB failed ($asset): $e');
      return null;
    }
  }
}
