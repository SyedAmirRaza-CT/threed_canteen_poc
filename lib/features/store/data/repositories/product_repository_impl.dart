import 'package:injectable/injectable.dart' hide Order;

import '../../domain/entities/basket.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/product_local_data_source.dart';

@LazySingleton(as: ProductRepository)
class ProductRepositoryImpl implements ProductRepository {
  const ProductRepositoryImpl(this._dataSource);
  final ProductDataSource _dataSource;

  @override
  Future<List<Category>> getCategories() => _dataSource.fetchCategories();

  @override
  Future<List<Product>> getProducts() => _dataSource.fetchProducts();

  @override
  Future<Order> placeOrder(Basket basket) async {
    final id = await _dataSource.submitOrder({
      for (final l in basket.lines) l.product.id: l.quantity,
    });
    return Order(id: id, itemCount: basket.itemCount, total: basket.total);
  }
}
