import 'package:flutter/material.dart';
import 'package:possystem/components/meta_block.dart';
import 'package:possystem/components/style/image_holder.dart';
import 'package:possystem/constants/constant.dart';
import 'package:possystem/helpers/breakpoint.dart';
import 'package:possystem/models/menu/product.dart';
import 'package:possystem/models/repository/cart.dart';
import 'package:possystem/translator.dart';
import 'package:possystem/ui/order/order_page.dart';
import 'package:possystem/ui/order/widgets/product_variant_picker.dart';

class OrderProductListView extends StatelessWidget {
  final List<Product> products;

  final ProductListView view;

  const OrderProductListView({super.key, required this.products, required this.view});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: kTopSpacing, bottom: kFABSpacing),
      child: _buildView(context, context),
    );
  }

  Widget _buildView(BuildContext context, BuildContext outerContext) {
    if (view == .list) {
      return _buildListView(outerContext);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // each width should between 200 and 320
        return _buildGridView(outerContext, Breakpoint.find(box: constraints).lookup(compact: 2, medium: 3, expanded: 4, large: 5));
      },
    );
  }

  Widget _buildGridView(BuildContext context, int crossAxisCount) {
    return Center(
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 8.0,
        children: [
          for (final product in products)
            ImageHolder(
              key: Key('order.product.${product.id}'),
              image: product.image,
              title: product.name,
              onPressed: () => _onSelected(context, product),
            ),
        ],
      ),
    );
  }

  Widget _buildListView(BuildContext context) {
    return ListView(
      children: [
        for (final product in products)
          ListTile(
            key: Key('order.product.${product.id}'),
            title: Text(product.name),
            subtitle: MetaBlock.withString(
              context,
              product.itemList.map((e) => e.name).toList(),
              emptyText: S.orderProductListNoIngredient,
            ),
            onTap: () => _onSelected(context, product),
          ),
      ],
    );
  }

  void _onSelected(BuildContext context, Product product) {
    if (product.variants.isNotEmpty) {
      showVariantPicker(context, product);
    } else {
      Cart.instance.add(product);
    }
  }
}
