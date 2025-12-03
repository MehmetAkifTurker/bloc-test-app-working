// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:excel/excel.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/tag_detail_screen.dart';
// // import 'package:water_boiler_rfid_labeler/ui/router/bottom_navigation.dart'; // isterseniz açık bırakın

// class FilterOption {
//   final int id;
//   final String label;

//   const FilterOption(this.id, this.label);
// }

// const FilterOption kAtaAll = FilterOption(-999, 'All — show everything');

// const List<FilterOption> kAtaFilterOptions = [
//   FilterOption(0, 'All others'),
//   FilterOption(1, 'Item (general; not 8–63)'),
//   FilterOption(2, 'Carton'),
//   FilterOption(6, 'Pallet'),
//   FilterOption(8, 'Seat Cushions'),
//   FilterOption(9, 'Seat Covers'),
//   FilterOption(10, 'Seat Belts / Belt Ext.'),
//   FilterOption(11, 'Galley & Service Equip.'),
//   FilterOption(12, 'Galley Ovens'),
//   FilterOption(13, 'Aircraft Security Items'),
//   FilterOption(14, 'Life Vests'),
//   FilterOption(15, 'Oxygen Generators (not cylinders/bottles)'),
//   FilterOption(16, 'Engine & Engine Components'),
//   FilterOption(17, 'Avionics'),
//   FilterOption(18, 'Experimental (“flight test”) equip.'),
//   FilterOption(19, 'Other Emergency Equipment'),
//   FilterOption(20, 'Other Rotables'),
//   FilterOption(21, 'Other Repairables'),
//   FilterOption(22, 'Other Cabin Interior'),
//   FilterOption(23, 'Other Repair (e.g., structural)'),
//   FilterOption(24, 'Seat & Seat Components (excl. 8–10)'),
//   FilterOption(25, 'In-Flight Entertainment (IFE) & related'),
//   FilterOption(56, 'Location Identifier'),
//   FilterOption(57, 'Documentation'),
//   FilterOption(58, 'Tools'),
//   FilterOption(59, 'Ground Support Equipment'),
//   FilterOption(60, 'Other Non-Flyable Equipment'),
// ];

// class BoxCheckScanScreen extends StatelessWidget {
//   const BoxCheckScanScreen({Key? key}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: commonAppBar(context, 'TAG READER', showBack: true),
//       body: const _BoxCheckScanBody(),
//     );
//   }
// }

// class _BoxCheckScanBody extends StatefulWidget {
//   const _BoxCheckScanBody();

//   @override
//   State<_BoxCheckScanBody> createState() => _BoxCheckScanBodyState();
// }

// class _BoxCheckScanBodyState extends State<_BoxCheckScanBody> {
//   bool _isScanning = false;
//   bool _exportBusy = false;

//   int _umRoundRobinIndex = 0;
//   Timer? _scanTimer;

//   double _powerLevel = 5;
//   final double _minPower = 5;
//   final double _maxPower = 30;
//   final int _divisions = 25;

//   final List<TagItem> _tagItems = [];
//   final Set<String> _epcSet = <String>{};
//   final Map<String, DateTime> _lastSeen = {};
//   bool _scanTickBusy = false;

//   List<FilterOption> get _ataOptions => [kAtaAll, ...kAtaFilterOptions];

//   static const TextStyle _ddTextStyle = TextStyle(
//     fontSize: 16,
//     fontWeight: FontWeight.w600,
//     color: Colors.black87, // ✅ metin rengi sabit
//   );

//   static const double _controlHeight = 48.0; // buton & dropdown aynı yükseklik

// // Üst kontrollerin en fazla genişliği (butonlarla hizalı görünüm)
//   static const double _controlsMaxWidth = 360;

// // Liste görünümünde aynı anda en çok 5 satır görünsün (yaklaşık satır yüksekliği)
//   static const double _listRowApproxHeight = 60;
//   static const int _listMaxVisibleRows = 5;

//   // Sağ/sol padding 16 olduğu için ekranda kullanılabilir genişlik = width - 32
//   double _controlsWidth(BuildContext context) {
//     final screen = MediaQuery.of(context).size.width;
//     final usable = screen - 32;
//     return _controlsMaxWidth < usable ? _controlsMaxWidth : usable;
//   }

//   // --- ATA filter state ---
//   FilterOption? _selectedAta; // null => filtre yok

//   int? _ataClassOf(TagItem t) {
//     final hex = t.userHex;
//     if (hex == null || hex.length < 16) return null;
//     final d = decodeUserMemory(hex);
//     final v = d['ataClass'];
//     if (v is int) return v;
//     if (v is String) return int.tryParse(v);
//     return null;
//   }

//   /// Görüntülenecek liste (ATA class tam eşleşme)
//   List<TagItem> get _filteredItems {
//     final sel = _selectedAta;
//     if (sel == null || sel.id == kAtaAll.id)
//       return _tagItems; // ← tümünü göster
//     final code = sel.id;
//     return _tagItems.where((t) => _ataClassOf(t) == code).toList();
//   }

//   @override
//   void initState() {
//     super.initState();
//     _checkIfConnected();
//     _selectedAta = kAtaAll;
//   }

//   Future<void> _checkIfConnected() async {
//     log("Checking if RFID reader is already connected (BoxCheckScanScreen)...");
//     final bool? connected = await RfidC72Plugin.isConnected;
//     if (connected == true) {
//       log("Yes, RFID is connected in BoxCheckScanScreen");
//     } else {
//       log("RFID not connected.");
//     }
//   }

//   Future<void> _readTag() async {
//     try {
//       final String? raw = await RfidC72Plugin.readSingleTagEpc();
//       if (raw == null || raw.isEmpty) {
//         log("No tag found");
//         return;
//       }

//       final epcHex = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

//       // cooldown
//       final now = DateTime.now();
//       final last = _lastSeen[epcHex];
//       if (last != null && now.difference(last) < const Duration(seconds: 3)) {
//         log("Suppressed duplicate within cooldown: $epcHex");
//         return;
//       }
//       _lastSeen[epcHex] = now;

//       // unique
//       if (_epcSet.contains(epcHex)) {
//         log("Duplicate EPC ignored: $epcHex");
//         return;
//       }

//       // decode & add
//       final decoded = decodeEpc(epcHex);
//       setState(() {
//         _epcSet.add(epcHex);
//         _tagItems.insert(
//           0,
//           TagItem(
//             rawEpc: epcHex,
//             cage: decoded.cage,
//             partNumber: decoded.partNumber,
//             serialNumber: decoded.serialNumber,
//             userRead: false,
//           ),
//         );
//       });

//       // opportunistic user read
//       await _checkUserMemoryOnce(_tagItems.first);
//     } catch (e) {
//       log("Error reading tag: $e");
//     }
//   }

//   void _toggleScan() {
//     if (!_isScanning) {
//       _scanTimer =
//           Timer.periodic(const Duration(milliseconds: 400), (timer) async {
//         if (_scanTickBusy) return;
//         _scanTickBusy = true;
//         try {
//           await _readTag();
//           await _pollMissingUserMemoryDuringScan(maxPerTick: 2);
//         } finally {
//           _scanTickBusy = false;
//         }
//       });
//       setState(() => _isScanning = true);
//     } else {
//       _scanTimer?.cancel();
//       _scanTimer = null;
//       setState(() => _isScanning = false);
//     }
//   }

