import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:possystem/components/linkify.dart';
import 'package:possystem/components/menu_actions.dart';
import 'package:possystem/components/style/buttons.dart';
import 'package:possystem/components/style/pop_button.dart';
import 'package:possystem/components/style/snackbar.dart';
import 'package:possystem/components/tutorial.dart';
import 'package:possystem/helpers/breakpoint.dart';
import 'package:possystem/models/repository/cart.dart';
import 'package:possystem/models/repository/menu.dart';
import 'package:possystem/models/repository/stashed_orders.dart';
import 'package:possystem/routes.dart';
import 'package:possystem/settings/checkout_warning.dart';
import 'package:possystem/settings/order_awakening_setting.dart';
import 'package:possystem/translator.dart';
import 'package:possystem/ui/order/cart/cart_metadata_view.dart';
import 'package:possystem/ui/order/cart/cart_product_list.dart';
import 'package:possystem/ui/order/cart/cart_product_selector.dart';
import 'package:possystem/ui/order/widgets/printer_button_view.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'cart/cart_product_state_selector.dart';
import 'widgets/draggable_sheet_view.dart';
import 'widgets/open_order_list_view.dart';
import 'widgets/order_catalog_list_view.dart';
import 'widgets/order_product_list_view.dart';
import 'widgets/orientated_view.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  late final PageController _pageController;

  /// Change the catalog index and pass to [OrderProductListView] and [OrderCatalogListView]
  late final ValueNotifier<int> _catalogIndexNotifier;

  /// Used to update the view of [OrderProductListView]
  late final ValueNotifier<ProductListView> _productViewNotifier;

  /// Reset panel to initial state, used by [DraggableSheetView]
  final _Notifier _resetNotifier = _Notifier();

  @override
  Widget build(BuildContext context) {
    final catalogs = Menu.instance.notEmptyItems;

    final orderCatalogListView = OrderCatalogListView(
      catalogs: catalogs,
      indexNotifier: _catalogIndexNotifier,
      viewNotifier: _productViewNotifier,
      onSelected: (index) => _pageController.jumpToPage(index),
    );
    final orderProductListView = ListenableBuilder(
      listenable: _productViewNotifier,
      builder: (context, _) => PageView.builder(
        controller: _pageController,
        onPageChanged: (index) => _catalogIndexNotifier.value = index,
        itemCount: catalogs.length,
        itemBuilder: (context, index) =>
            OrderProductListView(products: catalogs[index].itemList, view: _productViewNotifier.value),
      ),
    );

    final body = Breakpoint.find(width: MediaQuery.sizeOf(context).width) <= .medium
        ? DraggableSheetView(
            row1: orderCatalogListView,
            row2: orderProductListView,
            row3_1: const CartProductSelector(),
            row3_2Builder: (scroll, scrollable) => Expanded(
              child: CartProductList(scrollController: scroll, scrollable: scrollable),
            ),
            row3_3: const CartMetadataView(),
            row4: const CartProductStateSelector(),
            resetNotifier: _resetNotifier,
          )
        : OrientatedView(
            row1: orderCatalogListView,
            row2: orderProductListView,
            row3_1: const CartProductSelector(),
            row3_2: const Expanded(child: CartProductList()),
            row3_3: const CartMetadataView(),
            row4: const CartProductStateSelector(),
          );

    return TutorialWrapper(
      child: Scaffold(
        // avoid resize when keyboard(bottom inset) shows
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          leading: const PopButton(),
          title: ListenableBuilder(
            listenable: Cart.instance,
            builder: (context, _) {
              final c = Cart.instance;
              final text = c.no == 0
                  ? 'New order'
                  : (c.label.isEmpty ? 'Order #${c.no}' : 'Order #${c.no} · ${c.label}');
              return Text(text, style: Theme.of(context).textTheme.titleMedium);
            },
          ),
          actions: [
            MoreButton(key: const Key('order.more'), onPressed: _showActions),
            const PrinterButtonView(),
            TextButton(
              key: const Key('order.checkout'),
              onPressed: () => _handleCheckout(),
              child: Text(S.orderActionCheckout),
            ),
          ],
        ),
        body: body,
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ListenableBuilder(
                    listenable: StashedOrders.instance,
                    builder: (context, _) => OutlinedButton.icon(
                      key: const Key('order.open_orders'),
                      icon: const Icon(Icons.receipt_long_outlined),
                      label: FutureBuilder<StashedOrderMetrics>(
                        future: StashedOrders.instance.getMetrics(),
                        builder: (context, snap) => Text('Open orders (${snap.data?.count ?? 0})'),
                      ),
                      onPressed: _handleOpenOrders,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('order.new_order'),
                    icon: const Icon(Icons.add),
                    label: const Text('New order'),
                    onPressed: _handleNewOrder,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _pageController.dispose();
    _catalogIndexNotifier.dispose();
    _productViewNotifier.dispose();
    _resetNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    WakelockPlus.toggle(enable: OrderAwakeningSetting.instance.value);
    // rebind menu/attributes if changed
    Cart.instance.rebind();
    // ensure the active order has a ticket number to display
    Cart.instance.ensureOpen();

    _pageController = PageController();
    _catalogIndexNotifier = ValueNotifier<int>(0);
    _productViewNotifier = ValueNotifier<ProductListView>(ProductListView.grid);
    super.initState();
  }

  void _handleCheckout() async {
    final status = await context.pushNamed<CheckoutStatus>(Routes.orderCheckout);
    if (status != null && mounted) {
      handleCheckoutStatus(context, status);
      _resetNotifier.notify();
    }
  }

  void _showActions(BuildContext context) async {
    final result = await showPositionedMenu<_Action>(
      context,
      actions: [
        MenuAction(
          key: const Key('order.action.exchange'),
          title: Text(S.orderActionExchange),
          leading: const Icon(Icons.change_circle_outlined),
          returnValue: const _Action(route: Routes.cashierChanger),
        ),
        MenuAction(
          key: const Key('order.action.stash'),
          title: Text(S.orderActionStash),
          leading: const Icon(Icons.archive_outlined),
          returnValue: _Action(action: _handleStash),
        ),
        MenuAction(
          key: const Key('order.action.history'),
          title: Text(S.orderActionReview),
          leading: const Icon(Icons.history_outlined),
          returnValue: const _Action(route: Routes.history),
        ),
      ],
    );

    if (context.mounted && result != null) {
      final success = await result.exec(context);

      if (success == true && context.mounted) {
        showSnackBar(S.actSuccess, context: context);
      }
    }
  }

  Future<bool?> _handleStash() {
    DraggableScrollableActuator.reset(context);
    return Cart.instance.stash();
  }

  void _handleNewOrder() async {
    await Cart.instance.startNewOrder();
    if (!mounted) return;
    _resetNotifier.notify();
    await editOrderLabel(context, Cart.instance.no, Cart.instance.label, (v) => Cart.instance.setLabel(v));
  }

  void _handleOpenOrders() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OpenOrderListView(),
    );
    if (!mounted) return;

    _resetNotifier.notify();
    if (result == 'checkout') {
      _handleCheckout();
    } else if (result == 'new') {
      await editOrderLabel(context, Cart.instance.no, Cart.instance.label, (v) => Cart.instance.setLabel(v));
    }
  }
}

