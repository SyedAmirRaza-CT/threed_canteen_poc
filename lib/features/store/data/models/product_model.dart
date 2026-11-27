import '../../domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    required super.name,
    required super.categoryId,
    required super.emoji,
    required super.price,
    required super.calories,
    required super.stock,
    required super.description,
    required super.ingredients,
    required super.isVeg,
    required super.kind,
    required super.color,
    required super.accent,
    super.displayModel,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
    id: json['id'] as String,
    name: json['name'] as String,
    categoryId: json['categoryId'] as String,
    emoji: json['emoji'] as String,
    price: json['price'] as int,
    calories: json['calories'] as int,
    stock: json['stock'] as int,
    description: json['description'] as String,
    ingredients: List<String>.from(json['ingredients'] as List),
    isVeg: json['isVeg'] as bool,
    kind: ProductKind.values.byName(json['kind'] as String),
    color: json['color'] as int,
    accent: json['accent'] as int,
    displayModel: json['displayModel'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'categoryId': categoryId,
    'emoji': emoji,
    'price': price,
    'calories': calories,
    'stock': stock,
    'description': description,
    'ingredients': ingredients,
    'isVeg': isVeg,
    'kind': kind.name,
    'color': color,
    'accent': accent,
    if (displayModel != null) 'displayModel': displayModel,
  };
}