//   void _clearList() {
//     setState(() {
//       _tagItems.clear();
//       _epcSet.clear();
//       _lastSeen.clear();
//     });
//   }

//   /// EPC + USER verilerini Excel’e yazıp paylaş
//   Future<void> _shareExcelAnywhere() async {
//     if (_tagItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('List empty: no tags to export.')),
//       );
//       return;
//     }

//     final wasScanning = _isScanning;
//     if (wasScanning) _toggleScan();
//     setState(() => _exportBusy = true);

//     try {
//       final excel = Excel.createExcel();
//       final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
//       final sheet = excel.sheets[sheetName]!;

//       sheet.appendRow([
//         'No',
//         'PN',
//         'SN',
//         'Üretici (CAGE)',
//         'EPC (HEX)',
//         'USER HEX',
//         'w0',
//         'w1',
//         'w2',
//         'w3',
//         'ToC Major',
//         'ToC Minor',
//         'ATA Class',
//         'Tag Type',
//         'Payload Text',
//       ]);

//       int i = 1;
//       for (final t in _filteredItems) {
//         final userHex =
//             await RfidC72Plugin.readUserMemoryForEpc(t.rawEpc) ?? '';
//         final d = decodeUserMemory(userHex);
//         sheet.appendRow([
//           i++,
//           t.partNumber,
//           t.serialNumber,
//           t.cage,
//           t.rawEpc,
//           userHex,
//           d['w0'] ?? '',
//           d['w1'] ?? '',
//           d['w2'] ?? '',
//           d['w3'] ?? '',
//           d['tocMajor'] ?? '',
//           d['tocMinor'] ?? '',
//           d['ataClass'] ?? '',
//           d['tagType'] ?? '',
//           d['payloadText'] ?? '',
//         ]);
//       }

//       final bytes = excel.encode();
//       if (bytes == null) throw Exception('Excel encode null');

//       final dir = await getTemporaryDirectory();
//       final now = DateTime.now();
//       String two(int n) => n.toString().padLeft(2, '0');
//       final stamp =
//           '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

//       final fileName = 'RFID-READ-TAGS-$stamp.xlsx';
//       final file = File('${dir.path}/$fileName')..createSync(recursive: true);
//       await file.writeAsBytes(bytes, flush: true);

//       await Share.shareXFiles(
//         [
//           XFile(file.path,
//               name: fileName,
//               mimeType:
//                   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
//         ],
//         subject: 'RFID Export ($stamp)',
//         text: 'Ekte PN/SN/Üretici + EPC + USER içerikleri bulunmaktadır.',
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context)
//           .showSnackBar(SnackBar(content: Text('Export failed: $e')));
//     } finally {
//       if (wasScanning) _toggleScan();
//       if (mounted) setState(() => _exportBusy = false);
//     }
//   }

//   Future<void> _checkUserMemoryOnce(TagItem item) async {
//     if (item.userRead == true) return;
//     try {
//       final hex = await RfidC72Plugin.readUserMemoryForEpc(item.rawEpc);
//       if (!mounted) return;
//       if (hex != null && hex.length >= 16) {
//         setState(() {
//           item.userHex = hex;
//           item.userRead = true;
//         });
//       }
//     } catch (_) {}
//   }

//   Future<void> _pollMissingUserMemoryDuringScan({int maxPerTick = 2}) async {
//     if (!_isScanning || _tagItems.isEmpty) return;
//     int checked = 0;
//     final total = _tagItems.length;
//     while (checked < maxPerTick) {
//       _umRoundRobinIndex = (_umRoundRobinIndex + 1) % total;
//       final item = _tagItems[_umRoundRobinIndex];
//       if (!item.userRead) {
//         await _checkUserMemoryOnce(item);
//         checked++;
//       } else {
//         checked++;
//       }
//       if (!_isScanning) break;
//     }
//   }

//   static const _captionStyle = TextStyle(
//     fontSize: 13,
//     fontWeight: FontWeight.w600,
//     color: Colors.black54,
//   );

//   Widget _buildAtaFilterDropdown() {
//     final opts = _ataOptions;
//     final double vPad = (_controlHeight - 24) / 2; // 24 ≈ satır yüksekliği

//     return SizedBox(
//       height: _controlHeight, // butonlarla aynı
//       child: DropdownButtonFormField<FilterOption>(
//         value: _selectedAta ?? kAtaAll,
//         isDense: true,
//         isExpanded: true,
//         itemHeight: _controlHeight, // menü satır yüksekliği ≥ 48
//         menuMaxHeight: _controlHeight * 5 + 16, // ≈ 5 satır
//         decoration: InputDecoration(
//           labelText: 'ATA Class', // sadece labelText
//           floatingLabelBehavior: FloatingLabelBehavior.never,
//           contentPadding: EdgeInsets.symmetric(
//             horizontal: 12,
//             vertical: vPad, // kapalı görünüm yüksekliği
//           ),
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//         ),
//         items: opts.map((o) {
//           final label = o.id == kAtaAll.id ? o.label : '${o.id} — ${o.label}';
//           return DropdownMenuItem(
//             value: o,
//             child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
//           );
//         }).toList(),
//         onChanged: (v) => setState(() => _selectedAta = v),
//       ),
//     );
//   }

//   Widget _buildPowerSlider() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         // Başlığı küçült (yalnız dikey etki)
//         Text(
//           "Adjust Power Level => ${_powerLevel.toInt()}",
//           style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
//         ),
//         const SizedBox(height: 6),
//         SliderTheme(
//           data: SliderTheme.of(context).copyWith(
//             trackHeight: 2, // daha ince hat → dikey yer kazanır
//             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
//             overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
//           ),
//           child: Row(
//             children: [
//               SizedBox(
//                 width: 24,
//                 child: Text(_minPower.toInt().toString(),
//                     textAlign: TextAlign.center,
//                     style:
//                         const TextStyle(fontSize: 12, color: Colors.black54)),
//               ),
//               Expanded(
//                 child: Slider(
//                   value: _powerLevel,
//                   min: _minPower,
//                   max: _maxPower,
//                   divisions: _divisions,
//                   onChanged: (v) => setState(() => _powerLevel = v),
//                   onChangeEnd: (v) {
//                     RfidC72Plugin.setPowerLevel(v.toInt().toString());
//                     log("Power level set to ${v.toInt()}");
//                   },
//                 ),
//               ),
//               SizedBox(
//                 width: 24,
//                 child: Text(_maxPower.toInt().toString(),
//                     textAlign: TextAlign.center,
//                     style:
//                         const TextStyle(fontSize: 12, color: Colors.black54)),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildButtonRow() {
//     final dense = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
//     final denseText =
//         const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

//     final elevStyle = ElevatedButton.styleFrom(
//       padding: dense,
//       textStyle: denseText,
//       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       visualDensity: const VisualDensity(vertical: -2),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       // Renk: Start=yeşil, Stop=kırmızı
//       backgroundColor:
//           _isScanning ? Colors.red.shade600 : Colors.green.shade600,
//       foregroundColor: Colors.white,
//     );

