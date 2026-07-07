import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/models/tag_item.dart';
import 'package:water_boiler_rfid_labeler/models/epc_user_codec.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/ata_constants.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/widgets/location_status_widget.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/widgets/lifecycle_dialog.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/widgets/record_card_widget.dart';

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

// Local date keys for formatting

// Local theme constants (these reference shared constants)
const Color _brandNavy = Color(0xFF003B5C);
const Color _textPrimary = Color(0xFF1A1A1A);
const Color _textSecondary = Color(0xFF666666);
const Color _bgLight = Color(0xFFF8F9FA);
const Color _borderLight = Color(0xFFE0E0E0);

const TextStyle _sectionTitleStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: _brandNavy,
    letterSpacing: 0.3);
const TextStyle _cardTitleStyle =
    TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _brandNavy);
const TextStyle _labelStyle =
    TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary);
const TextStyle _valueStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: _textPrimary, height: 1.3);
const TextStyle _chipTitleStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: _textSecondary,
    letterSpacing: 0.5);
const TextStyle _chipValueStyle =
    TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _brandNavy);

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

    // Check if inventory data is already complete by parsing ToC header
    if (_userHex.length >= 16) {
      try {
        // Parse word 2 for 32-bit pointer flag
        final w2 = int.parse(_userHex.substring(8, 12), radix: 16);
        final is32Bit = (w2 & 0x0400) != 0;

        int targetWords;
        if (is32Bit && _userHex.length >= 20) {
          final w3 = int.parse(_userHex.substring(12, 16), radix: 16);
          final w4 = int.parse(_userHex.substring(16, 20), radix: 16);
          targetWords = ((w3 & 0xFFFF) << 16) | (w4 & 0xFFFF);
        } else {
          final w3 = int.parse(_userHex.substring(12, 16), radix: 16);
          targetWords = w3 & 0xFFFF;
        }

        final currentWords = _userHex.length ~/ 4;
        if (targetWords > 0 &&
            targetWords <= 512 &&
            currentWords >= targetWords) {
          log('DETAIL: Inventory data already complete ($currentWords >= $targetWords words), skipping full read');
          return;
        }
      } catch (e) {
        // ToC parse failed, proceed with full read
      }
    }

    // Defensive substring - avoid RangeError for short/truncated EPCs
    final epcPreview = epc.length > 8 ? epc.substring(0, 8) : epc;
    log('DETAIL: Fetching full USER memory via EPC filter: $epcPreview...');
    try {
      // Try EPC filter first (unique per tag, avoids TID duplicate issues)
      String? fullHex = await RfidC72Plugin.readUserMemoryForEpcFull(epc);

      // If EPC filter fails and we have TID, try TID filter as fallback
      if ((fullHex == null || fullHex.length <= _userHex.length) &&
          tid != null &&
          tid.isNotEmpty &&
          tid.length >= 8) {
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
  // Note: _startAutoUserRead is currently unused as we rely on inventory data
  // Kept for potential future use with manual tag reads
  // ignore: unused_element
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

  /// Short-ToC single tags: SRT-U (tag type 0xA) carries a Utility record,
  /// anything else is treated as a Birth Record (SRT-B).
  bool _singleTagIsUtility(Map<String, dynamic> decodedUser) {
    final tocHeader = decodedUser['tocHeader'];
    return tocHeader is Map && tocHeader['ataTagType'] == 0x000A;
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

  Future<void> _handleLifecycleUpdate() async {
    final data = await showUpdateLifecycleDialog(context);
    if (data == null) return;

    try {
      final ok = await RfidC72Plugin.updateLifecycleRecord(
        epcHex: widget.tagItem.rawEpc,
        currentPartNumber: data.currentPartNumber,
        partModLevel: data.partModLevel,
        expirationDate: data.expirationDate,
        certificateNumber: data.certificateNumber,
        lastOverhaulDate: data.lastOverhaulDate,
      );

      if (!mounted) return;

      if (ok == true) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Lifecycle record updated successfully!')),
        );
        // Re-read USER memory
        setState(() => _reading = true);
        final newUserHex =
            await RfidC72Plugin.readUserMemoryForEpc(widget.tagItem.rawEpc);
        if (!mounted) return;
        if (newUserHex != null && newUserHex.isNotEmpty) {
          setState(() {
            _userHex = newUserHex;
            widget.tagItem.userHex = newUserHex;
          });
        }
        setState(() => _reading = false);
      } else {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lifecycle update failed!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
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
    // Only give records a dedicated section when some were actually decoded.
    // Legacy / short-ToC tags can DECLARE a Dual/Multi tag type in their ToC
    // while carrying a single combined payload with no Record Descriptors;
    // without this gate they'd render an empty records section and the decoded
    // USER fields would never be shown.
    final recordsList = decodedUser['records'];
    final hasRecords = recordsList is List && recordsList.isNotEmpty;
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

          // For Dual/Multi-Record tags, show records separately — but only when
          // records were actually decoded; otherwise fall back to the combined
          // payload below so short-ToC/single tags still show their USER fields.
          if (hasRecords &&
              (_isDualRecordTag(decodedUser) ||
                  _hasMultipleRecords(decodedUser))) ...[
            RecordSectionsWidget(decodedUser: decodedUser),
            const SizedBox(height: 16),
          ] else if (hasPayload) ...[
            // Single/short-ToC tag — render the combined payload through the SAME
            // record card used for Dual/Multi tags, so every detail screen shares
            // one look (icon + title card, human-readable ATA field rows).
            RecordCardWidget(record: {
              'descriptor': {
                'recordType': _singleTagIsUtility(decodedUser) ? 0xFF : 0x00,
                'recordTypeLabel': _singleTagIsUtility(decodedUser)
                    ? 'Utility Record'
                    : 'Birth Record',
              },
              'payloadText': payloadText,
              'fields': decodedFields,
            }),
            const SizedBox(height: 16),
          ],
          _longPressCopyBox('EPC (Hex)', epcText),

          const SizedBox(height: 16),
          // Ekranda 2 satır, uzun basınca TAMAMINI kopyalar
          _longPressCopyBox('User Memory (Hex)', userText, previewMaxLines: 2),

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
                onPressed: _handleLifecycleUpdate,
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
}
