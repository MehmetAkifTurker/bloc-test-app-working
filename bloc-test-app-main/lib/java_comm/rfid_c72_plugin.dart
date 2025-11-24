import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RfidC72Plugin {
  static const MethodChannel _channel = MethodChannel('rfid_c72_plugin');
  static const MethodChannel _keyEventChannel =
      MethodChannel('com.example.my_rfid_plugin/key_events');
  static bool _barcodeConnected = false;
  static final _barcodeCtrl = StreamController<String>.broadcast();
  static Stream<String> get barcodeStream => _barcodeCtrl.stream;
  static bool _holdScan = false; // tuş basılı mı?
  static bool _loopRunning = false; // loop açık mı?
  static bool _innerScanActive = false; // tek tarama in-flight mi?
  static bool _isScanKey(int code) => const {131, 132, 293, 294}.contains(code);

  // --- DEBUG STREAM ---
  static final _debugCtrl = StreamController<String>.broadcast();
  static Stream<String> get debugStream => _debugCtrl.stream;
  static bool verbose = true;

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    final line = 'RFID[$ts] $msg';
    debugPrint(line);
    if (!_debugCtrl.isClosed) _debugCtrl.add(line);
  }

  static Future<String?> get platformVersion async {
    final String? version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static const EventChannel connectedStatusStream =
      EventChannel('ConnectedStatus');
  static const EventChannel tagsStatusStream = EventChannel('TagsStatus');

  static Future<bool?> get isStarted async {
    return _channel.invokeMethod('isStarted');
  }

  static Completer<bool>? _uhfConnectBusy;

  static Future<bool> ensureUhfConnected({String? power, String? area}) async {
    // Tek seferde bir bağlantı denemesi (idempotent)
    if (_uhfConnectBusy != null) return _uhfConnectBusy!.future;
    _uhfConnectBusy = Completer<bool>();
    try {
      // 0) Barkod döngüsünü durdur (varsa) – çakışmayı önler
      try {
        await disposeBarcode();
      } catch (_) {}

      // 1) Zaten bağlı mı?
      final already = await isConnected;
      if (already == true) {
        if (power != null) await setPowerLevel(power);
        if (area != null) await setWorkArea(area);
        debugPrint('RFID ensureUhfConnected => true');
        _uhfConnectBusy!.complete(true);
        return true;
      }

      // 2) Bağlan
      final ok = await connect;
      if (ok == true) {
        if (power != null) await setPowerLevel(power);
        if (area != null) await setWorkArea(area);
        debugPrint('RFID ensureUhfConnected => true');
        _uhfConnectBusy!.complete(true);
        return true;
      } else {
        debugPrint('RFID ensureUhfConnected => false');
        _uhfConnectBusy!.complete(false);
        return false;
      }
    } finally {
      _uhfConnectBusy = null;
    }
  }

  static Future<bool?> get startSingle async {
    return _channel.invokeMethod('startSingle');
  }

  static Future<bool?> get startContinuous async {
    return _channel.invokeMethod('startContinuous');
  }

  static Future<bool?> get startContinuous2 async {
    return _channel.invokeMethod('startContinuous2');
  }

  static Future<bool?> get stop async {
    return _channel.invokeMethod('stop');
  }

  static Future<bool?> get close async {
    return _channel.invokeMethod('close');
  }

  static Future<bool?> get clearData async {
    return _channel.invokeMethod('clearData');
  }

  static Future<bool?> get isEmptyTags async {
    return _channel.invokeMethod('isEmptyTags');
  }

  static Future<bool?> get connect async {
    return _channel.invokeMethod('connect');
  }

  static Future<bool?> get isConnected async {
    return _channel.invokeMethod('isConnected');
  }

  static Future<bool?> get connectBarcode async {
    return _channel.invokeMethod('connectBarcode');
  }

  static Future<bool?> get scanBarcode async {
    return _channel.invokeMethod('scanBarcode');
  }

  static Future<bool?> get stopScan async {
    return _channel.invokeMethod('stopScan');
  }

  static Future<bool?> get closeScan async {
    return _channel.invokeMethod('closeScan');
  }

  static Future<bool?> setPowerLevel(String value) async {
    return _channel
        .invokeMethod('setPowerLevel', <String, String>{'value': value});
  }

  static Future<bool?> setWorkArea(String value) async {
    return _channel
        .invokeMethod('setWorkArea', <String, String>{'value': value});
  }

  static Future<String?> get readBarcode async {
    final String? barcode = await _channel.invokeMethod('readBarcode');
    return barcode;
  }

  static Future<bool?> get playSound async {
    return _channel.invokeMethod('playSound');
  }

  static Future<String?> get getPowerLevel async {
    final String? powerLevel = await _channel.invokeMethod('getPowerLevel');
    return powerLevel;
  }

  static Future<String?> get getFrequencyMode async {
    final String? frequencyMode =
        await _channel.invokeMethod('getFrequencyMode');
    return frequencyMode;
  }

  static Future<String?> get getTemperature async {
    final String? getTemperature =
        await _channel.invokeMethod('getTemperature');
    return getTemperature;
  }

  static Future<bool?> writeTag(String value) async {
    final result = await _channel
        .invokeMethod('writeTag', <String, String>{'value': value});
    return result;
  }

  static Future<bool?> writeTagADIConstruct2(
      String partNumber, String serialNumber) async {
    final result =
        await _channel.invokeMethod('writeTagADIConstruct2', <String, String>{
      'partNumber': partNumber.toUpperCase(),
      'serialNumber': serialNumber.toUpperCase()
    });
    return result;
  }

  static Future<String?> readSingleTagEpc() async {
    final String? epcHex = await _channel.invokeMethod('readSingleTagEpc');
    return epcHex;
  }

  static Future<String?> readSingleTagEpcBasic() async {
    final String? epcHex = await _channel.invokeMethod('readSingleTagEpcBasic');
    return epcHex;
  }

  static Future<String?> readSingleTagWithTid() async {
    final String? tagInfo = await _channel.invokeMethod('readSingleTagWithTid');
    return tagInfo;
  }

  static Future<String?> diagnosticReadSingleTag() async {
    final String? diagnostic =
        await _channel.invokeMethod('diagnosticReadSingleTag');
    return diagnostic;
  }

  // Key Event Handling
  static void initializeKeyEventHandler(BuildContext context) {
    _log('Key handler attached');
    _keyEventChannel
        .setMethodCallHandler((call) => _handleKeyEvent(call, context));
  }

  static const EventChannel locationStatusStream =
      EventChannel('LocationStatus');

  static Future<bool?> startLocation({
    required String label,
    required int bank,
    required int ptr,
  }) async {
    final result = await _channel.invokeMethod('startLocation', {
      'label': label,
      'bank': bank,
      'ptr': ptr,
    });
    return result;
  }

  static Future<bool?> stopLocation() async {
    return await _channel.invokeMethod('stopLocation');
  }

  static Future<void> _handleKeyEvent(
      MethodCall call, BuildContext context) async {
    switch (call.method) {
      case 'onKeyDown':
        {
          final int keyCode = (call.arguments as int?) ?? -1;
          debugPrint('RFID onKeyDown key=$keyCode');
          if (!_isScanKey(keyCode)) return;
          _holdScan = true;
          await _startBarcodeLoop();
          break;
        }
      case 'onKeyUp':
        {
          final int keyCode = (call.arguments as int?) ?? -1;
          debugPrint('RFID onKeyUp   key=$keyCode');
          if (!_isScanKey(keyCode)) return;
          await _stopBarcodeLoop();
          break;
        }
      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  }

  static Future<bool?> writeAtaUserMemoryWithPayload(
    String manufacturer,
    String productName,
    String partNumber,
    String serialNumber,
    String manufactureDate,
    String expireDate,
  ) {
    return _channel.invokeMethod<bool>('writeAtaUserMemoryWithPayload', {
      'manufacturer': manufacturer,
      'productName': productName, // boş string yollanabilir
      'partNumber': partNumber,
      'serialNumber': serialNumber,
      'manufactureDate': manufactureDate,
      'expireDate': expireDate,
    });
  }

  static Future<bool?> programConstruct2Epc({
    required String partNumber,
    required String serialNumber,
    required String manager, // 6 char (ör: ' TG424')
    String accessPwd = '00000000',
    required int filter, // 0..63
  }) {
    return _channel.invokeMethod<bool>('programConstruct2Epc', {
      'partNumber': partNumber,
      'serialNumber': serialNumber,
      'manager': manager,
      'accessPwd': accessPwd,
      'filter': filter,
    });
  }

  static Future<bool?> configureChipAta({
    required String recordType, // 'DRT', 'SRT-B', 'SRT-U', 'MRT' vb.
    required int epcWords,
    required int userWords,
    required int permalockWords,
    required bool enablePermalock,
    required bool lockEpc,
    required bool lockUser,
    String accessPwd = '00000000',
  }) {
    return _channel.invokeMethod<bool>('configureChipAta', {
      'recordType': recordType,
      'epcWords': epcWords,
      'userWords': userWords,
      'permalockWords': permalockWords,
      'enablePermalock': enablePermalock,
      'lockEpc': lockEpc,
      'lockUser': lockUser,
      'accessPwd': accessPwd,
    });
  }

  static Future<String?> readUserMemory() async {
    // (You might not need epcHex, but keep it for now for future filtering)
    return await _channel.invokeMethod('readUserMemory');
  }

  static Future<String?> readUserMemoryForEpc(String epcHex) async {
    return _channel
        .invokeMethod<String>('readUserMemoryForEpc', {'epc': epcHex});
  }

  static Future<List<Map<String, dynamic>>> getCurrentTags() async {
    final String json = await _channel.invokeMethod('getCurrentTags');
    final List<dynamic> list = jsonDecode(json);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<Map<String, dynamic>?> readUserFieldsForEpc(
      String epcHex) async {
    final String? json = await _channel
        .invokeMethod<String>('readUserFieldsForEpc', {'epc': epcHex});
    if (json == null || json.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(json));
  }

  static Future<void> _ensureBarcodeOpened() async {
    if (!_barcodeConnected) {
      _log('connectBarcode()…');
      _barcodeConnected = (await connectBarcode) ?? false;
      _log('connectBarcode => ${_barcodeConnected ? "OK" : "FAIL"}');
    }
  }

  static Future<String?> _waitForDecode(
      {Duration timeout = const Duration(milliseconds: 500)}) async {
    final sw = Stopwatch()..start();
    int polls = 0;
    String? last;
    while (sw.elapsed < timeout) {
      final s = await RfidC72Plugin.readBarcode;
      if (s != null && s.isNotEmpty && s != 'FAIL') {
        _log('decode OK in ${sw.elapsedMilliseconds}ms (polls=$polls): "$s"');
        return s;
      }
      last = s;
      polls++;
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _log(
        'decode TIMEOUT after ${sw.elapsedMilliseconds}ms (polls=$polls, last="$last")');
    return null;
  }

// Tetik basılınca çağrılacak
  static Future<void> _startBarcodeLoop() async {
    if (_loopRunning) {
      _log('loop already running');
      return;
    }
    _loopRunning = true;

    await _ensureBarcodeOpened();
    _log('startBarcodeLoop hold=$_holdScan opened=$_barcodeConnected');

    while (_holdScan && _barcodeConnected) {
      if (_innerScanActive) {
        await Future.delayed(const Duration(milliseconds: 20));
        continue;
      }

      _innerScanActive = true;
      try {
        _log('scanBarcode()');
        await RfidC72Plugin.scanBarcode;
        final code = await _waitForDecode();
        if (code != null) {
          _barcodeCtrl.add(code);
          await RfidC72Plugin.playSound;
        }
      } finally {
        _log('stopScan()');
        await RfidC72Plugin.stopScan;
        _innerScanActive = false;
      }

      if (_holdScan) await Future.delayed(const Duration(milliseconds: 40));
    }

    _log('exit loop hold=$_holdScan');
    _loopRunning = false;
  }

  static Future<void> _stopBarcodeLoop() async {
    _log('stopBarcodeLoop() called');
    _holdScan = false;
    await RfidC72Plugin.stopScan;
  }

// Ekrandan çıkarken çağırmak için
  static Future<void> disposeBarcode() async {
    await _stopBarcodeLoop();
    await closeScan;
    _barcodeConnected = false;
  }

  static Future<void> _handleKeyEventNoCtx(MethodCall call) async {
    switch (call.method) {
      case 'onKeyDown':
        {
          final int keyCode = (call.arguments as int?) ?? -1;
          debugPrint('RFID onKeyDown key=$keyCode');
          if (!_isScanKey(keyCode)) return;
          _holdScan = true;
          await _startBarcodeLoop();
          break;
        }
      case 'onKeyUp':
        {
          final int keyCode = (call.arguments as int?) ?? -1;
          debugPrint('RFID onKeyUp   key=$keyCode');
          if (!_isScanKey(keyCode)) return;
          await _stopBarcodeLoop();
          break;
        }
    }
  }

  static bool _handlerRegistered = false;
  static Future<void> ensureKeyHandler() async {
    if (_handlerRegistered) return;
    _log('Key handler attached (global)');
    _keyEventChannel.setMethodCallHandler(_handleKeyEventNoCtx);
    _handlerRegistered = true;
  }
}
