import 'package:flutter/material.dart';
import 'package:possystem/models/menu/product.dart';
import 'package:possystem/models/menu/product_quantity.dart';
import 'package:possystem/models/menu/product_variant.dart';
import 'package:possystem/models/objects/order_object.dart';

/// Product in the cart.
///
/// Will be notify when selected, increment and quantity changed.
class CartProduct extends ChangeNotifier {
  /// Menu product.
  final Product product;

  /// The variant chosen when this entry was added to the cart, if any.
  ProductVariant? variant;

  /// Is this product being selected in cart?
  bool isSelected;

  num _singlePrice;

  /// Base cost for this cart entry (the product's cost, or a variant's cost
  /// when a variant was selected). Ingredient quantity costs are added on top.
  final num _baseCost;

  int _count;

  /// Ingredient and quantity pairs.
  ///
  /// Keys are ingredient and values are quantities.
  final Map<String, String> _quantities;

  /// [product] will set the default [singlePrice] and [quantities] is default
  /// to empty map.
  CartProduct(
    this.product, {
    int count = 1,
    num? singlePrice,
    num? singleCost,
    this.variant,
    this.isSelected = false,
    Map<String, String>? quantities,
  }) : _singlePrice = singlePrice ?? variant?.price ?? product.price,
       _baseCost = singleCost ?? variant?.cost ?? product.cost,
       _count = count,
       _quantities = quantities ?? <String, String>{};

  /// product's ID
  String get id => product.id;

  /// product's name
  String get name => product.name;

  /// Display name combining product and variant, e.g. "Chaap — Full".
  String get displayName => variant == null ? name : '$name — ${variant!.name}';

  /// The price used as the discount/original-price basis: the chosen
  /// variant's price if one was selected, otherwise the product's flat price.
  num get basePrice => variant?.price ?? product.price;

  /// The cost of single product.
  num get cost => quantities.fold<num>(_baseCost, (v, q) => v + (q.additionalCost));

  /// Total price which is single price times the count.
  num get totalPrice => _count * _singlePrice;

  /// Total cost which is single cost times the count.
  num get totalCost => _count * cost;

  /// Get all ingredients that has selected quantity.
  Iterable<ProductQuantity> get quantities => _quantities.entries
      .map((e) {
        return product.getItem(e.key)?.getItem(e.value);
      })
      .where((e) => e != null)
      .cast<ProductQuantity>();

  /// The price of the product, it may be affected by quantity of ingredients.
  set singlePrice(num other) {
    if (other != _singlePrice) {
      _singlePrice = other;
      notifyListeners();
    }
  }

  /// The count of the this product.
  int get count => _count;
  set count(int other) {
    if (other != _count) {
      _count = other;
      notifyListeners();
    }
  }

  /// Get quantity of specific ingredient.
  String? getQuantityId(String ingredientId) {
    return _quantities[ingredientId];
  }

  /// Get specific ingredient and quantity additional price.
  num getQuantityPrice(String ingredientId, String? quantityId) {
    if (quantityId == null) return 0;

    return product.getItem(ingredientId)?.getItem(quantityId)?.additionalPrice ?? 0;
  }

  /// Selected the quantity from cart and affect the price.
  void selectQuantity(String ingredientId, [String? quantityId]) {
    final old = _quantities[ingredientId];
    _singlePrice -= getQuantityPrice(ingredientId, old);

    if (quantityId == null) {
      _quantities.remove(ingredientId);
    } else {
      _quantities[ingredientId] = quantityId;
      _singlePrice += getQuantityPrice(ingredientId, quantityId);
    }

    notifyListeners();
  }

  /// Increase product count.
  void increment() {
    _count += 1;

    notifyListeners();
  }

  /// Decrease product count, stopping at 1.
  ///
  /// To remove the item entirely, use [Cart.removeAt] (e.g. swipe-to-delete
  /// or the bulk "Delete" action) instead.
  void decrement() {
    if (_count > 1) {
      _count -= 1;

      notifyListeners();
    }
  }

  /// Toggle selected state.
  ///
  /// If [checked] is different with current state return false else true.
  bool toggleSelected([bool? checked]) {
    checked ??= !isSelected;
    final changed = isSelected != checked;

    if (changed) {
      isSelected = checked;
      notifyListeners();
    }

    return changed;
  }

  /// Rebind the product from menu which is our source of truth.
  ///
  /// Enter the order page again the source might changed from other pages.
  void rebind() {
    // check missing
    for (final entry in _quantities.entries.toList()) {
      final item = product.getItem(entry.key);
      if (item?.hasItem(entry.value) != true) {
        _quantities.remove(entry.key);
      }
    }
    // drop a variant that no longer exists on the product
    if (variant != null && !product.variants.any((v) => v.id == variant!.id)) {
      variant = null;
    }
  }

  /// Convert to [OrderProductObject].
  OrderProductObject toObject() {
    return OrderProductObject(
      productId: product.id,
      productName: product.name,
      catalogName: product.catalog.name,
      variantId: variant?.id,
      variantName: variant?.name ?? '',
      count: _count,
      singleCost: cost,
      singlePrice: _singlePrice,
      originalPrice: basePrice,
      isDiscount: _singlePrice < basePrice,
      ingredients: product.items.map((e) => OrderIngredientObject.fromModel(e, getQuantityId(e.id))).toList(),
    );
  }
}
