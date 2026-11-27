import 'package:injectable/injectable.dart';

import '../entities/product.dart';
import '../repositories/product_repository.dart';

@lazySingleton
class GetProducts {
  const GetProducts(this._repository);
  final ProductRepository _repository;

  Future<List<Product>> call() => _repository.getProducts();
}
