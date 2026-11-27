/// A shelf category (Bakery, Drinks...). Plain business object, no mapping code.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
  });

  final String id;
  final String name;
  final String emoji;

  /// Brand colour of the category as 0xRRGGBB (used for shelf signs and chips).
  final int color;
}
