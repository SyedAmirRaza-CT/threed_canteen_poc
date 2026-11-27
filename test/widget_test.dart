import 'package:flutter_test/flutter_test.dart';
import 'package:threed_canteen_poc/features/store/data/models/product_model.dart';
import 'package:threed_canteen_poc/features/store/data/datasources/product_local_data_source.dart';
import 'package:threed_canteen_poc/features/store/domain/entities/basket.dart';

void main() {
  late List<ProductModel> products;

  setUp(() async {
    products = await ProductLocalDataSource().fetchProducts();
  });

  test('catalog loads and models round-trip through json', () {
    expect(products.length, greaterThan(20));
    final p = products.first;
    final copy = ProductModel.fromJson(p.toJson());
    expect(copy.id, p.id);
    expect(copy.kind, p.kind);
  });

  test('basket caps by stock and computes totals with tax', () {
    final basket = Basket();
    final cake = products.firstWhere((p) => p.id == 'cake'); // stock 8, ₹120
    expect(basket.add(cake, 100), cake.stock);
    expect(basket.remaining(cake), 0);
    expect(basket.add(cake), 0);
    basket.decrement(cake);
    expect(basket.quantityOf(cake), cake.stock - 1);
    expect(basket.subtotal, 120 * (cake.stock - 1));
    expect(basket.total, basket.subtotal + (basket.subtotal * 0.05).round());
    basket.clear();
    expect(basket.isEmpty, isTrue);
  });
}
