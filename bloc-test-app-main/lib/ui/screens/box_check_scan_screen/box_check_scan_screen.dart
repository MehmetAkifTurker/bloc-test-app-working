// Box Check Scan Screen - RFID Tag Reader
import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';

import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/epc_user_codec.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/tag_detail_screen.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/filter_options.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/excel_export_helper.dart';

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
    // setTriggerMode(rfid) already calls disposeBarcode() internally
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
      final String identityKey =
          _identityKey(epc: epcHex, tid: tid, validTid: validTid);

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

      // Use EPC-only key for lastSeen to prevent duplicate processing
      // when TID state changes (same physical tag, different identity keys)
      final epcOnlyKey = epcHex.toUpperCase().trim();
      final last = _lastSeen[epcOnlyKey];
      if (last != null &&
          now.difference(last) < const Duration(milliseconds: 1200) &&
          !needsUser &&
          !hasDirectUser) {
        return;
      }
      _lastSeen[epcOnlyKey] = now;

      final decoded = decodeEpc(epcHex);

      // Use USER from inventory if SDK provided it
      String? userHex;
      if (hasDirectUser) {
        userHex = directUserMemory;

        // SDK inventory returns ~61 words. For Lifecycle records (at word 74+),
        // we need full read. Dynamic read will determine actual size from ToC.
        // Only skip if we already have substantial data (more than inventory provides)
        final bool needsFullRead =
            userHex.length < 300; // ~75 words - more than inventory
        final bool existingNeedsFullRead =
            existingItem != null && (existingItem.userHex?.length ?? 0) < 300;

        if (needsFullRead || existingNeedsFullRead) {
          try {
            // Use EPC filter (unique per tag) instead of TID (may be duplicate)
            final fullHex =
                await RfidC72Plugin.readUserMemoryForEpcFull(epcHex);
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
    final epcOnly = tag.rawEpc.toUpperCase().trim();
    
    // First check exact match
    int? existingIndex = _tagIndexById[id];
    
    // If not found, search by EPC prefix to handle TID state changes
    // (same physical tag may have different keys when TID is/isn't readable)
    if (existingIndex == null) {
      for (final entry in _tagIndexById.entries) {
        final key = entry.key;
        // Match if key is exactly EPC or starts with EPC|
        if (key == epcOnly || key.startsWith('$epcOnly|')) {
          existingIndex = entry.value;
          break;
        }
      }
    }
    
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

  /// EPC + USER verilerini Excel'e yazıp paylaş
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
      final success = await exportTagsToExcel(_filteredItems);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
      }
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
    final currentFilter = _selectedFilter ?? kFilterAll;
    
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
        value: currentFilter,
        isDense: true,
        isExpanded: true,
        menuMaxHeight: 7 * kMinInteractiveDimension,
        dropdownColor: Colors.white,
        icon: const Icon(Icons.expand_more, color: _brandNavy, size: 22),
        decoration: InputDecoration(
          labelText: 'Filter Value',
          labelStyle: TextStyle(
            color: _brandNavy.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _brandNavy, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        selectedItemBuilder: (context) => opts.map((o) {
          final isAll = o.id == kFilterAll.id;
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isAll ? 'All Tags' : '${o.id} — ${o.label}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _brandNavy,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        items: opts.map((o) {
          final isAll = o.id == kFilterAll.id;
          final isSelected = o.id == currentFilter.id;
          return DropdownMenuItem(
            value: o,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected ? _brandNavy.withOpacity(0.08) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Filter Value number badge
                  if (!isAll)
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _brandNavy.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${o.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _brandNavy,
                        ),
                      ),
                    ),
                  if (!isAll) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isAll ? 'All Tags' : o.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isAll ? Colors.green.shade700 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isAll 
                              ? 'Show all scanned tags' 
                              : 'Filter Value ${o.id}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check, color: _brandNavy, size: 18),
                ],
              ),
            ),
          );
        }).toList(),
        onChanged: (v) {
          setState(() => _selectedFilter = v);
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) FocusScope.of(context).unfocus();
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
            const Icon(Icons.power, size: 16, color: _brandNavy),
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
