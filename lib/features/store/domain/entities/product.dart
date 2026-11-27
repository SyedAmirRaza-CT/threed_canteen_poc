/// Shape used to build the item's 3D model.
enum ProductKind {
  cake,
  cupcake,
  donut,
  bun,
  pizza,
  burger,
  sandwich,
  bottle,
  can,
  cup,
  chips,
  bar,
  fruit,
  banana,
  carton,
  tub,
  iceCream,
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.emoji,
    required this.price,
    required this.calories,
    required this.stock,
    required this.description,
    required this.ingredients,
    required this.isVeg,
    required this.kind,
    required this.color,
    required this.accent,
    this.displayModel,
  });

  final String id;
  final String name;
  final String categoryId;
  final String emoji;

  /// Price in rupees.
  final int price;
  final int calories;
  final int stock;
  final String description;
  final List<String> ingredients;
  final bool isVeg;
  final ProductKind kind;

  /// Main and accent colours of the 3D model as 0xRRGGBB.
  final int color;
  final int accent;

  /// Name of a GLB model (see ModelLibrary) that stands for this product in the
  /// store, e.g. a plated cake in the showcase. Such a product is bought by
  /// tapping that model, and it is not stocked on the aisle shelves.
  final String? displayModel;
}
