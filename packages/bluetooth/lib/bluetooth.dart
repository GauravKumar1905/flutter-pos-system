/// Local implementation replacing the private flutter-pos-packages.
/// Uses print_bluetooth_thermal for actual Bluetooth thermal printing.
library bluetooth;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

// ─── Logging ────────────────────────────────────────────────────────────────

enum LogLevel { debug, info, warn, error }

class Logger {
  static LogLevel level = LogLevel.info;
}

// ─── Exceptions ──────────────────────────────────────────────────────────────

enum BluetoothExceptionCode { unknown, timeout, deviceNotFound }
enum BluetoothExceptionFrom { scan, connect, disconnect, draw }

class BluetoothException implements Exception {
  final BluetoothExceptionCode code;
  final BluetoothExceptionFrom from;
  final String message;
  BluetoothException({required this.code, required this.from, this.message = ''});
  @override
  String toString() => 'BluetoothException($code, $from): $message';
}

class BluetoothOffException extends BluetoothException {
  BluetoothOffException()
      : super(code: BluetoothExceptionCode.unknown, from: BluetoothExceptionFrom.connect, message: 'Bluetooth is off');
}

// ─── Device ──────────────────────────────────────────────────────────────────

class BluetoothDevice {
  final String name;
  final String address;
  BluetoothDevice({required this.name, required this.address});
}

// ─── Signal / Status ─────────────────────────────────────────────────────────

enum BluetoothSignal { strong, medium, weak, none }

enum PrinterStatus { connected, connecting, disconnected, error }

enum PrinterDensity { light, normal, dark }

// ─── Bluetooth manager ───────────────────────────────────────────────────────

class Bluetooth {
  static final Bluetooth i = Bluetooth._();
  Bluetooth._();

  bool _scanning = false;

  Stream<List<BluetoothDevice>> startScan() async* {
    _scanning = true;
    final available = await PrintBluetoothThermal.pairedBluetooths;
    if (!_scanning) return;
    yield available
        .map((b) => BluetoothDevice(name: b.name ?? 'Unknown', address: b.macAdress))
        .toList();
  }

  Future<void> stopScan() async {
    _scanning = false;
  }
}

// ─── PrinterManufactory ──────────────────────────────────────────────────────

abstract class PrinterManufactory {
  int get widthBits;
  int get widthMM;

  static PrinterManufactory? tryGuess(String name) {
    final n = name.toLowerCase();
    if (n.contains('cat')) return CatPrinter();
    if (n.contains('xprinter') || n.contains('xp-58')) return XPrinter();
    if (n.contains('yokoscan')) return YokoscanPrinter();
    return null;
  }
}

class CatPrinter extends PrinterManufactory {
  final int feedPaperByteSize;
  CatPrinter({this.feedPaperByteSize = 1});
  @override int get widthBits => 384;
  @override int get widthMM => 58;
  @override String toString() => 'CatPrinter';
}

class XPrinter extends PrinterManufactory {
  @override final int widthMM;
  @override final int widthBits;
  XPrinter({this.widthMM = 58, this.widthBits = 384});
  @override String toString() => 'XPrinter';
}

class YokoscanPrinter extends PrinterManufactory {
  @override final int widthMM;
  @override final int widthBits;
  YokoscanPrinter({this.widthMM = 58, this.widthBits = 384});
  @override String toString() => 'YokoscanPrinter';
}

class EpsonPrinter extends PrinterManufactory {
  @override int get widthBits => 576;
  @override int get widthMM => 80;
  @override String toString() => 'EpsonPrinter';
}

// ─── Printer ─────────────────────────────────────────────────────────────────

class Printer extends ChangeNotifier {
  final String address;
  final PrinterManufactory manufactory;

  PrinterStatus _status = PrinterStatus.disconnected;

  Printer({required this.address, required this.manufactory, Printer? other});

  bool get connected => _status == PrinterStatus.connected;

  PrinterStatus get status => _status;

  Future<bool> connect() async {
    _status = PrinterStatus.connecting;
    notifyListeners();
    try {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address);
      _status = ok ? PrinterStatus.connected : PrinterStatus.error;
      notifyListeners();
      return ok;
    } catch (e) {
      _status = PrinterStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await PrintBluetoothThermal.disconnect;
    _status = PrinterStatus.disconnected;
    notifyListeners();
  }

  /// Draw image bytes to printer. Returns progress stream (0.0 → 1.0).
  Stream<double> draw(Uint8List image, {PrinterDensity density = PrinterDensity.normal}) async* {
    yield 0.0;
    try {
      // Send raw bytes directly to the thermal printer
      final ok = await PrintBluetoothThermal.writeBytes(image);
      yield ok ? 1.0 : 0.0;
    } catch (e) {
      yield 0.0;
      rethrow;
    }
  }
}
