import 'package:possystem/models/menu/product_quantity.dart';
import 'package:possystem/services/storage.dart';

import '../model.dart';
import '../objects/menu_object.dart';
import '../repository.dart';
import '../repository/menu.dart';
import 'catalog.dart';
import 'product_variant.dart';
import 'product_ingredient.dart';

class Product extends Model<ProductObject>
    with
        ModelStorage<ProductObject>,
        ModelOrderable<ProductObject>,
        ModelSearchable<ProductObject>,
        ModelImage<ProductObject>,
        Repository<ProductIngredient>,
        RepositoryStorage<ProductIngredient>,
        RepositoryOrderable<ProductIngredient> {
  /// Connect to parent object
  late final Catalog catalog;

  /// Help to calculate daily earn
  num cost;

  /// Money show to customer/order
  num price;

  /// Optional size/price variants (e.g. Half Plate, Full Plate)
  late List<ProductVariant> variants;

  /// The variant whose price/cost are mirrored into [price]/[cost].
  ///
  /// Set explicitly via [setVariants] ("Set as default"); falls back to the
  /// first variant if it doesn't match any (e.g. that variant was deleted).
  String? defaultVariantId;

  /// The time added to catalog
  final DateTime createdAt;

  /// The time it has been selected in searching
  DateTime? searchedAt;

  @override
  final Stores storageStore = .menu;

  @override
  final RepositoryStorageType repoType = .repoModel;

  Product({
    super.id,
    super.status = ModelStatus.normal,
    super.name = 'product',
    int index = 1,
    this.cost = 0,
    this.price = 0,
    List<ProductVariant>? variants,
    this.defaultVariantId,
    String? imagePath,
    DateTime? createdAt,
    this.searchedAt,
    Map<String, ProductIngredient>? ingredients,
  }) : createdAt = createdAt ?? .now() {
    this.index = index;
    this.imagePath = imagePath;
    this.variants = variants ?? [];
    syncDefaultPricing();

    if (ingredients != null) replaceItems(ingredients);
  }

  /// The variant currently marked as default (used for headline price/cost).
  ///
  /// Falls back to the first variant if [defaultVariantId] doesn't match any,
  /// and to a synthetic variant built from the legacy flat price/cost when
  /// there are no variants at all (e.g. a product never edited since before
  /// variants existed).
  ProductVariant get defaultVariant {
    if (variants.isEmpty) {
      return ProductVariant(id: defaultVariantId ?? '', name: '', price: price, cost: cost);
    }
    return variants.firstWhere((v) => v.id == defaultVariantId, orElse: () => variants.first);
  }

  bool get hasVariants => variants.isNotEmpty;

  /// Keep [price]/[cost] mirroring [defaultVariant].
  ///
  /// Call this whenever [variants] or [defaultVariantId] changes outside of
  /// [ProductObject.diff] (which already does it for persisted updates).
  void syncDefaultPricing() {
    if (variants.isNotEmpty) {
      final d = defaultVariant;
      price = d.price;
      cost = d.cost;
    }
  }

  /// Replace the variant list (and optionally the default) through the
  /// normal update/diff/save path, so the change is actually persisted.
  Future<void> setVariants(List<ProductVariant> variants, {String? defaultVariantId}) {
    return update(ProductObject(variants: variants, defaultVariantId: defaultVariantId ?? this.defaultVariantId));
  }

  factory Product.fromObject(ProductObject object) {
    final ingredients = object.ingredients
        .map((e) {
          try {
            return ProductIngredient.fromObject(e);
          } catch (e) {
            // not finding ingredient
            return null;
          }
        })
        .where((e) => e != null);

    if (!object.ingredients.every((object) => object.isLatest)) {
      Menu.instance.versionChanged = true;
    }

    return Product(
      id: object.id,
      name: object.name!,
      index: object.index!,
      price: object.price!,
      cost: object.cost!,
      imagePath: object.imagePath,
      createdAt: object.createdAt,
      searchedAt: object.searchedAt,
      ingredients: {for (var ingredient in ingredients) ingredient!.id: ingredient},
      variants: object.variants,
      defaultVariantId: object.defaultVariantId,
    )..prepareItem();
  }

  factory Product.fromRow(Product? ori, List<String> row, {required int index}) {
    final num price = .parse(row[2]);
    final num cost = .parse(row[3]);
    final status = ori == null
        ? ModelStatus.staged
        : (price == ori.price && cost == ori.cost ? ModelStatus.normal : ModelStatus.updated);

    return Product(id: ori?.id, name: row[1], index: index, price: price, cost: cost, status: status);
  }

  @override
  String get prefix => '${catalog.prefix}.products.$id';

  @override
  Catalog get repository => catalog;

  @override
  set repository(Repository repo) => catalog = repo as Catalog;

  @override
  ProductIngredient buildItem(String id, Map<String, Object?> value) {
    throw UnimplementedError();
  }

  ProductMatch getItemsSimilarity(String pattern) {
    final match = ProductMatch(product: this, score: getSimilarity(pattern) * 1.5);
    if (match.score > 0) {
      return match;
    }

    for (final ingredient in items) {
      match.mayIngredient(ingredient, ingredient.getSimilarity(pattern).toDouble());
      for (final quantity in ingredient.items) {
        match.mayQuantity(quantity, quantity.getSimilarity(pattern).toDouble());
      }
    }
    return match;
  }

  bool hasIngredient(String id) {
    return items.any((item) => item.ingredient.id == id);
  }

  @override
  void notifyItems() {
    notifyListeners();
    catalog.notifyItem();
  }

  Future<void> searched() {
    return update(ProductObject(searchedAt: .now()), event: 'search');
  }

  @override
  ProductObject toObject() => ProductObject(
    id: id,
    name: name,
    index: index,
    price: price,
    cost: cost,
    createdAt: createdAt,
    imagePath: imagePath,
    ingredients: items.map((e) => e.toObject()).toList(),
    variants: variants,
    defaultVariantId: defaultVariantId,
  );
}

class ProductMatch {
  Product product;
  ProductIngredient? ingredientMatched;
  ProductQuantity? quantityMatched;
  double score;

  ProductMatch({required this.product, this.ingredientMatched, this.quantityMatched, this.score = 0});

  String? get detailedName => ingredientMatched?.name ?? quantityMatched?.name;
  String? get detailedType => ingredientMatched != null ? 'ingredient' : (quantityMatched != null ? 'quantity' : null);

  void mayIngredient(ProductIngredient ingredient, double score) {
    if (score > this.score) {
      ingredientMatched = ingredient;
      quantityMatched = null;
      this.score = score;
    }
  }

  void mayQuantity(ProductQuantity quantity, double score) {
    if (score > this.score) {
      ingredientMatched = null;
      quantityMatched = quantity;
      this.score = score;
    }
  }
}
