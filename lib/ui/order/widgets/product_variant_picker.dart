import 'package:flutter/material.dart';
import 'package:possystem/models/menu/product.dart';
import 'package:possystem/models/menu/product_variant.dart';
import 'package:possystem/models/repository/cart.dart';

/// Shows a bottom sheet to pick a variant (e.g. Half Plate / Full Plate)
/// and adds the product to the cart with the selected price.
Future<void> showVariantPicker(BuildContext context, Product product) {
  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _VariantPickerSheet(product: product),
  );
}

class _VariantPickerSheet extends StatelessWidget {
  final Product product;

  const _VariantPickerSheet({required this.product});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Select a size', style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            ...product.variants.map((variant) => _VariantTile(
              product: product,
              variant: variant,
              onTap: () {
                Cart.instance.add(product, variantPrice: variant.price);
                Navigator.of(context).pop();
              },
            )),
          ],
        ),
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  final Product product;
  final ProductVariant variant;
  final VoidCallback onTap;

  const _VariantTile({required this.product, required this.variant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(variant.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          variant.price.toStringAsFixed(0),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
