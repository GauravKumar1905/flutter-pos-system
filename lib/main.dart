import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:possystem/constants/constant.dart';
import 'package:possystem/models/analysis/analysis.dart';
import 'package:possystem/models/printer.dart';
import 'package:possystem/models/repository/cart.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'helpers/logger.dart';
import 'models/repository/cashier.dart';
import 'models/repository/menu.dart';
import 'models/repository/order_attributes.dart';
import 'models/repository/quantities.dart';
import 'models/repository/replenisher.dart';
import 'models/repository/seller.dart';
import 'models/repository/stock.dart';
import 'services/cache.dart';
import 'services/database.dart';
import 'services/storage.dart';
import 'settings/collect_events_setting.dart';
import 'settings/settings_provider.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Firebase removed — running fully offline/local
  Log.out('start (offline mode, no Firebase)', 'init');

  try {
  await Database.instance.initialize(logWhenQuery: isLocalTest);
  await Storage.instance.initialize();
  await Cache.instance.initialize();

  SettingsProvider.instance.initialize();
  Log.allowSendEvents = false; // no analytics in local mode

  await Stock().initialize();
  await Quantities().initialize();
  await OrderAttributes().initialize();
  await Replenisher().initialize();
  await Cashier().reset();
  await Analysis().initialize();
  await Printers().initialize();
  await Menu().initialize();

  } catch (e, stack) {
    FlutterNativeSplash.remove();
    runApp(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Startup Error', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                const SizedBox(height: 16),
                Text(e.toString(), style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
                Text(stack.toString(), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    ));
    return;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: SettingsProvider.instance),
        ChangeNotifierProvider.value(value: Menu.instance),
        ChangeNotifierProvider.value(value: Stock.instance),
        ChangeNotifierProvider.value(value: Quantities.instance),
        ChangeNotifierProvider.value(value: Replenisher.instance),
        ChangeNotifierProvider.value(value: OrderAttributes.instance),
        ChangeNotifierProvider.value(value: Seller.instance),
        ChangeNotifierProvider.value(value: Cashier.instance),
        ChangeNotifierProvider.value(value: Cart.instance),
        ChangeNotifierProvider.value(value: Printers.instance),
      ],
      child: const App(),
    ),
  );
}
