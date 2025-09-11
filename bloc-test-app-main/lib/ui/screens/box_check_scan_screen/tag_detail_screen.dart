// // lib/ui/screens/tag_detail_screen.dart
// import 'dart:async';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';

// class TagDetailScreen extends StatefulWidget {
//   final TagItem tagItem;
//   final String userMemoryHex;
//   const TagDetailScreen({
//     Key? key,
//     required this.tagItem,
//     required this.userMemoryHex,
//   }) : super(key: key);

//   @override
//   State<TagDetailScreen> createState() => _TagDetailScreenState();
// }

// /// Basit sinyal göstergesi — EventChannel('LocationStatus') ile dBm benzeri bir değer bekler
// class LocationStatusWidget extends StatefulWidget {
//   final bool isLocating;
//   const LocationStatusWidget({super.key, required this.isLocating});

//   @override
//   State<LocationStatusWidget> createState() => _LocationStatusWidgetState();
// }

// class _LocationStatusWidgetState extends State<LocationStatusWidget> {
//   static const EventChannel _locationStatusChannel =
//       EventChannel('LocationStatus');
//   StreamSubscription? _locationSub;
//   int? _signalStrength;

//   void _subscribe() {
//     _locationSub ??= _locationStatusChannel.receiveBroadcastStream().listen(
//       (event) {
//         setState(() {
//           _signalStrength =
//               event is int ? event : int.tryParse(event.toString());
//         });
//       },
//       onError: (_) => setState(() => _signalStrength = null),
//     );
//   }

//   void _unsubscribe() {
//     _locationSub?.cancel();
//     _locationSub = null;
//   }

//   @override
//   void initState() {
//     super.initState();
//     if (widget.isLocating) _subscribe();
//   }

//   @override
//   void didUpdateWidget(covariant LocationStatusWidget oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (widget.isLocating && !oldWidget.isLocating) {
//       _signalStrength = null;
//       _subscribe();
//     } else if (!widget.isLocating && oldWidget.isLocating) {
//       _unsubscribe();
//       _signalStrength = null;
//     }
//   }

//   @override
//   void dispose() {
//     _unsubscribe();
//     super.dispose();
//   }

//   int getBarLevel(int? v) {
//     if (v == null) return 0;
//     if (v >= 70) return 3;
//     if (v >= 40) return 2;
//     if (v > 0) return 1;
//     return 0;
//   }

//   Color getBarColor(int level, int activeLevel) {
//     if (level > activeLevel) return Colors.grey.shade300;
//     switch (level) {
//       case 1:
//         return Colors.green.shade900;
//       case 2:
//         return Colors.green.shade600;
//       case 3:
//         return Colors.green.shade300;
//       default:
//         return Colors.grey.shade300;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final int activeLevel = getBarLevel(_signalStrength);

//     if (!widget.isLocating) {
//       return const Card(
//         margin: EdgeInsets.all(8),
//         child: ListTile(
//           title: Text('Tag search not started yet'),
//           subtitle: Text('Press "Start Locate" to begin'),
//         ),
//       );
//     }

//     final String subtitleText = _signalStrength == null
//         ? 'Searching...'
//         : 'Signal Strength: $_signalStrength dBm';

//     final TextStyle subtitleStyle = _signalStrength == null
//         ? const TextStyle(color: Colors.orange)
//         : TextStyle(
//             fontWeight: FontWeight.w600, color: getBarColor(activeLevel, 3));

