import 'package:injectable/injectable.dart' hide Order;
import 'package:material_ui/material_ui.dart';

import '../../../../core/utils/api_state.dart';
import '../../domain/entities/basket.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/place_order.dart';

@injectable
class BasketProvider extends ChangeNotifier {
  BasketProvider(this._placeOrder);

  final PlaceOrder _placeOrder;
  final Basket _basket = Basket();

  Basket get basket => _basket;

  ApiState<Order> _order = const ApiInitial();
  ApiState<Order> get order => _order;
  set order(ApiState<Order> v) {
    _order = v;
    notifyListeners();
  }

  /// Bumps on every add so the UI can play the fly-in animation.
  int addCounter = 0;
  Product? lastAdded;

  int quantityOf(Product p) => _basket.quantityOf(p);
  int remaining(Product p) => _basket.remaining(p);

  int add(Product p, [int quantity = 1]) {
    final added = _basket.add(p, quantity);
    if (added > 0) {
      lastAdded = p;
      addCounter++;
      notifyListeners();
    }
    return added;
  }

  void decrement(Product p) {
    _basket.decrement(p);
    notifyListeners();
  }

  void remove(Product p) {
    _basket.remove(p);
    notifyListeners();
  }

  void clear() {
    _basket.clear();
    notifyListeners();
  }

  Future<void> checkout() async {
    if (_basket.isEmpty) return;
    order = const ApiLoading();
    try {
      final placed = await _placeOrder(_basket);
      _basket.clear();
      order = ApiSuccess(placed);
    } catch (e) {
      order = ApiError(e.toString());
    }
  }

  void resetOrder() => order = const ApiInitial();
}
