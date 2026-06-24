/// A simple price variant for a product (e.g. Half Plate, Full Plate).
class ProductVariant {
  final String name;
  final num price;

  const ProductVariant({required this.name, required this.price});

  factory ProductVariant.fromMap(Map<String, Object?> map) {
    return ProductVariant(
      name: map['name'] as String,
      price: map['price'] as num,
    );
  }

  Map<String, Object> toMap() => {'name': name, 'price': price};

  @override
  String toString() => '$name (${price.toStringAsFixed(0)})';
}