void handleCheckoutStatus(BuildContext context, CheckoutStatus status) {
  status = CheckoutWarningSetting.instance.shouldShow(status);

  return switch (status) {
    CheckoutStatus.ok || CheckoutStatus.stash || .restore => showSnackBar(S.actSuccess, context: context),
    .cashierNotEnough => showSnackBar(S.orderSnackbarCashierNotEnough, context: context),
    .cashierUsingSmall => showMoreInfoSnackBar(
      S.orderSnackbarCashierUsingSmallMoney,
      Linkify.fromString(S.orderSnackbarCashierUsingSmallMoneyHelper(Routes.getRoute('settings/checkoutWarning'))),
      context: context,
    ),
    _ => null,
  };
}

/// [DraggableScrollableActuator] will trigger `animateTo` while building widget
/// which will cause `setState` to be called during build.
///
/// This notifier is used to avoid this issue.
class _Notifier extends ChangeNotifier {
  void notify() {
    notifyListeners();
  }
}

class _Action {
  final Future<bool?> Function()? action;

  final String? route;

  const _Action({this.action, this.route});

  Future<bool?> exec(BuildContext context) {
    return route == null ? action!() : context.pushNamed(route!);
  }
}

enum ProductListView {
  grid(Icon(Icons.grid_view_outlined)),
  list(Icon(Icons.view_list_outlined));

  final Icon icon;

  const ProductListView(this.icon);
}
