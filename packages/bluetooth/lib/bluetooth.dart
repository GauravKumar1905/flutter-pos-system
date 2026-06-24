/// Local implementation replacing the private flutter-pos-packages.
/// Uses print_bluetooth_thermal for actual Bluetooth thermal printing.
library bluetooth;

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

// ─── Logging ─────────────────────────────────────────────────────────────────

enum LogLevel { debug, info, warn, error }

class Logger {
  static LogLevel level = LogLevel.info;
}

// ─── Exception codes / from ──────────────────────────────────────────────────

enum BluetoothExceptionCode {
  unknown,
  timeout,
  deviceNotFound,
  adapterIsOff,
  characteristicNotFound,
  connectionCanceled,
  deviceIsDisconnected,
  serviceNotFound,
  userRejected,
}

enum BluetoothExceptionFrom { scan, connect, disconnect, draw }

// ─── Exceptions ──────────────────────────────────────────────────────────────

class BluetoothException implements Exception {
  /// Matches BluetoothExceptionCode.xxx.index for UI comparisons
  final int code;
  final String? description;
  final String? function;

  BluetoothException({
    required this.code,
    this.description,
    this.function,
  });

  @override
  String toString() => 'BluetoothException($code): ${description ?? function ?? "unknown"}';
}

class BluetoothOffException extends BluetoothException {
  BluetoothOffException()
      : super(
          code: BluetoothExceptionCode.adapterIsOff.index,
          description: 'Bluetooth adapter is off',
        );
}

// ─── Signals / Status / Density ──────────────────────────────────────────────

enum BluetoothSignal { weak, normal, good }

enum PrinterStatus {
  good,
  printing,
  unknown,
  unrecoverable,
  writeFailed,
  paperJams,
  paperNotFound,
  lowBattery,
  tooHot,
  uncovering,
  noResponse;

  /// 0 = all good, 1+ = needs attention.
  /// Used by UI to decide which icon to show.
  int get priority {
    switch (this) {
      case PrinterStatus.good:
      case PrinterStatus.printing:
      case PrinterStatus.unknown:
        return 0;
      case PrinterStatus.lowBattery:
      case PrinterStatus.tooHot:
      case PrinterStatus.uncovering:
      case PrinterStatus.noResponse:
        return 1;
      case PrinterStatus.unrecoverable:
      case PrinterStatus.writeFailed:
      case PrinterStatus.paperJams:
      case PrinterStatus.paperNotFound:
        return 2;
    }
  }
}

enum PrinterDensity { normal, tight }

// ─── Bluetooth Device ─────────────────────────────────────────────────────────

class BluetoothDevice {
  final String name;
  final String address;
  bool connected;

  BluetoothDevice({
    required this.name,
    required this.address,
    this.connected = false,
  });

  /// Demo device used in printer modal when no real devices scanned yet.
  factory BluetoothDevice.demo() => BluetoothDevice(
        name: 'Demo Printer',
        address: '00:00:00:00:00:00',
      );

  /// Periodically emits signal strength (simulated for now).
  Stream<BluetoothSignal> createSignalStream() async* {
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield BluetoothSignal.good;
    }
  }
}

// ─── Bluetooth scanner ───────────────────────────────────────────────────────

class Bluetooth {
  static final Bluetooth i = Bluetooth._();
  static Bluetooth get instance => i;
  Bluetooth._();

  bool _scanning = false;

  Stream<List<BluetoothDevice>> startScan() async* {
    _scanning = true;
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      if (_scanning) {
        yield paired
            .map((b) => BluetoothDevice(name: b.name ?? 'Unknown', address: b.macAdress))
            .toList();
      }
    } catch (_) {
      yield [];
    }
  }

  Future<void> stopScan() async {
    _scanning = false;
  }
}

// ─── PrinterManufactory ──────────────────────────────────────────────────────

abstract class PrinterManufactory {
  const PrinterManufactory();
  int get widthBits;
  int get widthMM;

  static PrinterManufactory? tryGuess(String name) {
    final n = name.toLowerCase();
    if (n.contains('cat')) return const CatPrinter();
    if (n.contains('xprinter') || n.contains('xp-')) return const XPrinter();
    if (n.contains('yokoscan')) return const YokoscanPrinter();
    return null;
  }
}

class CatPrinter extends PrinterManufactory {
  final int feedPaperByteSize;
  const CatPrinter({this.feedPaperByteSize = 1});
  @override int get widthBits => 384;
  @override int get widthMM => 58;
  @override String toString() => 'CatPrinter';
}

class XPrinter extends PrinterManufactory {
  @override final int widthMM;
  @override final int widthBits;
  const XPrinter({this.widthMM = 58, this.widthBits = 384});
  @override String toString() => 'XPrinter';
}

class YokoscanPrinter extends PrinterManufactory {
  @override final int widthMM;
  @override final int widthBits;
  const YokoscanPrinter({this.widthMM = 58, this.widthBits = 384});
  @override String toString() => 'YokoscanPrinter';
}

class EpsonPrinter extends PrinterManufactory {
  const EpsonPrinter();
  @override int get widthBits => 576;
  @override int get widthMM => 80;
  @override String toString() => 'EpsonPrinter';
}

// ─── Printer ─────────────────────────────────────────────────────────────────

class Printer extends ChangeNotifier {
  final String address;
  final PrinterManufactory manufactory;

  PrinterStatus _status = PrinterStatus.unknown;
  BluetoothDevice? _device;
  final _statusController = StreamController<PrinterStatus>.broadcast();

  Printer({required this.address, required this.manufactory, Printer? other});

  bool get connected => _status == PrinterStatus.good;

  PrinterStatus get status => _status;

  /// The connected BluetoothDevice (available after connect()).
  BluetoothDevice? get device => _device;

  /// Stream of printer status changes.
  Stream<PrinterStatus> get statusStream => _statusController.stream;

  void _setStatus(PrinterStatus s) {
    _status = s;
    _statusController.add(s);
    notifyListeners();
  }

  Future<bool> connect() async {
    _setStatus(PrinterStatus.printing); // "connecting" state
    try {
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: address);
      if (ok) {
        _device = BluetoothDevice(name: 'Printer', address: address, connected: true);
        _setStatus(PrinterStatus.good);
      } else {
        _device = null;
        _setStatus(PrinterStatus.noResponse);
      }
      return ok;
    } catch (e) {
      _device = null;
      _setStatus(PrinterStatus.unrecoverable);
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    _device = null;
    _setStatus(PrinterStatus.unknown);
  }

  /// Sends image bytes to printer. Returns progress 0.0→1.0.
  Stream<double> draw(Uint8List image, {PrinterDensity density = PrinterDensity.normal}) async* {
    yield 0.0;
    _setStatus(PrinterStatus.printing);
    try {
      final ok = await PrintBluetoothThermal.writeBytes(image);
      _setStatus(ok ? PrinterStatus.good : PrinterStatus.writeFailed);
      yield ok ? 1.0 : 0.0;
    } catch (e) {
      _setStatus(PrinterStatus.unrecoverable);
      yield 0.0;
      rethrow;
    }
  }

  @override
  void dispose() {
    _statusController.close();
    super.dispose();
  }
}
