import '../../../../core/constants/app_constants.dart';
import 'product.dart';

class BasketLine {
  const BasketLine(this.product, this.quantity);
  final Product product;
  final int quantity;

  int get total => product.price * quantity;
  int get calories => product.calories * quantity;
}

/// The shopper's basket. Pure business logic (stock caps, totals, tax).
class Basket {
  final Map<String, BasketLine> _lines = {};

  List<BasketLine> get lines => _lines.values.toList(growable: false);
  bool get isEmpty => _lines.isEmpty;

  int quantityOf(Product p) => _lines[p.id]?.quantity ?? 0;

  /// How many more of [p] can still be added.
  int remaining(Product p) => p.stock - quantityOf(p);

  int get itemCount => _lines.values.fold(0, (a, l) => a + l.quantity);
  int get subtotal => _lines.values.fold(0, (a, l) => a + l.total);
  int get tax => (subtotal * AppConstants.taxRate).round();
  int get total => subtotal + tax;
  int get totalCalories => _lines.values.fold(0, (a, l) => a + l.calories);

  /// Adds up to [quantity] items (capped by stock). Returns how many were added.
  int add(Product p, [int quantity = 1]) {
    final canAdd = quantity.clamp(0, remaining(p));
    if (canAdd == 0) return 0;
    _lines[p.id] = BasketLine(p, quantityOf(p) + canAdd);
    return canAdd;
  }

  void decrement(Product p) {
    final q = quantityOf(p);
    if (q <= 1) {
      _lines.remove(p.id);
    } else {
      _lines[p.id] = BasketLine(p, q - 1);
    }
  }

  void remove(Product p) => _lines.remove(p.id);

  void clear() => _lines.clear();
}
