import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:possystem/components/scaffold/item_modal.dart';
import 'package:possystem/components/style/image_holder.dart';
import 'package:possystem/helpers/validator.dart';
import 'package:possystem/models/menu/catalog.dart';
import 'package:possystem/models/menu/product.dart';
import 'package:possystem/models/menu/product_variant.dart';
import 'package:possystem/models/objects/menu_object.dart';
import 'package:possystem/models/repository/menu.dart';
import 'package:possystem/translator.dart';

class ProductModal extends StatefulWidget {
  final Product? product;
  final Catalog catalog;
  final bool isNew;

  const ProductModal({super.key, this.product, required this.catalog}) : isNew = product == null;

  @override
  State<ProductModal> createState() => _ProductModalState();
}

/// One row of the variant editor shown when creating a new product.
///
/// Every product is variant-first: even a "simple" product like a drink
/// gets exactly one variant row here, which becomes its default variant.
class _VariantRow {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController cost;

  _VariantRow({String? name, String? price, String? cost})
    : name = TextEditingController(text: name),
      price = TextEditingController(text: price),
      cost = TextEditingController(text: cost);

  void dispose() {
    name.dispose();
    price.dispose();
    cost.dispose();
  }
}

class _ProductModalState extends State<ProductModal> with ItemModal<ProductModal> {
  late TextEditingController _nameController;
  late FocusNode _nameFocusNode;
  late List<_VariantRow> _variantRows;

  String? _image;

  @override
  String get title => widget.isNew ? S.menuProductTitleCreate : S.menuProductTitleUpdate;

  @override
  List<Widget> buildFormFields() {
    return [
      EditImageHolder(path: _image, onSelected: (image) => setState(() => _image = image)),
      p(
        TextFormField(
          key: const Key('product.name'),
          controller: _nameController,
          textInputAction: widget.isNew ? .next : .done,
          textCapitalization: .words,
          focusNode: _nameFocusNode,
          decoration: InputDecoration(
            labelText: S.menuProductNameLabel,
            hintText: widget.product?.name ?? S.menuProductNameHint,
            filled: false,
          ),
          maxLength: 30,
          validator: Validator.textLimit(
            S.menuProductNameLabel,
            30,
            focusNode: _nameFocusNode,
            validator: (name) {
              return widget.product?.name != name && Menu.instance.hasProductByName(name)
                  ? S.menuProductNameErrorRepeat
                  : null;
            },
          ),
          onFieldSubmitted: widget.isNew ? null : handleFieldSubmit,
        ),
      ),
      if (widget.isNew) ..._buildVariantFields(),
    ];
  }

  List<Widget> _buildVariantFields() {
    return [
      p(
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text('Variants', style: Theme.of(context).textTheme.titleSmall),
        ),
      ),
      for (var i = 0; i < _variantRows.length; i++) _buildVariantRow(i),
      p(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('product.variant.add'),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Variant'),
            onPressed: _addVariantRow,
          ),
        ),
      ),
    ];
  }

  Widget _buildVariantRow(int index) {
    final row = _variantRows[index];
    return p(
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                key: Key('product.variant.$index.name'),
                controller: row.name,
                textCapitalization: .words,
                decoration: InputDecoration(
                  labelText: index == 0 ? 'Name (default)' : 'Name',
                  hintText: 'e.g. Regular, Half Plate',
                ),
                validator: Validator.textLimit('Variant Name', 30),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                key: Key('product.variant.$index.price'),
                controller: row.price,
                keyboardType: .number,
                decoration: const InputDecoration(labelText: 'Price'),
                validator: Validator.isNumber('Price'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextFormField(
                key: Key('product.variant.$index.cost'),
                controller: row.cost,
                keyboardType: .number,
                decoration: const InputDecoration(labelText: 'Cost'),
                validator: Validator.positiveNumber('Cost'),
              ),
            ),
            if (_variantRows.length > 1)
              IconButton(
                key: Key('product.variant.$index.delete'),
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () => _removeVariantRow(index),
              ),
          ],
        ),
      ),
    );
  }

  void _addVariantRow() {
    setState(() => _variantRows.add(_VariantRow()));
  }

  void _removeVariantRow(int index) {
    setState(() => _variantRows.removeAt(index).dispose());
  }

  Future<Product> getProduct() async {
    if (widget.isNew) {
      final variants = _variantRows
          .map((row) => ProductVariant(
                name: row.name.text.trim(),
                price: num.tryParse(row.price.text.trim()) ?? 0,
                cost: num.tryParse(row.cost.text.trim()) ?? 0,
              ))
          .toList();

      final product = Product(
        index: widget.catalog.newIndex,
        name: _nameController.text.trim(),
        variants: variants,
        defaultVariantId: variants.first.id,
        imagePath: _image,
      );

      await widget.catalog.addItem(product);
      return product;
    }

    final product = widget.product!;
    await product.update(ProductObject(name: _nameController.text.trim(), imagePath: _image));
    return product;
  }

  @override
  void initState() {
    super.initState();

    final p = widget.product;
    _nameController = TextEditingController(text: p?.name);
    _nameFocusNode = FocusNode();
    _image = widget.product?.imagePath;
    _variantRows = [_VariantRow()];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    for (final row in _variantRows) {
      row.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> updateItem() async {
    final product = await getProduct();

    if (mounted) {
      context.pop(product.id);
    }
  }
}
