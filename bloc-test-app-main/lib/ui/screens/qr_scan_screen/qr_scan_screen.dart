// // lib/ui/screens/qr_scan/qr_scan_screen.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

// class QrScanScreen extends StatefulWidget {
//   const QrScanScreen({Key? key}) : super(key: key);

//   @override
//   State<QrScanScreen> createState() => _QrScanScreenState();
// }

// class _QrScanScreenState extends State<QrScanScreen> {
//   bool _connected = false;
//   bool _scanning = false;
//   bool _continuous = true;
//   late final StreamSubscription _sub;
//   bool _showDebug = true;
//   late final StreamSubscription _debugSub;
//   final List<String> _logs = <String>[];

//   String _last = '';
//   final List<String> _history = [];

//   Timer? _pollTimer;

//   @override
//   void initState() {
//     super.initState();
//     RfidC72Plugin.initializeKeyEventHandler(context);
//     RfidC72Plugin.connectBarcode; // “Decoder bağlı” durumunu netleştirir
//   }

//   Future<void> _initBarcode() async {
//     try {
//       final ok = await RfidC72Plugin.connectBarcode ?? false;
//       if (!mounted) return;
//       setState(() => _connected = ok);
//     } catch (_) {
//       if (!mounted) return;
//       setState(() => _connected = false);
//     }
//   }

//   Future<void> _start() async {
//     if (_scanning) return;
//     final ok = await RfidC72Plugin.scanBarcode ?? false;
//     if (!ok) return;
//     setState(() => _scanning = true);

//     _pollTimer?.cancel();
//     _pollTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
//       try {
//         final s = (await RfidC72Plugin.readBarcode) ?? '';
//         if (s.isEmpty || s == 'FAIL') return;
//         if (s == _last) return;

//         HapticFeedback.mediumImpact();
//         await SystemSound.play(SystemSoundType.click);

//         if (!mounted) return;
//         setState(() {
//           _last = s;
//           _history.insert(0, s);
//         });

//         if (!_continuous) {
//           await _stop();
//         }
//       } catch (_) {}
//     });
//   }

//   Future<void> _stop() async {
//     _pollTimer?.cancel();
//     _pollTimer = null;
//     await RfidC72Plugin.stopScan;
//     if (!mounted) return;
//     setState(() => _scanning = false);
//   }

//   @override
//   void dispose() {
//     RfidC72Plugin.disposeBarcode(); // loop + decoder kapat
//     _sub.cancel();
//     super.dispose();
//   }

//   void _copy(String text) async {
//     await Clipboard.setData(ClipboardData(text: text));
//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Kopyalandı')),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: commonAppBar(context, 'QR / BARCODE', showBack: true),
//       body: Padding(
//         padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Durum satırı
//             Row(
//               children: [
//                 Icon(
//                   _connected ? Icons.check_circle : Icons.error_outline,
//                   color: _connected ? Colors.green : Colors.red,
//                   size: 18,
//                 ),
//                 const SizedBox(width: 6),
//                 Text(
//                   _connected ? 'Decoder bağlı' : 'Decoder bağlı değil',
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 12),

//             // Son okuma kartı (uzunsa ortadan ... ile kısalt, uzun basınca kopyala)
//             Text('Son Okunan', style: TextStyle(color: Colors.grey.shade700)),
//             const SizedBox(height: 6),
//             GestureDetector(
//               onLongPress: _last.isEmpty ? null : () => _copy(_last),
//               child: Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   borderRadius: BorderRadius.circular(14),
//                   border: Border.all(color: Colors.grey.shade300),
//                 ),
//                 child: Text(
//                   _last.isEmpty ? '—' : _last,
//                   textAlign: TextAlign.left,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(fontSize: 16, height: 1.25),
//                 ),
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Kontroller
//             Row(
//               children: [
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: _scanning ? _stop : _start,
//                     icon: Icon(_scanning ? Icons.stop : Icons.qr_code_scanner),
//                     label: Text(_scanning ? 'Stop' : 'Start Scan'),
//                     style: ElevatedButton.styleFrom(
//                       minimumSize: const Size.fromHeight(48),
//                       backgroundColor: _scanning
//                           ? Colors.red.shade600
//                           : Colors.green.shade600,
//                       foregroundColor: Colors.white,
//                     ),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: () => setState(() {
//                       _history.clear();
//                       _last = '';
//                     }),
//                     icon: const Icon(Icons.clear_all),
//                     label: const Text('Clear'),
//                     style: OutlinedButton.styleFrom(
//                       minimumSize: const Size.fromHeight(48),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             SwitchListTile(
//               dense: true,
//               contentPadding: EdgeInsets.zero,
//               title: const Text('Debug log'),
//               subtitle: Text(_showDebug ? 'Visible' : 'Hidden'),
//               value: _showDebug,
//               onChanged: (v) => setState(() => _showDebug = v),
//             ),
//             if (_showDebug) ...[
//               const SizedBox(height: 6),
//               Container(
//                 height: 180,
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.9),
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: Colors.grey.shade700),
//                 ),
//                 child: _logs.isEmpty
//                     ? const Center(
//                         child: Text('No logs yet',
//                             style: TextStyle(color: Colors.white70)))
//                     : ListView.builder(
//                         reverse: true,
//                         itemCount: _logs.length,
//                         itemBuilder: (_, i) => Padding(
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 2),
//                           child: Text(
//                             _logs[i],
//                             style: const TextStyle(
//                               fontFamily: 'monospace',
//                               fontSize: 12,
//                               color: Colors.white,
//                             ),
//                             maxLines: 2,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ),
//                       ),
//               ),
//             ],

