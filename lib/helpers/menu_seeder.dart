import 'package:flutter/services.dart';
import 'package:possystem/helpers/logger.dart';
import 'package:possystem/models/repository/menu.dart';
import 'package:possystem/services/cache.dart';
import 'package:possystem/ui/transit/exporter/csv_exporter.dart';
import 'package:possystem/ui/transit/formatter/model_parser.dart';

class MenuSeeder {
  static const _seededKey = 'menuSeededV1';

  static Future<void> seedIfNeeded() async {
    if (Cache.instance.get<bool>(_seededKey) == true) return;

    if (Menu.instance.isNotEmpty) {
      await Cache.instance.set(_seededKey, true);
      return;
    }

    try {
      final csvText = await rootBundle.loadString('assets/menu_seed.csv');
      final lines = csvText.split('\n').where((l) => l.trim().isNotEmpty).toList();

      // Skip the header row
      final parser = MenuParser(.instance);
      int counter = 1;
      for (final line in lines.skip(1)) {
        final row = CSVExporter.split(line);
        if (parser.validate(row) == null) {
          parser.parse(row, counter++);
        }
      }

      await Menu.instance.commitStaged();
      await Cache.instance.set(_seededKey, true);
      Log.out('menu seeded with ${counter - 1} products', 'menu_seeder');
    } catch (e, stack) {
      Log.out('menu seed failed: $e\n$stack', 'menu_seeder');
    }
  }
}
