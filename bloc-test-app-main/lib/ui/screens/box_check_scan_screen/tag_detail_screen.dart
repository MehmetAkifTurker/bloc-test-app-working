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
    super.key,
    required this.tagItem,
    required this.userMemoryHex,
  });

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

const Map<int, String> kAtaTagTypeNames = {
  0x0000: 'Multi-Record',
  0x0001: 'Dual-Record',
  0x0002: 'Single Birth Record',
  0x000A: 'Single Utility Record',
};

const List<String> kAtaUserFieldOrder = [
  'MFR',
  'CAG',
  'SPL',
  'SER',
  'SEQ',
  'UCN',
  'PNR',
  'PNO',
  'UIC',
  'DMF',
  'EXP',
  'PDT',
  'ESD',
  'LLE',
  'ICC',
  'LOT',
  'LTN',
  'CNT',
  'WGT',
  'UNT',
  'HAZ',
  'ECC',
  'SWI',
  'TDN',
  'NSN',
  'FAB',
  'DOH',
  'DNH',
  'OVD',
  'OMM',
];

const Map<String, String> kAtaUserFieldLabels = {
  'MFR': 'Manufacturer',
  'CAG': 'CAGE Code',
  'SPL': 'Supplier Code',
  'SER': 'Serial Number',
  'SEQ': 'Serial Sequence',
  'UCN': 'Unique Component Number',
  'PNR': 'Current Part Number',
  'PNO': 'Original Part Number',
  'UIC': 'UID Construct Number',
  'DMF': 'Manufacture Date',
  'EXP': 'Expiration Date',
  'PDT': 'Part Description',
  'ESD': 'ESD Indicator',
  'LLE': 'Life Limited Indicator',
  'ICC': 'Commodity Code',
  'LOT': 'Lot Number',
  'LTN': 'Lot Number',
  'CNT': 'Country of Manufacture',
  'WGT': 'Original Weight',
  'UNT': 'Unit of Measure',
  'HAZ': 'Hazardous Material Code',
  'ECC': 'Export Control Classification',
  'SWI': 'Software Indicator',
  'TDN': 'Certificate Tracking Number',
  'NSN': 'NATO Stock Number',
  'FAB': 'Fabricator',
  'DOH': 'Last Hydrostatic Test',
  'DNH': 'Next Hydrostatic Test',
  'OVD': 'Last Overhaul Date',
  'OMM': 'Original Equipment Manufacturer',
};

const Set<String> _kDateKeys = {'DMF', 'EXP', 'DOH', 'DNH', 'OVD'};

// ==================== THEME CONSTANTS ====================
// Turkish Airlines Brand Colors
const Color _brandNavy = Color(0xFF003B5C);
const Color _textPrimary = Color(0xFF1A1A1A);
const Color _textSecondary = Color(0xFF666666);
const Color _bgLight = Color(0xFFF8F9FA);
const Color _borderLight = Color(0xFFE0E0E0);

// Text Styles
const TextStyle _sectionTitleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: _brandNavy,
  letterSpacing: 0.3,
);

const TextStyle _cardTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: _brandNavy,
);

const TextStyle _labelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: _textSecondary,
);

const TextStyle _valueStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: _textPrimary,
  height: 1.3,
);

const TextStyle _chipTitleStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  color: _textSecondary,
  letterSpacing: 0.5,
);

