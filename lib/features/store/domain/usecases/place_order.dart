import 'package:injectable/injectable.dart' hide Order;

import '../entities/basket.dart';
import '../entities/order.dart';
import '../repositories/product_repository.dart';

@lazySingleton
class PlaceOrder {
  const PlaceOrder(this._repository);
  final ProductRepository _repository;

  /// Throws [StateError] when the basket is empty.
  Future<Order> call(Basket basket) {
    if (basket.isEmpty) throw StateError('Basket is empty');
    return _repository.placeOrder(basket);
  }
}
