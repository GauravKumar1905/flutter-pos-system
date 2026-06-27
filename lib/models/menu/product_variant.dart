import 'package:possystem/helpers/util.dart';

/// A simple price/cost variant for a product (e.g. Half Plate, Full Plate).
class ProductVariant {
  /// Stable id, independent of position in the list — lets a product mark
  /// one variant as the default without relying on list order.
  final String id;
  final String name;
  final num price;
  final num cost;

  ProductVariant({String? id, required this.name, required this.price, required this.cost})
    : id = id ?? Util.uuidV4();

  factory ProductVariant.fromMap(Map<String, Object?> map) {
    return ProductVariant(
      id: map['id'] as String?,
      name: map['name'] as String,
      price: map['price'] as num,
      cost: map['cost'] as num? ?? 0,
    );
  }

  Map<String, Object> toMap() => {'id': id, 'name': name, 'price': price, 'cost': cost};

  @override
  bool operator ==(Object other) =>
      other is ProductVariant && other.id == id && other.name == name && other.price == price && other.cost == cost;

  @override
  int get hashCode => Object.hash(id, name, price, cost);

  @override
  String toString() => '$name (${price.toStringAsFixed(0)})';
}