//     final outStyle = OutlinedButton.styleFrom(
//       padding: dense,
//       textStyle: denseText,
//       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       visualDensity: const VisualDensity(vertical: -2),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//     );

//     return Row(
//       children: [
//         Expanded(
//           child: SizedBox(
//             height: _controlHeight, // 🔸 sabit yükseklik
//             child: ElevatedButton(
//               onPressed: _toggleScan,
//               style: elevStyle,
//               child: Text(_isScanning ? "Stop Scan" : "Start Scan"),
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: SizedBox(
//             height: _controlHeight, // 🔸 sabit yükseklik
//             child: OutlinedButton(
//               onPressed: _clearList,
//               style: outStyle,
//               child: const Text("Clear List"),
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildTagList() {
//     final items = _filteredItems;

//     // En fazla 5 satır kadar yükseklik
//     final maxListHeight = _listRowApproxHeight * _listMaxVisibleRows;

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
//           child: Text(
//             "Total Tags: ${items.length} / ${_tagItems.length}",
//             style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//           ),
//         ),
//         const SizedBox(height: 4),

//         // 🔸 5 satırı aşmayacak yükseklikte bir konteyner; fazlası scroll ile görülür
//         Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 16),
//           child: ConstrainedBox(
//             constraints: BoxConstraints(maxHeight: maxListHeight),
//             child: items.isEmpty
//                 ? const Center(child: Text("No tags read yet."))
//                 : ListView.separated(
//                     shrinkWrap: true,
//                     padding: EdgeInsets.zero,
//                     itemCount: items
//                         .length, // hepsini verir, ama yükseklik 5 satır kadar
//                     separatorBuilder: (_, __) =>
//                         const Divider(height: 1, thickness: 1),
//                     itemBuilder: (context, index) {
//                       final item = items[index];
//                       final bool ok = (item.userRead == true);

//                       return Container(
//                         padding: const EdgeInsets.symmetric(vertical: 4.0),
//                         color:
//                             ok ? Colors.green.shade50 : Colors.yellow.shade100,
//                         child: Row(
//                           crossAxisAlignment:
//                               CrossAxisAlignment.start, // 🔸 sarma için start
//                           children: [
//                             const SizedBox(width: 8),
//                             CircleAvatar(
//                               radius: 16,
//                               backgroundColor: ok ? Colors.green : Colors.amber,
//                               child: Text(
//                                 (index + 1).toString(),
//                                 style: const TextStyle(
//                                     color: Colors.white,
//                                     fontSize: 14,
//                                     fontWeight: FontWeight.bold),
//                               ),
//                             ),
//                             const SizedBox(width: 12),

//                             // 🔸 Uzun metinler satır atlayabilir
//                             Expanded(
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text("PN: ${item.partNumber}",
//                                       softWrap: true),
//                                   Text("SN: ${item.serialNumber}",
//                                       softWrap: true),
//                                   Text("CAGE: ${item.cage}", softWrap: true),
//                                 ],
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ),
//       ],
//     );
//   }

//   @override
//   void dispose() {
//     _scanTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Column(
//           children: [
//             // Üstte Power + küçük boşluk
//             Padding(
//               padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//               child: _buildPowerSlider(),
//             ),
//             const SizedBox(height: 8),

//             // START/CLEAR (dropdown ile aynı genişlik)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: SizedBox(
//                   width: _controlsWidth(context),
//                   child: _buildButtonRow(),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 12),

//             // ATA Class dropdown (butonlar ile birebir hizalı)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: SizedBox(
//                   width: _controlsWidth(context),
//                   child: _buildAtaFilterDropdown(),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 8),

//             // Liste
//             _buildTagList(),
//           ],
//         ),

//         // Paylaş FAB
//         Positioned(
//           right: 8,
//           bottom: 8,
//           child: IgnorePointer(
//             ignoring: _exportBusy || _tagItems.isEmpty,
//             child: Opacity(
//               opacity: (_exportBusy || _tagItems.isEmpty) ? 0.5 : 1.0,
//               child: FloatingActionButton(
//                 heroTag: 'fabShareEmail',
//                 tooltip: 'Share via email (.xlsx)',
//                 shape: const CircleBorder(),
//                 backgroundColor: Colors.grey.shade700,
//                 foregroundColor: Colors.white,
//                 onPressed: (_exportBusy || _tagItems.isEmpty)
//                     ? null
//                     : _shareExcelAnywhere,
//                 child: AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 200),
//                   child: _exportBusy
//                       ? const SizedBox(
//                           key: ValueKey('loader'),
//                           width: 22,
//                           height: 22,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2, color: Colors.white),
//                         )
//                       : const Icon(Icons.mail_outline, key: ValueKey('icon')),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// // }
// import 'dart:async';
// import 'dart:developer';
// import 'dart:io';

// import 'package:flutter/material.dart';
// import 'package:excel/excel.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:share_plus/share_plus.dart';

// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/tag_detail_screen.dart';

// class FilterOption {
//   final int id;
//   final String label;
//   const FilterOption(this.id, this.label);
// }

// const FilterOption kAtaAll = FilterOption(-999, 'All — show everything');

// const List<FilterOption> kAtaFilterOptions = [
//   FilterOption(0, 'All others'),
//   FilterOption(1, 'Item (general; not 8–63)'),
//   FilterOption(2, 'Carton'),
//   FilterOption(6, 'Pallet'),
//   FilterOption(8, 'Seat Cushions'),
//   FilterOption(9, 'Seat Covers'),
//   FilterOption(10, 'Seat Belts / Belt Ext.'),
//   FilterOption(11, 'Galley & Service Equip.'),
//   FilterOption(12, 'Galley Ovens'),
//   FilterOption(13, 'Aircraft Security Items'),
//   FilterOption(14, 'Life Vests'),
//   FilterOption(15, 'Oxygen Generators (not cylinders/bottles)'),
//   FilterOption(16, 'Engine & Engine Components'),
//   FilterOption(17, 'Avionics'),
//   FilterOption(18, 'Experimental (“flight test”) equip.'),
//   FilterOption(19, 'Other Emergency Equipment'),
//   FilterOption(20, 'Other Rotables'),
//   FilterOption(21, 'Other Repairables'),
//   FilterOption(22, 'Other Cabin Interior'),
//   FilterOption(23, 'Other Repair (e.g., structural)'),
//   FilterOption(24, 'Seat & Seat Components (excl. 8–10)'),
//   FilterOption(25, 'In-Flight Entertainment (IFE) & related'),
//   FilterOption(56, 'Location Identifier'),
//   FilterOption(57, 'Documentation'),
//   FilterOption(58, 'Tools'),
//   FilterOption(59, 'Ground Support Equipment'),
//   FilterOption(60, 'Other Non-Flyable Equipment'),
// ];

// class BoxCheckScanScreen extends StatelessWidget {
//   const BoxCheckScanScreen({Key? key}) : super(key: key);

//   // @override
//   // Widget build(BuildContext context) {
//   //   return Scaffold(
//   //     appBar: commonAppBar(context, 'TAG READER', showBack: true),
//   //     body: const _BoxCheckScanBody(),
//   //   );
//   // }
//   Future<bool> _goHome(BuildContext context) async {
//     Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
//     return false; // bu sayfayı pop etme
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false, // geri eylemini biz yöneteceğiz
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return; // Navigator zaten pop ettiyse dokunma
//         Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
//       },
//       child: Scaffold(
//         appBar: commonAppBar(context, 'TAG READER', showBack: true),
//         body: const _BoxCheckScanBody(),
//       ),
//     );
//   }
// }

// class _BoxCheckScanBody extends StatefulWidget {
//   const _BoxCheckScanBody();
//   @override
//   State<_BoxCheckScanBody> createState() => _BoxCheckScanBodyState();
// }

// class _BoxCheckScanBodyState extends State<_BoxCheckScanBody> {
//   bool _isScanning = false;
//   bool _exportBusy = false;

//   int _umRoundRobinIndex = 0;
//   Timer? _scanTimer;

//   double _powerLevel = 5;
//   final double _minPower = 5;
//   final double _maxPower = 30;
//   final int _divisions = 25;

//   final List<TagItem> _tagItems = [];
//   final Set<String> _epcSet = <String>{};
//   final Map<String, DateTime> _lastSeen = {};
//   bool _scanTickBusy = false;

//   List<FilterOption> get _ataOptions => [kAtaAll, ...kAtaFilterOptions];

//   // UI ölçüler
//   static const double _controlHeight = 48.0; // buton ve kapalı dropdown
//   static const double _controlsMaxWidth = 360;
//   static const double _listRowApproxHeight = 60;
//   static const int _listMaxVisibleRows = 5;

//   double _controlsWidth(BuildContext context) {
//     final usable = MediaQuery.of(context).size.width - 32;
//     return _controlsMaxWidth < usable ? _controlsMaxWidth : usable;
//   }

//   // --- ATA filter state ---
//   FilterOption? _selectedAta;

//   int? _ataClassOf(TagItem t) {
//     final hex = t.userHex;
//     if (hex == null || hex.length < 16) return null;
//     final d = decodeUserMemory(hex);
//     final v = d['ataClass'];
//     if (v is int) return v;
//     if (v is String) return int.tryParse(v);
//     return null;
//   }

//   List<TagItem> get _filteredItems {
//     final sel = _selectedAta;
//     if (sel == null || sel.id == kAtaAll.id) return _tagItems;
//     final code = sel.id;
//     return _tagItems.where((t) => _ataClassOf(t) == code).toList();
//   }

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _checkIfConnected(); // ağır iş: plugin init/bağlantı
//     });
//     _selectedAta = kAtaAll;
//   }

//   Future<void> _checkIfConnected() async {
//     log("Checking if RFID reader is already connected (BoxCheckScanScreen)...");
//     final bool? connected = await RfidC72Plugin.isConnected;
//     log(connected == true ? "Yes, RFID connected" : "RFID not connected.");
//   }

//   Future<void> _readTag() async {
//     try {
//       final String? raw = await RfidC72Plugin.readSingleTagEpc();
//       if (raw == null || raw.isEmpty) return;

//       final epcHex = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();

//       final now = DateTime.now();
//       final last = _lastSeen[epcHex];
//       if (last != null && now.difference(last) < const Duration(seconds: 3)) {
//         return;
//       }
//       _lastSeen[epcHex] = now;

//       if (_epcSet.contains(epcHex)) return;

//       final decoded = decodeEpc(epcHex);
//       setState(() {
//         _epcSet.add(epcHex);
//         _tagItems.insert(
//           0,
//           TagItem(
//             rawEpc: epcHex,
//             cage: decoded.cage,
//             partNumber: decoded.partNumber,
//             serialNumber: decoded.serialNumber,
//             userRead: false,
//           ),
//         );
//       });

//       await _checkUserMemoryOnce(_tagItems.first);
//     } catch (e) {
//       log("Error reading tag: $e");
//     }
//   }

//   void _toggleScan() {
//     if (!_isScanning) {
//       _scanTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
//         if (_scanTickBusy) return;
//         _scanTickBusy = true;
//         try {
//           await _readTag();
//           await _pollMissingUserMemoryDuringScan(maxPerTick: 2);
//         } finally {
//           _scanTickBusy = false;
//         }
//       });
//       setState(() => _isScanning = true);
//     } else {
//       _scanTimer?.cancel();
//       _scanTimer = null;
//       setState(() => _isScanning = false);
//     }
//   }

//   void _clearList() {
//     setState(() {
//       _tagItems.clear();
//       _epcSet.clear();
//       _lastSeen.clear();
//     });
//   }

//   Future<void> _shareExcelAnywhere() async {
//     if (_tagItems.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('List empty: no tags to export.')),
//       );
//       return;
//     }

//     final wasScanning = _isScanning;
//     if (wasScanning) _toggleScan();
//     setState(() => _exportBusy = true);

//     try {
//       final excel = Excel.createExcel();
//       final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
//       final sheet = excel.sheets[sheetName]!;

//       sheet.appendRow([
//         'No',
//         'PN',
//         'SN',
//         'Üretici (CAGE)',
//         'EPC (HEX)',
//         'USER HEX',
//         'w0',
//         'w1',
//         'w2',
//         'w3',
//         'ToC Major',
//         'ToC Minor',
//         'ATA Class',
//         'Tag Type',
//         'Payload Text',
//       ]);

//       int i = 1;
//       for (final t in _filteredItems) {
//         final userHex =
//             await RfidC72Plugin.readUserMemoryForEpc(t.rawEpc) ?? '';
//         final d = decodeUserMemory(userHex);
//         sheet.appendRow([
//           i++,
//           t.partNumber,
//           t.serialNumber,
//           t.cage,
//           t.rawEpc,
//           userHex,
//           d['w0'] ?? '',
//           d['w1'] ?? '',
//           d['w2'] ?? '',
//           d['w3'] ?? '',
//           d['tocMajor'] ?? '',
//           d['tocMinor'] ?? '',
//           d['ataClass'] ?? '',
//           d['tagType'] ?? '',
//           d['payloadText'] ?? '',
//         ]);
//       }

//       final bytes = excel.encode();
//       if (bytes == null) throw Exception('Excel encode null');

//       final dir = await getTemporaryDirectory();
//       final now = DateTime.now();
//       String two(int n) => n.toString().padLeft(2, '0');
//       final stamp =
//           '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

//       final fileName = 'RFID-READ-TAGS-$stamp.xlsx';
//       final file = File('${dir.path}/$fileName')..createSync(recursive: true);
//       await file.writeAsBytes(bytes, flush: true);

//       await Share.shareXFiles(
//         [
//           XFile(file.path,
//               name: fileName,
//               mimeType:
//                   'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
//         ],
//         subject: 'RFID Export ($stamp)',
//         text: 'Ekte PN/SN/Üretici + EPC + USER içerikleri bulunmaktadır.',
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Paylaşım başarısız: $e')),
//       );
//     } finally {
//       if (wasScanning) _toggleScan();
//       if (mounted) setState(() => _exportBusy = false);
//     }
//   }

//   Future<void> _checkUserMemoryOnce(TagItem item) async {
//     if (item.userRead == true) return;
//     try {
//       final hex = await RfidC72Plugin.readUserMemoryForEpc(item.rawEpc);
//       if (!mounted) return;
//       if (hex != null && hex.length >= 16) {
//         setState(() {
//           item.userHex = hex;
//           item.userRead = true;
//         });
//       }
//     } catch (_) {}
//   }

//   Future<void> _pollMissingUserMemoryDuringScan({int maxPerTick = 2}) async {
//     if (!_isScanning || _tagItems.isEmpty) return;
//     int checked = 0;
//     final total = _tagItems.length;
//     while (checked < maxPerTick) {
//       _umRoundRobinIndex = (_umRoundRobinIndex + 1) % total;
//       final item = _tagItems[_umRoundRobinIndex];
//       if (!item.userRead) await _checkUserMemoryOnce(item);
//       checked++;
//       if (!_isScanning) break;
//     }
//   }

//   Widget _buildAtaFilterDropdown() {
//     final opts = _ataOptions;
//     return DropdownButtonFormField<FilterOption>(
//       value: _selectedAta ?? kAtaAll,
//       isDense: true,
//       isExpanded: true,
//       // <= Menü yüksekliğini 5 satırla sınırla
//       menuMaxHeight: 5 * kMinInteractiveDimension,
//       decoration: InputDecoration(
//         labelText: 'ATA Class',
//         isDense: true,
//         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
//       ),
//       items: opts.map((o) {
//         final label = o.id == kAtaAll.id ? o.label : '${o.id} — ${o.label}';
//         return DropdownMenuItem(
//           value: o,
//           child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
//         );
//       }).toList(),
//       onChanged: (v) => setState(() => _selectedAta = v),
//     );
//   }

//   Widget _buildPowerSlider() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text("Adjust Power Level => ${_powerLevel.toInt()}",
//             style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
//         const SizedBox(height: 6),
//         SliderTheme(
//           data: SliderTheme.of(context).copyWith(
//             trackHeight: 2,
//             thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
//             overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
//           ),
//           child: Row(
//             children: [
//               SizedBox(
//                 width: 24,
//                 child: Text(_minPower.toInt().toString(),
//                     textAlign: TextAlign.center,
//                     style:
//                         const TextStyle(fontSize: 12, color: Colors.black54)),
//               ),
//               Expanded(
//                 child: Slider(
//                   value: _powerLevel,
//                   min: _minPower,
//                   max: _maxPower,
//                   divisions: _divisions,
//                   onChanged: (v) => setState(() => _powerLevel = v),
//                   onChangeEnd: (v) {
//                     RfidC72Plugin.setPowerLevel(v.toInt().toString());
//                     log("Power level set to ${v.toInt()}");
//                   },
//                 ),
//               ),
//               SizedBox(
//                 width: 24,
//                 child: Text(_maxPower.toInt().toString(),
//                     textAlign: TextAlign.center,
//                     style:
//                         const TextStyle(fontSize: 12, color: Colors.black54)),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildButtonRow() {
//     final dense = const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
//     final denseText =
//         const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

//     final elevStyle = ElevatedButton.styleFrom(
//       padding: dense,
//       textStyle: denseText,
//       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       visualDensity: const VisualDensity(vertical: -2),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       backgroundColor:
//           _isScanning ? Colors.red.shade600 : Colors.green.shade600,
//       foregroundColor: Colors.white,
//       minimumSize: const Size.fromHeight(_controlHeight),
//     );

//     final outStyle = OutlinedButton.styleFrom(
//       padding: dense,
//       textStyle: denseText,
//       tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       visualDensity: const VisualDensity(vertical: -2),
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//       minimumSize: const Size.fromHeight(_controlHeight),
//       foregroundColor: _brandNavy,
//     );

//     return Row(
//       children: [
//         Expanded(
//             child: ElevatedButton(
//                 onPressed: _toggleScan,
//                 style: elevStyle,
//                 child: Text(_isScanning ? "Stop Scan" : "Start Scan"))),
//         const SizedBox(width: 8),
//         Expanded(
//             child: OutlinedButton(
//                 onPressed: _clearList,
//                 style: outStyle,
//                 child: const Text("Clear List"))),
//       ],
//     );
//   }

//   Widget _buildTagList() {
//     final items = _filteredItems;

//     return Expanded(
//       // <- boş alan kalmasın, liste alanı tüm alt kısmı doldursun
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
//             child: Text(
//               "Total Tags: ${items.length} / ${_tagItems.length}",
//               style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//             ),
//           ),
//           const SizedBox(height: 4),
//           Expanded(
//             child: items.isEmpty
//                 ? const Center(child: Text("No tags read yet."))
//                 : ListView.separated(
//                     padding: const EdgeInsets.symmetric(horizontal: 16),
//                     itemCount: items.length,
//                     separatorBuilder: (_, __) =>
//                         const Divider(height: 1, thickness: 1),
//                     itemBuilder: (context, index) {
//                       final item = items[index];
//                       final ok = item.userRead == true;

//                       return Material(
//                         color:
//                             ok ? Colors.green.shade50 : Colors.yellow.shade100,
//                         child: ListTile(
//                           contentPadding: const EdgeInsets.symmetric(
//                               horizontal: 8, vertical: 6),
//                           // ① Numara: dikeyde otomatik ortalı
//                           leading: CircleAvatar(
//                             radius: 16,
//                             backgroundColor: ok ? Colors.green : Colors.amber,
//                             child: FittedBox(
//                               child: Text(
//                                 '${index + 1}',
//                                 style: const TextStyle(
//                                   color: Colors.white,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                             ),
//                           ),
//                           // ② Metinler
//                           title: Text('PN: ${item.partNumber}', softWrap: true),
//                           subtitle: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text('SN: ${item.serialNumber}', softWrap: true),
//                               Text('Üretici: ${item.cage}', softWrap: true),
//                             ],
//                           ),
//                           // ③ Tıklayınca detay sayfası
//                           onTap: () {
//                             Navigator.of(context).push(
//                               MaterialPageRoute(
//                                 builder: (_) => TagDetailScreen(
//                                   tagItem: item,
//                                   // Eğer daha önce okunmadıysa boş ver,
//                                   // TagDetailScreen kendi otomatik okuyor.
//                                   userMemoryHex: item.userHex ?? '',
//                                 ),
//                               ),
//                             );
//                           },
//                         ),
//                       );
//                     },
//                   ),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _scanTimer?.cancel();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Column(
//           children: [
//             Padding(
//                 padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
//                 child: _buildPowerSlider()),
//             const SizedBox(height: 8),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: SizedBox(
//                     width: _controlsWidth(context), child: _buildButtonRow()),
//               ),
//             ),
//             const SizedBox(height: 12),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 16),
//               child: Align(
//                 alignment: Alignment.centerLeft,
//                 child: SizedBox(
//                     width: _controlsWidth(context),
//                     child: _buildAtaFilterDropdown()),
//               ),
//             ),
//             const SizedBox(height: 8),
//             _buildTagList(),
//           ],
//         ),
//         Positioned(
//           right: 8,
//           bottom: 8,
//           child: IgnorePointer(
//             ignoring: _exportBusy || _tagItems.isEmpty,
//             child: Opacity(
//               opacity: (_exportBusy || _tagItems.isEmpty) ? 0.5 : 1.0,
//               child: FloatingActionButton(
//                 heroTag: 'fabShareEmail',
//                 tooltip: 'Share via email (.xlsx)',
//                 shape: const CircleBorder(),
//                 backgroundColor: Colors.grey.shade700,
//                 foregroundColor: Colors.white,
//                 onPressed: (_exportBusy || _tagItems.isEmpty)
//                     ? null
//                     : _shareExcelAnywhere,
//                 child: AnimatedSwitcher(
//                   duration: const Duration(milliseconds: 200),
//                   child: _exportBusy
//                       ? const SizedBox(
//                           key: ValueKey('loader'),
//                           width: 22,
//                           height: 22,
//                           child: CircularProgressIndicator(
//                               strokeWidth: 2, color: Colors.white),
//                         )
//                       : const Icon(Icons.mail_outline, key: ValueKey('icon')),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
// lib/ui/screens/box_check_scan_screen/box_check_scan_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/tag_detail_screen.dart';


class FilterOption {
  final int id;
  final String label;
  const FilterOption(this.id, this.label);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FilterOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

const FilterOption kFilterAll = FilterOption(-999, 'All — show everything');

const List<FilterOption> kFilterOptions = [
  FilterOption(0, 'All others'),
  FilterOption(1, 'Item (general; not 8–63)'),
  FilterOption(2, 'Carton'),
  FilterOption(6, 'Pallet'),
  FilterOption(8, 'Seat Cushions'),
  FilterOption(9, 'Seat Covers'),
  FilterOption(10, 'Seat Belts / Belt Ext.'),
  FilterOption(11, 'Galley & Service Equip.'),
  FilterOption(12, 'Galley Ovens'),
  FilterOption(13, 'Aircraft Security Items'),
  FilterOption(14, 'Life Vests'),
  FilterOption(15, 'Oxygen Generators'),
  FilterOption(16, 'Engine & Engine Components'),
  FilterOption(17, 'Avionics'),
  FilterOption(18, 'Experimental (“flight test”) equip.'),
  FilterOption(19, 'Other Emergency Equipment'),
  FilterOption(20, 'Other Rotables'),
  FilterOption(21, 'Other Repairables'),
  FilterOption(22, 'Other Cabin Interior'),
  FilterOption(23, 'Other Repair (e.g., structural)'),
  FilterOption(24, 'Seat & Seat Components (excl. 8–10)'),
  FilterOption(25, 'In-Flight Entertainment (IFE)'),
  FilterOption(56, 'Location Identifier'),
  FilterOption(57, 'Documentation'),
  FilterOption(58, 'Tools'),
  FilterOption(59, 'Ground Support Equipment'),
  FilterOption(60, 'Other Non-Flyable Equipment'),
];

class BoxCheckScanScreen extends StatelessWidget {
  const BoxCheckScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      },
      child: Scaffold(
        appBar: commonAppBar(context, 'TAG READER', showBack: true),
        body: const _BoxCheckScanBody(),
      ),
    );
  }
}