const TextStyle _chipValueStyle = TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  color: _brandNavy,
);

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
  int? _latestSignal;

  @override
  void initState() {
    super.initState();
    _userHex = widget.userMemoryHex;

    // Always try to read full 128 words using TID filter for complete data
    // SDK inventory only returns ~61 words, but Lifecycle records may start at word 74+
    _fetchFullUserMemory();
  }
  
  Future<void> _fetchFullUserMemory() async {
    final epc = widget.tagItem.rawEpc;
    final tid = widget.tagItem.tid;
    
    // Defensive substring - avoid RangeError for short/truncated EPCs
    final epcPreview = epc.length > 8 ? epc.substring(0, 8) : epc;
    log('DETAIL: Fetching full 128-word USER memory via EPC filter: $epcPreview...');
    try {
      // Try EPC filter first (unique per tag, avoids TID duplicate issues)
      String? fullHex = await RfidC72Plugin.readUserMemoryForEpcFull(epc);
      
      // If EPC filter fails and we have TID, try TID filter as fallback
      if ((fullHex == null || fullHex.length <= _userHex.length) && 
          tid != null && tid.isNotEmpty && tid.length >= 8) {
        final tidPreview = tid.length > 8 ? tid.substring(0, 8) : tid;
        log('DETAIL: EPC filter failed, trying TID filter: $tidPreview...');
        fullHex = await RfidC72Plugin.readUserMemoryForTid(tid);
      }
      
      // Early exit if widget disposed during async operations
      if (!mounted) return;
      
      if (fullHex != null && fullHex.length > _userHex.length) {
        final wordsRead = fullHex.length ~/ 4;
        log('DETAIL: Got full USER memory: $wordsRead words (was ${_userHex.length ~/ 4})');
        final validHex = fullHex; // Capture non-null value
        // Re-check mounted immediately before setState to prevent crash
        if (!mounted) return;
        setState(() {
          _userHex = validHex;
          _autoFetch = false;
          widget.tagItem.userHex = validHex;
          widget.tagItem.userRead = true;
        });
    } else {
        log('DETAIL: Full read returned same or less data, keeping inventory data');
      }
    } catch (e) {
      log('DETAIL: Error fetching full USER memory: $e');
    }
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
      log('DETAIL: Attempting to read USER memory for EPC: ${widget.tagItem.rawEpc} (attempt $attempt)');
      final String? rawHex =
          await RfidC72Plugin.readUserMemoryForEpc(widget.tagItem.rawEpc);

      if (!mounted) return;
      if (rawHex != null && rawHex.length >= 16) {
        setState(() {
          _userHex = rawHex;
          _autoFetch = false; // Found -> stop polling
          // Persist back to list item so it stays green on return
          widget.tagItem.userHex = rawHex;
          widget.tagItem.userRead = true;
        });
        _umTimer?.cancel();
        log('DETAIL: USER read success for EPC: ${widget.tagItem.rawEpc}, data length: ${rawHex.length}');
        return;
      } else if (attempt < 3) {
        log('DETAIL: USER read attempt $attempt failed, retrying...');
        await Future.delayed(const Duration(milliseconds: 500));
        _tryReadUser(attempt: attempt + 1);
      } else {
        if (!mounted) return;
        setState(() {
          _userHex = '';
          _autoFetch = false;
        });
        _umTimer?.cancel();
        log('DETAIL: USER read failed after $attempt attempts for EPC: ${widget.tagItem.rawEpc}');
      }
    } catch (e) {
      log('DETAIL: Error reading user memory for EPC ${widget.tagItem.rawEpc}: $e');
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 500));
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


  // ---------------- LOCATE + SOUND ----------------
  Future<void> _toggleLocate() async {
    if (_locatingBusy) return;
    setState(() => _locatingBusy = true);
    try {
      if (!_isLocating) {
        final epcToFind = widget.tagItem.rawEpc;
        log('DETAIL Starting location for EPC: $epcToFind (PN: ${widget.tagItem.partNumber}, SN: ${widget.tagItem.serialNumber})');
        final ok = await RfidC72Plugin.startLocation(
          label: epcToFind,
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
    if (_locSub != null) return; // Already subscribed
    setState(() => _latestSignal = null);
    _locSub = _locationStatusChannel.receiveBroadcastStream().listen((event) {
      final int? s = event is int ? event : int.tryParse(event.toString());
      _rescheduleForSignal(s);
    }, onError: (_) {
      _rescheduleForSignal(null);
    });
    _kickBeepIfNeeded();
  }

  void _unsubscribeLocate() {
    if (_locSub == null) return; // Already unsubscribed
    try {
      _locSub!.cancel();
    } catch (e) {
      // Ignore cancellation errors
      log('EventChannel cancel error: $e');
    }
    _locSub = null;
    if (mounted) {
      setState(() => _latestSignal = null);
    } else {
      _latestSignal = null;
    }
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
    final bool periodChanged =
        next.inMilliseconds != _currentPeriod.inMilliseconds;
    if (periodChanged) {
      _currentPeriod = next;
      _restartBeepTimer();
    }
    if (_latestSignal != s) {
      if (mounted) {
        setState(() => _latestSignal = s);
      } else {
        _latestSignal = s;
      }
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
        await RfidC72Plugin.playSound;
      } catch (_) {}
    });
  }

  void _stopBeepTimer() {
    _beepTimer?.cancel();
    _beepTimer = null;
  }

  // ----------------- UI HELPERS -----------------
  Map<String, String> _parsePayloadFields(String text) {
    final fields = <String, String>{};
    final sanitized = text.replaceAll('\n', ' ').trim();
    final reg = RegExp(r'([A-Z0-9]{3,5})\s+([^*]+)');
    for (final match in reg.allMatches(sanitized)) {
      final key = match.group(1)?.trim().toUpperCase();
      final value = match.group(2)?.trim();
      if (key == null || key.isEmpty || value == null || value.isEmpty) {
        continue;
      }
      fields[key] = value;
    }
    return fields;
  }

  String _formatDateString(String v) {
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

  String _formatAtaValue(String key, String value) {
    if (_kDateKeys.contains(key)) return _formatDateString(value);
    return value;
  }

  Widget _payloadBox(Map<String, String> providedFields, String text) {
    final Map<String, String> f =
        providedFields.isNotEmpty ? providedFields : _parsePayloadFields(text);
    final List<Widget> lines = [];
    final Set<String> seen = {};

    void add(String key) {
      final v = f[key]?.trim();
      if (v == null || v.isEmpty) return;
      if (!seen.add(key)) return;
      final shown = _formatAtaValue(key, v);
      final uiLabel = kAtaUserFieldLabels[key] ?? key;
      lines.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140,
              child: Text(uiLabel, style: _labelStyle),
            ),
            Expanded(
              child: Text(shown, style: _valueStyle),
            ),
          ],
        ),
      ));
    }

    for (final key in kAtaUserFieldOrder) {
      add(key);
    }

    final extraKeys = f.keys.where((key) => !seen.contains(key)).toList()
      ..sort();
    for (final key in extraKeys) {
      add(key);
    }

    if (lines.isEmpty) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _bgLight,
        borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderLight),
        ),
        child: Text(text.isEmpty ? '-' : text, style: _valueStyle),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
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
          color: _bgLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(), style: _chipTitleStyle),
            const SizedBox(height: 6),
            Text(value, style: _chipValueStyle),
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
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          SizedBox(
            width: 110,
            child: Text('$label:', style: _labelStyle),
          ),
          Expanded(
            child: Text(value, style: _valueStyle.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _longPressCopyBox(String label, String fullText,
      {int? previewMaxLines}) {
    // Determine icon based on label
    IconData icon = Icons.memory;
    Color iconColor = _brandNavy;
    if (label.contains('EPC')) {
      icon = Icons.sell_outlined;
      iconColor = Colors.purple.shade700;
    } else if (label.contains('User')) {
      icon = Icons.storage;
      iconColor = Colors.teal.shade700;
    }

    return GestureDetector(
          onLongPress: () => _copyAll(fullText, label),
          behavior: HitTestBehavior.opaque,
          child: Container(
        padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
          color: _bgLight,
              borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: _cardTitleStyle.copyWith(color: iconColor)),
                ),
                const Icon(Icons.copy, size: 14, color: _textSecondary),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              fullText.isEmpty ? '-' : fullText,
              maxLines: previewMaxLines,
              overflow: previewMaxLines != null
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
              style: _valueStyle.copyWith(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
          ),
        ),
      ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decodedUser = decodeUserMemory(_userHex);
    final epcDecoded = decodeEpc(widget.tagItem.rawEpc);
    final epcFilter = epcDecoded.filterValue;
    final epcFilterName = kAtaClassNames[epcFilter];
    final filterLabel =
        epcFilterName == null ? '$epcFilter' : '$epcFilter — $epcFilterName';
    final manufacturerFromEpc = epcDecoded.cage.trim().isEmpty
        ? widget.tagItem.cage.trim()
        : epcDecoded.cage.trim();
    final partNumberFromEpc = epcDecoded.partNumber.isNotEmpty
        ? epcDecoded.partNumber
        : widget.tagItem.partNumber;
    final serialNumberFromEpc = epcDecoded.serialNumber.isNotEmpty
        ? epcDecoded.serialNumber
        : widget.tagItem.serialNumber;

    final payloadText = decodedUser['payloadText']?.toString() ?? '';
    final Map<String, String> decodedFields = {};
    final rawFields = decodedUser['fields'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries) {
        final key = entry.key?.toString().toUpperCase();
        final value = entry.value?.toString().trim();
        if (key != null &&
            key.isNotEmpty &&
            value != null &&
            value.isNotEmpty) {
          decodedFields[key] = value;
        }
      }
    }

    final hasPayload = payloadText.isNotEmpty || decodedFields.isNotEmpty;
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
              _chip('PN', partNumberFromEpc),
              const SizedBox(width: 12),
              _chip('SN', serialNumberFromEpc),
            ],
          ),
          const SizedBox(height: 16),

          // EPC Payload Card (like Birth/Lifecycle)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _bgLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2, size: 20, color: _brandNavy),
                    SizedBox(width: 8),
                    Text('EPC Payload', style: _cardTitleStyle),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('Filter', filterLabel),
                const SizedBox(height: 8),
                _buildInfoRow('Manufacturer', manufacturerFromEpc),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // For Dual/Multi-Record tags, show records separately
          if (_isDualRecordTag(decodedUser) ||
              _hasMultipleRecords(decodedUser)) ...[
            _buildRecordSections(decodedUser),
          const SizedBox(height: 16),
          ] else if (hasPayload) ...[
            // Single record - show combined payload
            const Text('User Memory Payload', style: _sectionTitleStyle),
            const SizedBox(height: 8),
            _payloadBox(decodedFields, payloadText),
            const SizedBox(height: 16),
          ],
          _longPressCopyBox('EPC (Hex)', epcText),

          const SizedBox(height: 16),
          // Ekranda 2 satır, uzun basınca TAMAMINI kopyalar
          _longPressCopyBox('User Memory (Hex)', userText, previewMaxLines: 2),

          // ToC Header (commented for now - can be added back if needed)
          // if (decodedUser.isNotEmpty) ...[
          //   const SizedBox(height: 8),
          //   Container(
          //     padding: const EdgeInsets.all(12),
          //     decoration: BoxDecoration(
          //       color: Colors.grey.shade50,
          //       borderRadius: BorderRadius.circular(8),
          //       border: Border.all(color: Colors.grey.shade200),
          //     ),
          //     child: Row(
          //       children: [
          //         Icon(Icons.info_outline, size: 16, color: _textSecondary),
          //         const SizedBox(width: 8),
          //         Expanded(
          //           child: Text(
          //             "ToC Header: w0=${decodedUser['w0']}  w1=${decodedUser['w1']}  w2=${decodedUser['w2']}  w3=${decodedUser['w3']}",
          //             style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: _textSecondary, fontWeight: FontWeight.w500),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],

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
          LocationStatusWidget(
            isLocating: _isLocating,
            signalStrength: _latestSignal,
          ),

          // Update Lifecycle button (for Dual-Record tags)
          if (_isDualRecordTag(decodedUser)) ...[
            const SizedBox(height: 20),
            Divider(color: Colors.grey.shade400, thickness: 1),
            const SizedBox(height: 16),
            const Text('Lifecycle Management', style: _sectionTitleStyle),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => _showUpdateLifecycleDialog(context),
                icon: const Icon(Icons.edit_note_rounded, size: 22),
                label: const Text(
                  'Update Lifecycle Record',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003B5C),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isDualRecordTag(Map<String, dynamic> decodedUser) {
    final tocHeader = decodedUser['tocHeader'];
    if (tocHeader == null) return false;

    // Check tag type
    final tagType = tocHeader['ataTagType'];
    if (tagType == 0x0001) return true; // Dual-Record tag type

    // Fallback: check for record descriptors and lifecycle
    final rdWords = tocHeader['recordDescriptorWords'];
    if (rdWords == null || rdWords < 2) return false;

    // If has Full ToC with 2+ RDs, likely has lifecycle (even if empty)
    final recordDescriptors = decodedUser['recordDescriptors'];
    if (recordDescriptors != null && recordDescriptors is List) {
      for (final rd in recordDescriptors) {
        if (rd is Map && rd['recordType'] == 0x04) {
          return true; // Has Lifecycle RD
        }
      }
    }

    return false;
  }

  bool _hasMultipleRecords(Map<String, dynamic> decodedUser) {
    final records = decodedUser['records'];
    return records != null && records is List && records.length > 1;
  }

  Widget _buildRecordSections(Map<String, dynamic> decodedUser) {
    final records = decodedUser['records'];
    if (records == null || records is! List || records.isEmpty) {
      return const SizedBox.shrink();
    }

    const brandNavy = Color(0xFF003B5C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < records.length; i++)
          if (records[i] is Map) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildRecordCard(records[i] as Map<String, dynamic>, brandNavy),
          ],
      ],
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record, Color brandColor) {
    final descriptor = record['descriptor'] as Map?;
    final recordType = descriptor?['recordType'] ?? 0;
    final recordTypeLabel = descriptor?['recordTypeLabel'] ?? 'Unknown';
    final payloadText = record['payloadText']?.toString() ?? '';
    final fields = record['fields'] as Map?;

    final Map<String, String> recordFields = {};
    if (fields != null) {
      for (final entry in fields.entries) {
        final key = entry.key?.toString().toUpperCase();
        var value = entry.value?.toString().trim();
        if (key != null &&
            key.isNotEmpty &&
            value != null &&
            value.isNotEmpty) {
          // Format date fields (YYYYMMDD → YYYY/MM/DD)
          if ((key == 'DMF' ||
                  key == 'EXP' ||
                  key == 'OVD' ||
                  key == 'DOH' ||
                  key == 'DNH') &&
              value.length == 8 &&
              RegExp(r'^\d{8}$').hasMatch(value)) {
            value =
                '${value.substring(0, 4)}/${value.substring(4, 6)}/${value.substring(6, 8)}';
          }
          recordFields[key] = value;
        }
      }
    }

    // Icon based on record type
    IconData recordIcon;
    Color iconColor;
    switch (recordType) {
      case 0x00: // Birth
        recordIcon = Icons.cake;
        iconColor = brandColor;
        break;
      case 0x04: // Lifecycle
        recordIcon = Icons.autorenew;
        iconColor = Colors.orange.shade700;
        break;
      case 0x01: // Current Data
        recordIcon = Icons.update;
        iconColor = Colors.green.shade700;
        break;
      case 0x03: // Part History
        recordIcon = Icons.history;
        iconColor = Colors.blue.shade700;
        break;
      default:
        recordIcon = Icons.description;
        iconColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(recordIcon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(recordTypeLabel,
                    style: _cardTitleStyle.copyWith(color: iconColor)),
              ),
            ],
          ),
          if (recordFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...recordFields.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text('${e.key}:', style: _labelStyle),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: _valueStyle.copyWith(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
          if (payloadText.isNotEmpty && recordFields.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payloadText,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showUpdateLifecycleDialog(BuildContext context) async {
    final pnrCtrl = TextEditingController();
    final pmlCtrl = TextEditingController();
    final tdnCtrl = TextEditingController();

    DateTime? selectedExpDate;
    DateTime? selectedOvhDate;

    const brandNavy = Color(0xFF003B5C);

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: brandNavy, width: 2),
              ),
              floatingLabelStyle: const TextStyle(color: brandNavy),
            ),
          ),
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandNavy.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: brandNavy, size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Update Lifecycle',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: brandNavy,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.blue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Updates rewritable Lifecycle data.\nBirth record remains locked.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: pnrCtrl,
                      decoration: InputDecoration(
                        labelText: 'Current Part Number (PNR)',
                        hintText: 'e.g., TA6950-02',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pmlCtrl,
                      decoration: InputDecoration(
                        labelText: 'Mod Level (PML)',
                        hintText: 'e.g., MOD-123',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedExpDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: brandNavy,
                                  onPrimary: Colors.white,
                                  surface: Colors.white,
                                  onSurface: Colors.black,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() => selectedExpDate = picked);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          controller: TextEditingController(
                            text: selectedExpDate == null
                                ? ''
                                : '${selectedExpDate!.year}/${selectedExpDate!.month.toString().padLeft(2, '0')}/${selectedExpDate!.day.toString().padLeft(2, '0')}',
                          ),
                          decoration: InputDecoration(
                            labelText: 'Expiration Date (EXP)',
                            hintText: 'YYYY/MM/DD',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                            suffixIcon: selectedExpDate != null
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () => setDialogState(
                                        () => selectedExpDate = null),
                                  )
                                : const Icon(Icons.calendar_today,
                                    size: 18, color: brandNavy),
                          ),
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: tdnCtrl,
                      decoration: InputDecoration(
                        labelText: 'Certificate Number (TDN)',
                        hintText: 'e.g., 8130-12345',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Cancel',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Update',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != true) return;

    // Perform update
    try {
      // Format dates as YYYYMMDD
      String? expDateFormatted;
      if (selectedExpDate != null) {
        expDateFormatted = '${selectedExpDate!.year.toString().padLeft(4, '0')}'
            '${selectedExpDate!.month.toString().padLeft(2, '0')}'
            '${selectedExpDate!.day.toString().padLeft(2, '0')}';
      }

      String? ovhDateFormatted;
      final ovh = selectedOvhDate;
      if (ovh != null) {
        ovhDateFormatted = '${ovh.year.toString().padLeft(4, '0')}'
            '${ovh.month.toString().padLeft(2, '0')}'
            '${ovh.day.toString().padLeft(2, '0')}';
      }

      final ok = await RfidC72Plugin.updateLifecycleRecord(
        epcHex: widget.tagItem.rawEpc,
        currentPartNumber: pnrCtrl.text.trim().isEmpty
            ? null
            : pnrCtrl.text.trim().toUpperCase(),
        partModLevel: pmlCtrl.text.trim().isEmpty
            ? null
            : pmlCtrl.text.trim().toUpperCase(),
        expirationDate: expDateFormatted,
        certificateNumber: tdnCtrl.text.trim().isEmpty
            ? null
            : tdnCtrl.text.trim().toUpperCase(),
        lastOverhaulDate: ovhDateFormatted,
      );

      if (!mounted) return;

      if (ok == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Lifecycle record updated successfully!')),
          );
        }
        // Re-read USER memory
        setState(() => _reading = true);
        final newUserHex =
            await RfidC72Plugin.readUserMemoryForEpc(widget.tagItem.rawEpc);
        if (newUserHex != null && newUserHex.isNotEmpty && mounted) {
          setState(() {
            _userHex = newUserHex;
            widget.tagItem.userHex = newUserHex;
          });
        }
        if (mounted) {
          setState(() => _reading = false);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lifecycle update failed!')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}

/// Basit sinyal göstergesi — değer üst widget tarafından sağlanır
class LocationStatusWidget extends StatelessWidget {
  final bool isLocating;
  final int? signalStrength;
  const LocationStatusWidget(
      {super.key, required this.isLocating, required this.signalStrength});

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
    final int activeLevel = getBarLevel(signalStrength);

    if (!isLocating) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: ListTile(
          title: Text('Tag search not started yet'),
          subtitle: Text('Press "Start Locate" to begin'),
        ),
      );
    }

    final String subtitleText = signalStrength == null
        ? 'Searching...'
        : 'Signal Strength: $signalStrength';

    final TextStyle subtitleStyle = signalStrength == null
        ? const TextStyle(color: Colors.orange)
        : TextStyle(
            fontWeight: FontWeight.w600, color: getBarColor(activeLevel, 3));

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
          child: _SignalBars(activeLevel: activeLevel),
        ),
        title: const Text('Location Signal Strength'),
        subtitle: Text(subtitleText, style: subtitleStyle),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int activeLevel;
  
  const _SignalBars({required this.activeLevel});
  
  Color _getBarColor(int level) {
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
    return Row(
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
              color: _getBarColor(level),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
    );
  }
}
