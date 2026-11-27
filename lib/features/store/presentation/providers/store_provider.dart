import 'package:injectable/injectable.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/api_state.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/get_categories.dart';
import '../../domain/usecases/get_products.dart';

enum StorePhase { outside, entering, inside }

class StoreCatalog {
  const StoreCatalog({required this.categories, required this.products});
  final List<Category> categories;
  final List<Product> products;

  Category categoryOf(Product p) =>
      categories.firstWhere((c) => c.id == p.categoryId);
  List<Product> productsIn(Category c) =>
      products.where((p) => p.categoryId == c.id).toList();
}

/// Catalog loading + where the shopper is (outside, entering, inside) + current aisle.
@injectable
class StoreProvider extends ChangeNotifier {
  StoreProvider(this._getCategories, this._getProducts);

  final GetCategories _getCategories;
  final GetProducts _getProducts;

  ApiState<StoreCatalog> _catalog = const ApiInitial();
  ApiState<StoreCatalog> get catalog => _catalog;
  set catalog(ApiState<StoreCatalog> v) {
    _catalog = v;
    notifyListeners();
  }

  StorePhase _phase = StorePhase.outside;
  StorePhase get phase => _phase;
  set phase(StorePhase v) {
    if (_phase == v) return;
    _phase = v;
    notifyListeners();
  }

  String _aisle = '';
  String get aisle => _aisle;
  set aisle(String v) {
    if (_aisle == v) return;
    _aisle = v;
    notifyListeners();
  }

  Future<void> loadCatalog() async {
    catalog = const ApiLoading();
    try {
      final results = await Future.wait([_getCategories(), _getProducts()]);
      catalog = ApiSuccess(
        StoreCatalog(
          categories: results[0] as List<Category>,
          products: results[1] as List<Product>,
        ),
      );
    } catch (_) {
      catalog = const ApiError(AppStrings.loadFailed);
    }
  }
}