class _BoxCheckScanBody extends StatefulWidget {
  const _BoxCheckScanBody();
  @override
  State<_BoxCheckScanBody> createState() => _BoxCheckScanBodyState();
}

class _BoxCheckScanBodyState extends State<_BoxCheckScanBody> {
  static const Color _brandNavy = Color(0xFF003B5C);
  bool _isScanning = false;
  bool _exportBusy = false;

  Timer? _scanTimer;
  bool _scanTickBusy = false;
  bool _scanStartedByTrigger = false;

  // RF power
  double _powerLevel = 5;
  final double _minPower = 5;
  final double _maxPower = 30;
  final int _divisions = 25;

  // Data
  final List<TagItem> _tagItems = [];
  final Map<String, int> _tagIndexById = <String, int>{};
  final Map<String, DateTime> _lastSeen = {};

  // Filter
  FilterOption? _selectedFilter = kFilterAll;
  List<FilterOption> get _filterOptions => [kFilterAll, ...kFilterOptions];

  String _identityKey({
    required String epc,
    required String tid,
    required bool validTid,
  }) {
    // Use EPC+TID combination for unique identity
    // Must match TagItem.uniqueId format exactly (with trim)
    // Only include TID if SDK marks it as valid AND it's non-empty
    final epcKey = epc.toUpperCase().trim();
    final tidKey = tid.trim();
    if (validTid && tidKey.isNotEmpty) {
      return '$epcKey|${tidKey.toUpperCase()}';
    }
    return epcKey;
  }