//     return Card(
//       margin: const EdgeInsets.all(8),
//       child: ListTile(
//         leading: SizedBox(
//           width: 32,
//           height: 32,
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: List.generate(3, (i) {
//               final int level = i + 1;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 1.5),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   width: 7,
//                   height: 10.0 + 7.0 * level,
//                   decoration: BoxDecoration(
//                     color: getBarColor(level, activeLevel),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               );
//             }),
//           ),
//         ),
//         title: const Text('Location Signal Strength'),
//         subtitle: Text(subtitleText, style: subtitleStyle),
//       ),
//     );
//   }
// }
// lib/ui/screens/tag_detail_screen.dart
// import 'dart:async';
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // SystemSound için
// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';

// class TagDetailScreen extends StatefulWidget {
//   final TagItem tagItem;
//   final String userMemoryHex;
//   const TagDetailScreen({
//     Key? key,
//     required this.tagItem,
//     required this.userMemoryHex,
//   }) : super(key: key);

//   @override
//   State<TagDetailScreen> createState() => _TagDetailScreenState();
// }

// // Ses modu
// enum AudioFeedback { off, beep }

// class _TagDetailScreenState extends State<TagDetailScreen> {
//   bool _isLocating = false;
//   bool _locatingBusy = false;

//   bool _autoFetch = true;
//   bool _reading = false;
//   Timer? _umTimer;
//   String _userHex = "";
//   static const _interval = Duration(milliseconds: 600);

//   // --- Ses/Beep kontrolü ---
//   AudioFeedback _audio = AudioFeedback.off;
//   static const EventChannel _locationStatusChannel =
//       EventChannel('LocationStatus'); // aynı kanaldan sinyal okuyoruz
//   StreamSubscription? _soundSub;
//   Timer? _beepTimer;
//   Duration? _beepEvery;

//   @override
//   void initState() {
//     super.initState();
//     _userHex = widget.userMemoryHex;
//     if (_userHex.isEmpty) _startAutoUserRead();

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       log('DETAIL — PN:${widget.tagItem.partNumber} SN:${widget.tagItem.serialNumber} CAGE:${widget.tagItem.cage}');
//     });
//   }

//   @override
//   void dispose() {
//     _umTimer?.cancel();
//     _stopBeep();
//     _soundSub?.cancel();
//     super.dispose();
//   }

//   // ----------------- USER MEMORY AUTO READ -----------------
//   void _startAutoUserRead() {
//     _umTimer?.cancel();
//     if (!_autoFetch) return;
//     _umTimer = Timer.periodic(_interval, (_) => _tryReadUser());
//   }

//   Future<void> _tryReadUser() async {
//     if (_reading) return;
//     _reading = true;
//     try {
//       final hex =
//           await RfidC72Plugin.readUserMemoryForEpc(widget.tagItem.rawEpc);
//       if (hex != null && hex.length >= 16) {
//         if (!mounted) return;
//         setState(() {
//           _userHex = hex;
//           _autoFetch = false; // bulundu → döngü dursun
//         });
//         _umTimer?.cancel();
//       }
//     } catch (_) {
//       // yut — bir sonraki periyotta tekrar denenecek
//     } finally {
//       _reading = false;
//     }
//   }

//   // ----------------- LOCATE -----------------
//   Future<void> _toggleLocate() async {
//     if (_locatingBusy) return;
//     setState(() => _locatingBusy = true);
//     try {
//       if (!_isLocating) {
//         final ok = await RfidC72Plugin.startLocation(
//           label: widget.tagItem.rawEpc,
//           bank: 1,
//           ptr: 32,
//         );
//         if (!mounted) return;
//         if (ok == true) {
//           setState(() => _isLocating = true);
//           _wireAudio(); // locate açıldı → ses kablola
//         }
//       } else {
//         final ok = await RfidC72Plugin.stopLocation();
//         if (!mounted) return;
//         if (ok == true) {
//           setState(() => _isLocating = false);
//           _wireAudio(); // locate kapandı → ses kapat
//         }
//       }
//     } finally {
//       if (mounted) setState(() => _locatingBusy = false);
//     }
//   }

//   // ----------------- AUDIO (BEEP) -----------------
//   void _wireAudio() {
//     // Locate kapalıysa ya da ses off ise her şeyi kapat.
//     if (!_isLocating || _audio == AudioFeedback.off) {
//       _soundSub?.cancel();
//       _soundSub = null;
//       _stopBeep();
//       return;
//     }

//     // Zaten bağlıysa tekrar bağlama
//     _soundSub ??=
//         _locationStatusChannel.receiveBroadcastStream().listen((event) {
//       final int? s = event is int ? event : int.tryParse(event.toString());
//       final d = _intervalForStrength(s);
//       // Aralık değiştiyse timer'ı yeniden başlat
//       if (_beepEvery?.inMilliseconds != d.inMilliseconds) {
//         _startBeepTimer(d);
//       }
//     }, onError: (_) {
//       _startBeepTimer(const Duration(milliseconds: 900));
//     });
//   }

//   Duration _intervalForStrength(int? s) {
//     // Yaklaştıkça daha sık bip
//     if (s == null) return const Duration(milliseconds: 900);
//     if (s < 30) return const Duration(milliseconds: 800);
//     if (s < 50) return const Duration(milliseconds: 600);
//     if (s < 70) return const Duration(milliseconds: 400);
//     return const Duration(milliseconds: 220);
//   }

//   void _startBeepTimer(Duration every) {
//     _beepEvery = every;
//     _beepTimer?.cancel();
//     _beepTimer = Timer.periodic(every, (_) async {
//       try {
//         await SystemSound.play(SystemSoundType.alert); // basit bip
//       } catch (_) {}
//     });
//   }

//   void _stopBeep() {
//     _beepTimer?.cancel();
//     _beepTimer = null;
//     _beepEvery = null;
//   }

//   // ----------------- UI -----------------
//   @override
//   Widget build(BuildContext context) {
//     final int activeLevel = getBarLevel(_signalStrength);

//     if (!widget.isLocating) {
//       return const Card(
//         margin: EdgeInsets.all(8),
//         child: ListTile(
//           title: Text('Tag search not started yet'),
//           subtitle: Text('Press "Start Locate" to begin'),
//         ),
//       );
//     }

//     final String subtitleText = _signalStrength == null
//         ? 'Searching...'
//         : 'Signal Strength: $_signalStrength dBm';

//     final TextStyle subtitleStyle = _signalStrength == null
//         ? const TextStyle(color: Colors.orange)
//         : TextStyle(
//             fontWeight: FontWeight.w600, color: getBarColor(activeLevel, 3));

//     return Card(
//       margin: const EdgeInsets.all(8),
//       child: ListTile(
//         leading: SizedBox(
//           width: 32,
//           height: 32,
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: List.generate(3, (i) {
//               final int level = i + 1;
//               return Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 1.5),
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 300),
//                   width: 7,
//                   height: 10.0 + 7.0 * level,
//                   decoration: BoxDecoration(
//                     color: getBarColor(level, activeLevel),
//                     borderRadius: BorderRadius.circular(2),
//                   ),
//                 ),
//               );
//             }),
//           ),
//         ),
//         title: const Text('Location Signal Strength'),
//         subtitle: Text(subtitleText, style: subtitleStyle),
//       ),
//     );
//   }
// }
// lib/ui/screens/tag_detail_screen.dart
// lib/ui/screens/tag_detail_screen.dart
// lib/ui/screens/tag_detail_screen.dart
// lib/ui/screens/tag_detail_screen.dartimport 'dart:async';
import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

class TagDetailScreen extends StatefulWidget {
  final TagItem tagItem;
  final String userMemoryHex;
  const TagDetailScreen({
    Key? key,
    required this.tagItem,
    required this.userMemoryHex,
  }) : super(key: key);

  @override
  State<TagDetailScreen> createState() => _TagDetailScreenState();
}

/// ATA sınıf isimleri (14 => Life Vests vs.)
const Map<int, String> kAtaClassNames = {
  0: 'Other',
  1: 'Item (general; not 8–63)',
  2: 'Carton',
  6: 'Pallet',
  8: 'Seat Cushions',
  9: 'Seat Covers',
  10: 'Seat Belts / Belt Ext.',
  11: 'Galley & Service Equip.',
  12: 'Galley Ovens',
  13: 'Aircraft Security Items',
  14: 'Life Vests',
  15: 'Oxygen Generators',
  16: 'Engine & Engine Components',
  17: 'Avionics',
  18: 'Experimental Equip.',
  19: 'Other Emergency Equipment',
  20: 'Other Rotables',
  21: 'Other Repairables',
  22: 'Other Cabin Interior',
  23: 'Other Repair (structural)',
  24: 'Seat & Components',
  25: 'IFE & related',
  56: 'Location Identifier',
  57: 'Documentation',
  58: 'Tools',
  59: 'Ground Support Equipment',
  60: 'Other Non-Flyable Equipment',
};

class _TagDetailScreenState extends State<TagDetailScreen> {
  // Locate / ses
  bool _isLocating = false;
  bool _locatingBusy = false;
  bool _soundOn = false;

  // USER memory auto read
  bool _autoFetch = true;
  bool _reading = false;
  Timer? _umTimer;
  String _userHex = "";
  static const _umPoll = Duration(milliseconds: 600);

  // Location stream + adaptif bip
  static const EventChannel _locationStatusChannel =
      EventChannel('LocationStatus');
  StreamSubscription? _locSub;
  Timer? _beepTimer;
  Duration _currentPeriod = const Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _userHex = widget.userMemoryHex;
    if (_userHex.isEmpty) {
      _startAutoUserRead();
    } else {
      _decodeAndVerifyUserMemory(widget.tagItem.partNumber, _userHex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      log('DETAIL — PN:${widget.tagItem.partNumber} SN:${widget.tagItem.serialNumber} CAGE:${widget.tagItem.cage}');
    });
  }

  @override
  void dispose() {
    _umTimer?.cancel();
    _unsubscribeLocate();
    _stopBeepTimer();
    super.dispose();
  }

  // ---------------- USER AUTO READ ----------------
  void _startAutoUserRead() {
    _umTimer?.cancel();
    if (!_autoFetch) return;
    _umTimer = Timer.periodic(_umPoll, (_) => _tryReadUser());
  }

  Future<void> _tryReadUser({int attempt = 1}) async {
    if (_reading) return;
    _reading = true;
    try {
      final Map<String, dynamic>? fields =
          await RfidC72Plugin.readUserFieldsForEpc(widget.tagItem.rawEpc);

      if (fields != null && fields.isNotEmpty) {
        final String serFromUser = (fields['SER'] ?? '').toString().trim();
        final String mfr =
            (fields['MFR'] ?? '').toString().trim().toUpperCase();
        final String rawHex = fields['rawHex'] ?? '';
        final String rawText = fields['rawText'] ?? '';

        final String expectedSer = widget.tagItem.serialNumber.trim();
        final String expectedCage = widget.tagItem.cage.trim().toUpperCase();
        final String epcSerDigits = expectedSer.replaceAll(RegExp(r'\D'), '');
        final String userSerDigits = serFromUser.replaceAll(RegExp(r'\D'), '');
        final bool serMatch = userSerDigits.isNotEmpty &&
            (epcSerDigits.endsWith(userSerDigits) ||
                userSerDigits.endsWith(epcSerDigits) ||
                epcSerDigits == userSerDigits);
        final bool mfrMatch =
            (mfr.isEmpty || expectedCage.isEmpty) || (mfr == expectedCage);

        log('DETAIL USER fields (try $attempt) => SER=$serFromUser rawText="$rawText" serMatch=$serMatch mfrMatch=$mfrMatch');

        if (serMatch && mfrMatch) {
          if (!mounted) return;
          setState(() {
            _userHex = rawHex;
            _autoFetch = false; // Found and verified -> stop polling
            // Persist back to list item so it stays green on return
            widget.tagItem.userHex = rawHex;
            widget.tagItem.userRead = true;
          });
          _umTimer?.cancel();
          return;
        } else if (attempt < 3) {
          await Future.delayed(const Duration(milliseconds: 200));
          _tryReadUser(attempt: attempt + 1);
        } else {
          if (!mounted) return;
          setState(() {
            _userHex = rawHex;
            _autoFetch = false;
          });
          _umTimer?.cancel();
        }
      } else if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 200));
        _tryReadUser(attempt: attempt + 1);
      } else {
        if (!mounted) return;
        setState(() {
          _userHex = '';
          _autoFetch = false;
        });
        _umTimer?.cancel();
      }
    } catch (e) {
      log('Error reading user fields: $e');
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 200));
        _tryReadUser(attempt: attempt + 1);
      } else {
        if (!mounted) return;
        setState(() {
          _userHex = '';
          _autoFetch = false;
        });
        _umTimer?.cancel();
      }
    } finally {
      _reading = false;
    }
  }

  void _decodeAndVerifyUserMemory(String epcPartNumber, String userHex) async {
    final Map<String, dynamic> decoded = decodeUserMemory(userHex);
    final String serFromUser = (decoded['SER'] ?? '').toString().trim();
    final String mfr = (decoded['MFR'] ?? '').toString().trim().toUpperCase();
    final String expectedSer = widget.tagItem.serialNumber.trim();
    final String expectedCage = widget.tagItem.cage.trim().toUpperCase();
    final String epcSerDigits = expectedSer.replaceAll(RegExp(r'\D'), '');
    final String userSerDigits = serFromUser.replaceAll(RegExp(r'\D'), '');
    final bool serMatch = userSerDigits.isNotEmpty &&
        (epcSerDigits.endsWith(userSerDigits) ||
            userSerDigits.endsWith(epcSerDigits) ||
            epcSerDigits == userSerDigits);
    final bool mfrMatch =
        (mfr.isEmpty || expectedCage.isEmpty) || (mfr == expectedCage);

    if (serMatch && mfrMatch) {
      setState(() {
        _userHex = userHex;
        widget.tagItem.userHex = userHex;
        widget.tagItem.userRead = true;
      });
    } else {
      _startAutoUserRead();
    }
  }

  // ---------------- LOCATE + SOUND ----------------
  Future<void> _toggleLocate() async {
    if (_locatingBusy) return;
    setState(() => _locatingBusy = true);
    try {
      if (!_isLocating) {
        final ok = await RfidC72Plugin.startLocation(
          label: widget.tagItem.rawEpc,
          bank: 1,
          ptr: 32,
        );
        if (!mounted) return;
        if (ok == true) {
          setState(() => _isLocating = true);
          _subscribeLocate();
        }
      } else {
        final ok = await RfidC72Plugin.stopLocation();
        if (!mounted) return;
        if (ok == true) {
          setState(() => _isLocating = false);
          _unsubscribeLocate();
          _stopBeepTimer();
        }
      }
    } finally {
      if (mounted) setState(() => _locatingBusy = false);
    }
  }

  void _subscribeLocate() {
    _locSub ??= _locationStatusChannel.receiveBroadcastStream().listen((event) {
      final int? s = event is int ? event : int.tryParse(event.toString());
      _rescheduleForSignal(s);
    }, onError: (_) {
      _rescheduleForSignal(null);
    });
    _kickBeepIfNeeded();
  }

  void _unsubscribeLocate() {
    _locSub?.cancel();
    _locSub = null;
  }

  Duration _periodFor(int? s) {
    // 0→100 arttıkça periyot 900ms→150ms lineer kısalsın
    if (s == null) return const Duration(milliseconds: 900);
    final v = s.clamp(0, 100);
    const minMs = 150, maxMs = 900;
    final ms = (maxMs - ((maxMs - minMs) * v / 100)).round();
    return Duration(milliseconds: ms);
  }

  void _rescheduleForSignal(int? s) {
    final next = _periodFor(s);
    if (next.inMilliseconds != _currentPeriod.inMilliseconds) {
      _currentPeriod = next;
      _restartBeepTimer();
    }
  }

  void _kickBeepIfNeeded() {
    if (!_isLocating || !_soundOn) {
      _stopBeepTimer();
      return;
    }
    _restartBeepTimer();
  }

  void _restartBeepTimer() {
    _stopBeepTimer();
    _beepTimer = Timer.periodic(_currentPeriod, (_) async {
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    });
  }

  void _stopBeepTimer() {
    _beepTimer?.cancel();
    _beepTimer = null;
  }

  // ----------------- UI HELPERS -----------------
  Map<String, String> _parsePayloadFields(String text) {
    final Map<String, String> fields = {};
    for (final part in text.split('*')) {
      final p = part.trim();
      if (p.isEmpty) continue;
      final sp = p.indexOf(' ');
      if (sp <= 0) continue;
      final key = p.substring(0, sp).trim();
      final val = p.substring(sp + 1).trim();
      fields[key] = val;
    }
    return fields;
  }

  String _formatDmf(String v) {
    // If already contains non-digits (e.g., slashes), keep as-is
    if (RegExp(r'[^0-9]').hasMatch(v)) return v;
    // YYYYMMDD
    final ymd = RegExp(r'^(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])$');
    if (ymd.hasMatch(v)) {
      return '${v.substring(0, 4)}/${v.substring(4, 6)}/${v.substring(6, 8)}';
    }
    // DDMMYYYY
    final dmy = RegExp(r'^(0[1-9]|[12]\d|3[01])(0[1-9]|1[0-2])(19|20)\d{2}$');
    if (dmy.hasMatch(v)) {
      return '${v.substring(0, 2)}/${v.substring(2, 4)}/${v.substring(4, 8)}';
    }
    return v;
  }

  Widget _payloadBox(String text) {
    final f = _parsePayloadFields(text);
    final List<Widget> lines = [];
    void add(String labelKey, String uiLabel) {
      final v = f[labelKey];
      if (v == null || v.isEmpty) return;
      final shown = labelKey == 'DMF' ? _formatDmf(v) : v;
      lines.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(uiLabel,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: Text(shown,
                  style: const TextStyle(fontSize: 14, height: 1.25)),
            ),
          ],
        ),
      ));
    }

    add('MFR', 'Manufacturer');
    add('PDT', 'Item Description');
    add('PNR', 'Part Number');
    add('SER', 'Serial Number');
    add('DMF', 'Manufacture Date');
    add('UIC', 'UIC');

    if (lines.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines,
      ),
    );
  }

  Widget _chip(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Future<void> _copyAll(String what, String label) async {
    await Clipboard.setData(ClipboardData(text: what));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  /// Uzun basınca TAM METNİ kopyalar. `previewMaxLines` verilirse ekranda kısaltır.
  Widget _longPressCopyBox(String label, String fullText,
      {int? previewMaxLines}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        GestureDetector(
          onLongPress: () => _copyAll(fullText, label),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              fullText.isEmpty ? '-' : fullText,
              maxLines: previewMaxLines, // null ise sınırsız
              overflow: previewMaxLines != null
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: const TextStyle(height: 1.25),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final decodedUser = decodeUserMemory(_userHex);
    final epcDecoded = decodeEpc(widget.tagItem.rawEpc);
    final epcFilter = epcDecoded.filterValue;
    final epcFilterName = kAtaClassNames[epcFilter];

    final payloadText = decodedUser['payloadText']?.toString() ?? '';
    final epcText = widget.tagItem.rawEpc;
    final userText = _userHex;

    return Scaffold(
      appBar: commonAppBar(
        context,
        'RFID Tag Details',
        showBack: true,
        onBack: () {
          Navigator.pop(context, true); // indicate possible updates
        },
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              _chip('PN', widget.tagItem.partNumber),
              const SizedBox(width: 12),
              _chip('SN', widget.tagItem.serialNumber),
            ],
          ),
          const SizedBox(height: 16),

          // EPC Payload (Filter + Manufacturer)
          Text('EPC Payload',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Filter:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700)),
                    const SizedBox(width: 6),
                    Text(
                      epcFilterName == null
                          ? '$epcFilter'
                          : '$epcFilter — $epcFilterName',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Manufacturer:',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade700)),
                    const SizedBox(width: 6),
                    Text(widget.tagItem.cage,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          if (payloadText.isNotEmpty) ...[
            Text('User Memory Payload',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _payloadBox(payloadText),
          ],

          const SizedBox(height: 16),
          _longPressCopyBox('EPC (Hex)', epcText),

          const SizedBox(height: 16),
          // Ekranda 2 satır, uzun basınca TAMAMINI kopyalar
          _longPressCopyBox('User Memory (Hex)', userText, previewMaxLines: 2),

          if (decodedUser.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              "Header: w0=${decodedUser['w0']}  w1=${decodedUser['w1']}  w2=${decodedUser['w2']}  w3=${decodedUser['w3']}",
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],

          const SizedBox(height: 20),
          // Ses anahtarı
          SwitchListTile(
            title: const Text('Sound while locating'),
            subtitle: Text(_soundOn ? 'On' : 'Off'),
            value: _soundOn,
            onChanged: (v) {
              setState(() => _soundOn = v);
              _kickBeepIfNeeded();
            },
          ),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _locatingBusy ? null : _toggleLocate,
              icon: _locatingBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(_isLocating ? Icons.stop : Icons.podcasts),
              label: Text(_isLocating ? 'Stop Searching' : 'Find Tag'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLocating ? Colors.red : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          LocationStatusWidget(isLocating: _isLocating),
        ],
      ),
    );
  }
}

/// Basit sinyal göstergesi — EventChannel('LocationStatus') ile 0..100 benzeri bir değer bekler
class LocationStatusWidget extends StatefulWidget {
  final bool isLocating;
  const LocationStatusWidget({super.key, required this.isLocating});

  @override
  State<LocationStatusWidget> createState() => _LocationStatusWidgetState();
}

class _LocationStatusWidgetState extends State<LocationStatusWidget> {
  static const EventChannel _locationStatusChannel =
      EventChannel('LocationStatus');
  StreamSubscription? _locationSub;
  int? _signalStrength;

  void _subscribe() {
    _locationSub ??= _locationStatusChannel.receiveBroadcastStream().listen(
      (event) {
        setState(() {
          _signalStrength =
              event is int ? event : int.tryParse(event.toString());
        });
      },
      onError: (_) => setState(() => _signalStrength = null),
    );
  }

  void _unsubscribe() {
    _locationSub?.cancel();
    _locationSub = null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isLocating) _subscribe();
  }

  @override
  void didUpdateWidget(covariant LocationStatusWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLocating && !oldWidget.isLocating) {
      _signalStrength = null;
      _subscribe();
    } else if (!widget.isLocating && oldWidget.isLocating) {
      _unsubscribe();
      _signalStrength = null;
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  int getBarLevel(int? v) {
    if (v == null) return 0;
    if (v >= 70) return 3;
    if (v >= 40) return 2;
    if (v > 0) return 1;
    return 0;
  }

  Color getBarColor(int level, int activeLevel) {
    if (level > activeLevel) return Colors.grey.shade300;
    switch (level) {
      case 1:
        return Colors.green.shade900;
      case 2:
        return Colors.green.shade600;
      case 3:
        return Colors.green.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int activeLevel = getBarLevel(_signalStrength);

    if (!widget.isLocating) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: ListTile(
          title: Text('Tag search not started yet'),
          subtitle: Text('Press "Start Locate" to begin'),
        ),
      );
    }

    final String subtitleText = _signalStrength == null
        ? 'Searching...'
        : 'Signal Strength: $_signalStrength';

    final TextStyle subtitleStyle = _signalStrength == null
        ? const TextStyle(color: Colors.orange)
        : TextStyle(
            fontWeight: FontWeight.w600, color: getBarColor(activeLevel, 3));

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final int level = i + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 7,
                  height: 10.0 + 7.0 * level,
                  decoration: BoxDecoration(
                    color: getBarColor(level, activeLevel),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        title: const Text('Location Signal Strength'),
        subtitle: Text(subtitleText, style: subtitleStyle),
      ),
    );
  }
}
