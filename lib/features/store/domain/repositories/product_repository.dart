import '../entities/basket.dart';
import '../entities/category.dart';
import '../entities/order.dart';
import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Category>> getCategories();
  Future<List<Product>> getProducts();
  Future<Order> placeOrder(Basket basket);
}