  @override
  void initState() {
    super.initState();
    // Run heavy initialization asynchronously without blocking UI
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    // Parallel initialization for faster startup
    await Future.wait([
      _ensureUhf(),
      _attachTriggerControls(),
    ]);
  }

  Future<void> _ensureUhf() async {
    final ok = await RfidC72Plugin.ensureUhfConnected();
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RFID connection failed (UHF).')),
      );
    }
  }

  Future<void> _attachTriggerControls() async {
    await RfidC72Plugin.ensureKeyHandler();
    RfidC72Plugin.registerRfidTriggerHandlers(
      onTriggerDown: _handleTriggerDown,
      onTriggerUp: _handleTriggerUp,
    );
    await RfidC72Plugin.setTriggerMode(ScanTriggerMode.rfid);
  }

  Future<void> _handleTriggerDown() async {
    if (_isScanning) return;
    _scanStartedByTrigger = true;
    _toggleScan();
  }

  Future<void> _handleTriggerUp() async {
    if (_scanStartedByTrigger && _isScanning) {
      _toggleScan();
    }
    _scanStartedByTrigger = false;
  }

  int? _extractAtaClass(String? userHex) {
    if (userHex == null || userHex.length < 16) return null;
    final d = decodeUserMemory(userHex);
    final v = d['ataClass'];
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Returns filtered tag list based on selected ATA class filter.
  /// 
  /// Priority: Uses ataClass (from USER memory ToC) first, falls back to 
  /// filterValue (from EPC header) if ataClass is not available.
  /// This ensures correct filtering even when USER memory hasn't been read yet.
  List<TagItem> get _filteredItems {
    final sel = _selectedFilter;
    if (sel == null || sel.id == kFilterAll.id) {
      return _tagItems;
    }
    final code = sel.id;
    return _tagItems.where((t) {
      // Prefer ataClass from USER memory ToC (more accurate)
      // Fall back to filterValue from EPC header if ataClass not available
      final effectiveClass = t.ataClass ?? t.filterValue;
      return effectiveClass == code;
    }).toList();
  }

  Future<void> _readTag() async {
    try {
      String? tagInfoJson = await RfidC72Plugin.readSingleTagMeta();
      if (tagInfoJson == null || tagInfoJson.isEmpty) {
        tagInfoJson = await RfidC72Plugin.readSingleTagWithTid();
      }
      if (tagInfoJson == null || tagInfoJson.isEmpty) return;

      // Parse the JSON response containing EPC, TID, and RSSI
      late Map<String, dynamic> tagInfo;
      try {
        tagInfo = jsonDecode(tagInfoJson);
      } catch (e) {
        log("❌ TID-SCAN: Failed to parse tag info JSON: $e");
        return;
      }

      final String epcHex = (tagInfo['epc'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+'), '')
          .toUpperCase();
      final String tid = (tagInfo['tid'] ?? '').toString().toUpperCase();
      final bool validTid = tagInfo['validTid'] == true;
      final String directUserMemory = (tagInfo['userMemory'] ?? '').toString();

      if (epcHex.isEmpty) return;

      // Filter: Only process ATA-compliant tags (EPC header = 0x3B)
      if (epcHex.length >= 2) {
        final epcHeader = epcHex.substring(0, 2).toUpperCase();
        if (epcHeader != '3B') {
          // Non-ATA tag - skip silently (don't add to list)
          return;
        }
      }

      final now = DateTime.now();
      final String identityKey = _identityKey(epc: epcHex, tid: tid, validTid: validTid);
      
      // Two-phase lookup to handle TID state transitions:
      // 1. First try exact match (EPC|TID or just EPC)
      // 2. If not found, search for any tag with matching EPC
      //    Handles both directions:
      //    - TID loss: tag had TID before, now missing (EPC|TID -> EPC)
      //    - TID gain: tag had no TID before, now has one (EPC -> EPC|TID)
      int? existingIndex = _tagIndexById[identityKey];
      if (existingIndex == null) {
        // Exact key not found - search for any existing tag with same EPC
        // Key format is either "EPC" or "EPC|TID", so we need exact matching
        final epcUpper = epcHex.toUpperCase().trim();
        for (final entry in _tagIndexById.entries) {
          // Check for exact EPC match: key == "EPC" or key == "EPC|..."
          // Using startsWith alone could match "3B06" with "3B060" incorrectly
          final key = entry.key;
          if (key == epcUpper || key.startsWith('$epcUpper|')) {
            existingIndex = entry.value;
            break;
          }
        }
      }
      final TagItem? existingItem =
          existingIndex != null ? _tagItems[existingIndex] : null;
      final bool needsUser = !(existingItem?.userRead ?? false);
      final bool hasDirectUser =
          directUserMemory.isNotEmpty && directUserMemory.length >= 16;

      final last = _lastSeen[identityKey];
      if (last != null &&
          now.difference(last) < const Duration(milliseconds: 1200) &&
          !needsUser &&
          !hasDirectUser) {
        return;
      }
      _lastSeen[identityKey] = now;

      final decoded = decodeEpc(epcHex);

      // Use USER from inventory if SDK provided it
      String? userHex;
      if (hasDirectUser) {
        userHex = directUserMemory;
        
        // SDK inventory returns ~61 words. For Lifecycle records (at word 74+),
        // we need full read. Dynamic read will determine actual size from ToC.
        // Only skip if we already have substantial data (more than inventory provides)
        final bool needsFullRead = userHex.length < 300; // ~75 words - more than inventory
        final bool existingNeedsFullRead = existingItem != null && 
            (existingItem.userHex?.length ?? 0) < 300;
        
        if (needsFullRead || existingNeedsFullRead) {
          try {
            // Use EPC filter (unique per tag) instead of TID (may be duplicate)
            final fullHex = await RfidC72Plugin.readUserMemoryForEpcFull(epcHex);
            if (fullHex != null && fullHex.length > userHex.length) {
              userHex = fullHex;
            } else if (validTid && tid.isNotEmpty && tid.length >= 8) {
              // Fallback to TID if EPC filter fails
              final tidHex = await RfidC72Plugin.readUserMemoryForTid(tid);
              if (tidHex != null && tidHex.length > userHex.length) {
                userHex = tidHex;
              }
            }
          } catch (_) {
            // Keep inventory data if full read fails
          }
        }
      } else {
        userHex = existingItem?.userHex;
      }

      int? ataClass = existingItem?.ataClass;
      if (userHex != null && userHex.length >= 16) {
        if (existingItem == null || existingItem.userHex != userHex) {
          ataClass = _extractAtaClass(userHex);
        }
      }

      TagItem updatedItem;
      // Use TID only if SDK marks it as valid AND non-empty
      // Must match _identityKey logic for consistent tag identification
      final String? effectiveTid = (validTid && tid.isNotEmpty) ? tid : null;
      
      if (existingItem == null) {
        updatedItem = TagItem(
          rawEpc: epcHex,
          cage: decoded.cage,
          partNumber: decoded.partNumber,
          serialNumber: decoded.serialNumber,
          tid: effectiveTid,
          filterValue: decoded.filterValue,
          userRead: userHex != null && userHex.length >= 16,
          userHex: userHex,
          ataClass: ataClass,
        );
      } else {
        // Check if EPC changed - if so, invalidate cached USER memory
        final epcChanged = existingItem.rawEpc != epcHex;
        // Always use effectiveTid (not fallback to existingItem.tid) to maintain
        // consistency with _identityKey. If validTid is false, TID should be null
        // in both the tag item and the identity key to prevent index mismatch.
        updatedItem = existingItem.copyWith(
          rawEpc: epcHex,
          cage: decoded.cage,
          partNumber: decoded.partNumber,
          serialNumber: decoded.serialNumber,
          tid: effectiveTid,
          filterValue: decoded.filterValue,
          userRead: epcChanged
              ? (userHex != null && userHex.isNotEmpty)
              : (userHex != null ? true : existingItem.userRead),
          userHex: epcChanged ? userHex : (userHex ?? existingItem.userHex),
          ataClass: ataClass,
        );
      }

      setState(() {
        _upsertTag(updatedItem);
      });

      // Removed verbose logging for performance
    } catch (e) {
      log("❌ Error reading tag: $e");
    }
  }

  void _upsertTag(TagItem tag) {
    final id = tag.uniqueId;
    final existingIndex = _tagIndexById[id];
    if (existingIndex != null) {
      _tagItems[existingIndex] = tag;
      _rebuildTagIndex();
      return;
    }
    _tagItems.insert(0, tag);
    _rebuildTagIndex();
  }

  void _rebuildTagIndex() {
    _tagIndexById.clear();
    for (var i = 0; i < _tagItems.length; i++) {
      _tagIndexById[_tagItems[i].uniqueId] = i;
    }
  }

  void _toggleScan() {
    if (!_isScanning) {
      _scanTimer = Timer.periodic(const Duration(milliseconds: 400), (_) async {
        if (_scanTickBusy) return;
        _scanTickBusy = true;
        try {
          await _readTag();
          // SDK reads EPC+TID+USER in single operation - very fast!
        } finally {
          _scanTickBusy = false;
        }
      });
      setState(() => _isScanning = true);
    } else {
      _scanTimer?.cancel();
      _scanTimer = null;
      setState(() => _isScanning = false);
    }
  }

  void _clearList() {
    setState(() {
      _tagItems.clear();
      _tagIndexById.clear();
      _lastSeen.clear();
    });
  }

  void _openDetail(TagItem item) {
    final bool wasScanning = _isScanning;
    if (wasScanning) {
      _toggleScan(); // stop scanning while in detail
    }
    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (_) => TagDetailScreen(
        tagItem: item,
        userMemoryHex: item.userHex ?? '',
      ),
    ))
        .then((updated) {
      if (updated == true && mounted) {
        setState(() {}); // reflect any userHex/userRead updates
      }
    });
  }

  /// EPC + USER verilerini Excel’e yazıp paylaş
  Future<void> _shareExcelAnywhere() async {
    if (_tagItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('List empty: no tags to export.')),
      );
      return;
    }

    final wasScanning = _isScanning;
    if (wasScanning) _toggleScan();
    setState(() => _exportBusy = true);

    try {
      final excel = Excel.createExcel();
      final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
      final sheet = excel.sheets[sheetName];
      if (sheet == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create Excel sheet')),
          );
        }
        return;
      }

      sheet.appendRow([
        'No',
        'EPC',
        'TID',
        'PN (EPC)',
        'SN (EPC)',
        'CAGE',
        'Filter',
        'Tag Type',
        'MFR',
        'SER',
        'PNO',
        'PNR',
        'DMF',
        'EXP',
        'PDT',
        'UIC',
        'PML',
        'TDN',
        'Record Count',
        'USER (HEX)',
      ]);

      int i = 1;
      for (final t in _filteredItems) {
        final userHex = t.userHex ?? '';
        final d = decodeUserMemory(userHex);
        final fields = d['fields'] as Map? ?? {};

        // Helper to format dates
        String formatDate(String? raw) {
          if (raw == null || raw.length != 8) return raw ?? '';
          if (!RegExp(r'^\d{8}$').hasMatch(raw)) return raw;
          return '${raw.substring(0, 4)}/${raw.substring(4, 6)}/${raw.substring(6, 8)}';
        }

        final tocHeader = d['tocHeader'] as Map?;
        final tagTypeLabel = tocHeader?['ataTagTypeLabel'] ?? '';

        sheet.appendRow([
          i++,
          t.rawEpc,
          t.tid ?? '',
          t.partNumber,
          t.serialNumber,
          t.cage,
          t.filterValue ?? '',
          tagTypeLabel,
          fields['MFR'] ?? '',
          fields['SER'] ?? '',
          fields['PNO'] ?? '',
          fields['PNR'] ?? '',
          formatDate(fields['DMF']),
          formatDate(fields['EXP']),
          fields['PDT'] ?? '',
          fields['UIC'] ?? '',
          fields['PML'] ?? '',
          fields['TDN'] ?? '',
          d['recordCount'] ?? '',
          userHex,
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) throw Exception('Excel encode null');

      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      String two(int n) => n.toString().padLeft(2, '0');
      final stamp =
          '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';

      final fileName = 'RFID-READ-TAGS-$stamp.xlsx';
      final file = File('${dir.path}/$fileName')..createSync(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [
          XFile(file.path,
              name: fileName,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
        subject: 'RFID Tag Export - $stamp',
        text:
            'Attached: RFID tag data including EPC, TID, USER memory and decoded TEI fields.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (wasScanning) _toggleScan();
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Widget _buildAtaFilterDropdown() {
    final opts = _filterOptions;
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandNavy, width: 2),
          ),
          floatingLabelStyle: const TextStyle(color: _brandNavy),
        ),
      ),
      child: DropdownButtonFormField<FilterOption>(
        value: _selectedFilter ?? kFilterAll,
        isDense: true,
        isExpanded: true,
        menuMaxHeight: 5 * kMinInteractiveDimension,
        decoration: InputDecoration(
          labelText: 'Filter Value',
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandNavy, width: 2),
          ),
        ),
        items: opts.map((o) {
          final label =
              o.id == kFilterAll.id ? o.label : '${o.id} — ${o.label}';
          return DropdownMenuItem(
            value: o,
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: (v) {
          setState(() => _selectedFilter = v);
          final label = v == null || v.id == kFilterAll.id
              ? 'ALL'
              : '${v.id} (${v.label})';
          log('FILTER: Selected $label');
          // Unfocus after a brief delay to ensure dropdown closes first
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              FocusScope.of(context).unfocus();
            }
          });
        },
      ),
    );
  }

  Widget _buildPowerSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.power, size: 16, color: _brandNavy),
            const SizedBox(width: 6),
            const Text("RF Power",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _brandNavy,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text("${_powerLevel.toInt()} dBm",
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: _brandNavy,
            inactiveTrackColor: _brandNavy.withOpacity(.2),
            thumbColor: _brandNavy,
            overlayColor: _brandNavy.withOpacity(.1),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Text(_minPower.toInt().toString(),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
              Expanded(
                child: Slider(
                  value: _powerLevel,
                  min: _minPower,
                  max: _maxPower,
                  divisions: _divisions,
                  onChanged: (v) => setState(() => _powerLevel = v),
                  onChangeEnd: (v) {
                    RfidC72Plugin.setPowerLevel(v.toInt().toString());
                    log("Power level set to ${v.toInt()}");
                  },
                ),
              ),
              SizedBox(
                width: 24,
                child: Text(_maxPower.toInt().toString(),
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black54)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtonRow() {
    const dense = EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    const denseText = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

    final elevStyle = ElevatedButton.styleFrom(
      padding: dense,
      textStyle: denseText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(vertical: -2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor:
          _isScanning ? Colors.red.shade600 : Colors.green.shade600,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(48),
    );

    final outStyle = OutlinedButton.styleFrom(
      padding: dense,
      textStyle: denseText,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(vertical: -2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      minimumSize: const Size.fromHeight(48),
      foregroundColor: _brandNavy,
    );

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _toggleScan,
            style: elevStyle,
            child: Text(_isScanning ? "Stop Scan" : "Start Scan"),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: _clearList,
            style: outStyle,
            child: const Text("Clear List"),
          ),
        ),
      ],
    );
  }

  Widget _listItem(TagItem item, int index) {
    final ok = item.userRead == true;
    return InkWell(
      onTap: () => _openDetail(item),
      child: Container(
        color: ok ? Colors.green.shade50 : Colors.yellow.shade100,
        padding: const EdgeInsets.symmetric(vertical: 10), // biraz daha nefes
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // <== dikeyde ortala
          children: [
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: ok ? Colors.green : Colors.amber,
              child: Text(
                (index + 1).toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("PN: ${item.partNumber}", softWrap: true),
                    Text("SN: ${item.serialNumber}", softWrap: true),
                    Text("CAGE: ${item.cage}", softWrap: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagList() {
    final items = _filteredItems;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _brandNavy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.style, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  "Tags",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brandNavy,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "${items.length}",
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                ),
                if (items.length != _tagItems.length) ...[
                  const SizedBox(width: 4),
                  Text(
                    "/ ${_tagItems.length}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No tags read yet."))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, thickness: 1),
                    itemBuilder: (context, index) =>
                        _listItem(items[index], index),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    RfidC72Plugin.clearRfidTriggerHandlers();
    // ignore: discarded_futures
    RfidC72Plugin.setTriggerMode(ScanTriggerMode.barcode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _buildPowerSlider(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildButtonRow(),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAtaFilterDropdown(),
            ),
            const SizedBox(height: 8),
            _buildTagList(),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: IgnorePointer(
            ignoring: _exportBusy || _tagItems.isEmpty,
            child: Opacity(
              opacity: (_exportBusy || _tagItems.isEmpty) ? 0.5 : 1.0,
              child: FloatingActionButton(
                heroTag: 'fabShareEmail',
                tooltip: 'Share via email (.xlsx)',
                shape: const CircleBorder(),
                backgroundColor: Colors.grey.shade700,
                foregroundColor: Colors.white,
                onPressed: (_exportBusy || _tagItems.isEmpty)
                    ? null
                    : _shareExcelAnywhere,
                child: _exportBusy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.mail_outline),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