//             const SizedBox(height: 12),

//             // Geçmiş
//             Text('History', style: TextStyle(color: Colors.grey.shade700)),
//             const SizedBox(height: 6),
//             Expanded(
//               child: _history.isEmpty
//                   ? const Center(child: Text('Henüz okuma yok.'))
//                   : ListView.separated(
//                       itemCount: _history.length,
//                       separatorBuilder: (_, __) =>
//                           const Divider(height: 1, thickness: 1),
//                       itemBuilder: (_, i) {
//                         final item = _history[i];
//                         return ListTile(
//                           dense: true,
//                           title: Text(
//                             item,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           trailing: IconButton(
//                             icon: const Icon(Icons.copy_rounded, size: 20),
//                             onPressed: () => _copy(item),
//                           ),
//                         );
//                       },
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// lib/ui/screens/qr_scan/qr_scan_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({Key? key}) : super(key: key);

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _connected = false;
  bool _scanning = false;
  bool _continuous = true;
  late final StreamSubscription<String> _sub;

  String _last = '';
  final List<String> _history = [];

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    RfidC72Plugin.initializeKeyEventHandler(context);

    // Key handler’ı global ve 1 kez kur
    RfidC72Plugin.ensureKeyHandler();

    // 2D barkod modülünü aç (buton olmadan tetik de çalışabilsin)
    RfidC72Plugin.connectBarcode.then((ok) {
      debugPrint('QR: connectBarcode => $ok');
      if (mounted) setState(() => _connected = ok ?? false);
    });

    // Tetik + dahili loop’tan gelen sonuçları dinle
    _sub = RfidC72Plugin.barcodeStream.listen((code) {
      debugPrint('QR decode (stream): "$code"');
      if (!mounted) return;
      setState(() {
        _last = code;
        _history.insert(0, code);
      });
    });
  }

  // Sadece VS Code Debug Console'a log
  void _log(String msg) {
    final t = DateTime.now();
    String p2(int v) => v.toString().padLeft(2, '0');
    final ts =
        '${p2(t.hour)}:${p2(t.minute)}:${p2(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
    debugPrint('RFID[$ts] $msg');
  }

  Future<void> _initBarcode() async {
    try {
      final ok = await RfidC72Plugin.connectBarcode ?? false;
      if (!mounted) return;
      _log('connectBarcode => $ok');
      setState(() => _connected = ok);
    } catch (_) {
      if (!mounted) return;
      setState(() => _connected = false);
    }
  }

  Future<void> _start() async {
    if (_scanning) return;
    final ok = await RfidC72Plugin.scanBarcode ?? false;
    if (!ok) return;
    setState(() => _scanning = true);

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      try {
        final s = (await RfidC72Plugin.readBarcode) ?? '';
        if (s.isEmpty || s == 'FAIL' || s == _last) return;
        debugPrint('QR decode (poll): "$s"'); // butonla manuel mod
        if (!mounted) return;
        setState(() {
          _last = s;
          _history.insert(0, s);
        });
        if (!_continuous) await _stop();
      } catch (_) {}
    });
  }

  Future<void> _stop() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    await RfidC72Plugin.stopScan;
    if (!mounted) return;
    setState(() => _scanning = false);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _sub.cancel();
    RfidC72Plugin.disposeBarcode();
    super.dispose();
  }

  void _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kopyalandı')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: commonAppBar(context, 'QR / BARCODE', showBack: true),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Durum
            Row(
              children: [
                Icon(
                  _connected ? Icons.check_circle : Icons.error_outline,
                  color: _connected ? Colors.green : Colors.red,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  _connected ? 'Decoder bağlı' : 'Decoder bağlı değil',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Son okunan
            Text('Son Okunan', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            GestureDetector(
              onLongPress: _last.isEmpty ? null : () => _copy(_last),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  _last.isEmpty ? '—' : _last,
                  textAlign: TextAlign.left,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, height: 1.25),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Kontroller
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _scanning ? _stop : _start,
                    icon: Icon(_scanning ? Icons.stop : Icons.qr_code_scanner),
                    label: Text(_scanning ? 'Stop' : 'Start Scan'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: _scanning
                          ? Colors.red.shade600
                          : Colors.green.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _history.clear();
                      _last = '';
                    }),
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Geçmiş
            Text('History', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 6),
            Expanded(
              child: _history.isEmpty
                  ? const Center(child: Text('Henüz okuma yok.'))
                  : ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 1),
                      itemBuilder: (_, i) {
                        final item = _history[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            item,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            onPressed: () => _copy(item),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
