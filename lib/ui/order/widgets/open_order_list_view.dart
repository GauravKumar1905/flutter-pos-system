import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:possystem/components/style/snackbar.dart';
import 'package:possystem/helpers/util.dart';
import 'package:possystem/models/objects/order_object.dart';
import 'package:possystem/models/repository/cart.dart';
import 'package:possystem/models/repository/menu.dart';
import 'package:possystem/models/repository/stashed_orders.dart';
import 'package:possystem/translator.dart';

/// A bottom-sheet list of all currently open (in-progress) orders.
///
/// Tapping a tile switches the active order to it (silently saving the current
/// one) and pops with `'switched'`. The overflow menu offers checkout (pops
/// with `'checkout'`), relabel, and delete. "Start new order" pops with
/// `'new'`. The hosting page acts on the popped result.
class OpenOrderListView extends StatefulWidget {
  const OpenOrderListView({super.key});

  @override
  State<OpenOrderListView> createState() => _OpenOrderListViewState();
}

class _OpenOrderListViewState extends State<OpenOrderListView> {
  late Future<List<OrderObject>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = StashedOrders.instance.getItems(limit: null);
  }

  /// Products' subtotal (stash map does not persist the full order price).
  num _total(OrderObject order) => order.products.fold<num>(0, (s, p) => s + p.totalPrice);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                height: 5,
                width: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(child: Text('Open orders', style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<OrderObject>>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                    );
                  }
                  final orders = snapshot.data!;
                  if (orders.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('No other open orders yet.')),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, i) => _buildTile(context, orders[i]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: OutlinedButton.icon(
                key: const Key('open_order.new'),
                icon: const Icon(Icons.add),
                label: const Text('Start new order'),
                onPressed: _startNew,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, OrderObject order) {
    final theme = Theme.of(context);
    final products = order.products
        .map((e) {
          final p = Menu.instance.getProduct(e.productId);
          if (p == null) return null;
          return e.count == 1 ? p.name : '${p.name} * ${e.count}';
        })
        .whereType<String>()
        .join(', ');

    return Card(
      key: Key('open_order.${order.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primary,
          child: Text('#${order.no}', style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 12)),
        ),
        title: Text(
          order.label.isEmpty ? 'No label' : order.label,
          style: TextStyle(fontStyle: order.label.isEmpty ? FontStyle.italic : FontStyle.normal),
        ),
        subtitle: Text(
          '${DateFormat.Hm(S.localeName).format(order.createdAt)} · ${products.isEmpty ? 'empty' : products}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('\$${_total(order).toCurrency()}', style: theme.textTheme.titleMedium),
            PopupMenuButton<String>(
              onSelected: (v) => _onAction(context, v, order),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'checkout',
                  child: ListTile(leading: Icon(Icons.price_check), title: Text('Checkout')),
                ),
                PopupMenuItem(
                  value: 'label',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit label')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete')),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _switchTo(context, order),
      ),
    );
  }

  Future<void> _switchTo(BuildContext context, OrderObject order) async {
    await Cart.instance.switchTo(order);
    if (context.mounted) Navigator.of(context).pop('switched');
  }

  Future<void> _startNew() async {
    await Cart.instance.startNewOrder();
    if (mounted) Navigator.of(context).pop('new');
  }

  Future<void> _onAction(BuildContext context, String action, OrderObject order) async {
    switch (action) {
      case 'checkout':
        await Cart.instance.switchTo(order);
        if (context.mounted) Navigator.of(context).pop('checkout');
        break;
      case 'label':
        await editOrderLabel(context, order.no, order.label, (value) async {
          await StashedOrders.instance.updateLabel(order.id ?? 0, value);
          if (mounted) setState(_reload);
        });
        break;
      case 'delete':
        await StashedOrders.instance.delete(order.id ?? 0);
        if (mounted) {
          setState(_reload);
          if (context.mounted) showSnackBar('Order deleted', context: context);
        }
        break;
    }
  }
}

/// Show the "add a name" dialog for an order, with the number already assigned.
Future<void> editOrderLabel(BuildContext context, int no, String current, void Function(String) onSave) async {
  final controller = TextEditingController(text: current);
  final value = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Order #$no — add a name'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g. Blue Swift, Ravi, KA-01-1234',
          helperText: 'Optional — a car / customer name to find this order fast.',
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: const Text('Save name'),
        ),
      ],
    ),
  );

  if (value != null) onSave(value);
}
