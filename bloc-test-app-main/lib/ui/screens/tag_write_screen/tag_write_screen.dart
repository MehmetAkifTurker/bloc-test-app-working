// Tag Write Screen - ATA Spec 2000 compliant RFID tag writer
import 'dart:developer';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/tag_write_screen/create_chip_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ATA Spec 2000 – Table 18 (selected assigned values only).
class FilterOption {
  final int value;
  final String label;
  const FilterOption(this.value, this.label);
}

const List<FilterOption> kAtaFilterOptions = [
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
  FilterOption(15, 'Oxygen Generators (not cylinders/bottles)'),
  FilterOption(16, 'Engine & Engine Components'),
  FilterOption(17, 'Avionics'),
  FilterOption(18, 'Experimental ("flight test") equip.'),
  FilterOption(19, 'Other Emergency Equipment'),
  FilterOption(20, 'Other Rotables'),
  FilterOption(21, 'Other Repairables'),
  FilterOption(22, 'Other Cabin Interior'),
  FilterOption(23, 'Other Repair (e.g., structural)'),
  FilterOption(24, 'Seat & Seat Components (excl. 8–10)'),
  FilterOption(25, 'In-Flight Entertainment (IFE) & related'),
  FilterOption(56, 'Location Identifier'),
  FilterOption(57, 'Documentation'),
  FilterOption(58, 'Tools'),
  FilterOption(59, 'Ground Support Equipment'),
  FilterOption(60, 'Other Non-Flyable Equipment'),
];

/// Optional ATA Spec 2000 TEIs (beyond the common fields). Lets the user add any
/// of these to the Birth Record so the app is universal, not tag-specific, while
/// the common fields above keep the typical workflow one-glance simple.
class OptionalTei {
  final String code;
  final String label;
  final int maxLen;
  const OptionalTei(this.code, this.label, this.maxLen);
}

const List<OptionalTei> kOptionalTeis = [
  OptionalTei('PNR', 'Current Part Number', 32),
  OptionalTei('SEQ', 'Sequence Number', 30),
  OptionalTei('OVD', 'Last Overhaul Date (YYYYMMDD)', 8),
  OptionalTei('DOH', 'Hydrostatic Test Date (YYYYMMDD)', 8),
  OptionalTei('PML', 'Part Modification Level', 100),
  OptionalTei('TDN', 'Certificate / Type Design No.', 32),
  OptionalTei('HAZ', 'Hazardous Material Code', 6),
  OptionalTei('LLE', 'Life Limited (0/1)', 1),
  OptionalTei('LOT', 'Lot / Batch Number', 15),
  OptionalTei('CND', 'Condition (SRV/UNS/UNK)', 3),
  // NOTE: No CAG/SPL option here. The CAGE code is already written as MFR from the
  // mandatory manufacturer field, and ATA Spec 2000 (Birth Record, §1.1) permits
  // only ONE of MFR/CAG/SPL per record — offering CAG here would produce an
  // invalid record carrying both MFR and CAG.
];

class _ExtraField {
  final OptionalTei tei;
  final TextEditingController ctrl = TextEditingController();
  _ExtraField(this.tei);
}

class TagWriteScreen extends StatefulWidget {
  const TagWriteScreen({super.key});

  @override
  State<TagWriteScreen> createState() => _TagWriteScreenState();
}

class _TagWriteScreenState extends State<TagWriteScreen> {
  // Optional extra ATA TEIs the user added for this write (universal write).
  final List<_ExtraField> _extraFields = [];

  final TextEditingController serialNumberController =
      TextEditingController(text: "SN00001");
  final TextEditingController manufacturerController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController manufactureDateController =
      TextEditingController();
  String _selectedPN = "";
  String _selectedManufacturer = "";
  static const double _menuMaxHeight = 260.0;
  static const BoxConstraints _iconButtonConstraints =
      BoxConstraints.tightFor(width: 40, height: 40);
  static const EdgeInsets _iconButtonPadding = EdgeInsets.zero;
  static const Color _brandNavy = Color(0xFF003B5C);

  // Layout constants for consistent alignment
  static const double _actionSlotSize = 40.0;
  static const double _actionGap = 8.0;

  /// A row that keeps two action columns (+ and delete/clear) aligned
  Widget _alignedFieldRow({
    required Widget field,
    Widget? addAction,
    Widget? removeAction,
  }) {
    Widget slot(Widget? child) => SizedBox(
          width: _actionSlotSize,
          height: _actionSlotSize,
          child: child ?? const SizedBox.shrink(),
        );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: field),
        const SizedBox(width: _actionGap),
        slot(addAction),
        const SizedBox(width: _actionGap),
        slot(removeAction),
      ],
    );
  }

  int _selectedFilter = 14;
  DateTime? _mfgDate;
  DateTime? _expDate;

  // SharedPreferences keys
  static const _kPnListKey = 'pn_list';
  static const _kMfrListKey = 'manufacturer_list';
  static const _kProdListKey = 'product_name_list';
  static const _kTagTypesKey = 'tag_types';
  static const _kDescListKey = 'item_description_list';
  // Last-used selection (sticky across sessions for fast batch writing).
  static const _kLastPnKey = 'last_pn';
  static const _kLastMfrKey = 'last_mfr';
  static const _kLastDescKey = 'last_desc';
  static const _kLastSerialKey = 'last_serial';

  // Persistent lists (neutral by default; the user adds their own via "+").
  List<String> _descList = [];
  String _selectedDesc = "";
  List<String> _pnList = [];
  List<String> _mfrList = [];
  List<String> _prodList = [];

  String get manufactureDateFormatted {
    final date = _mfgDate;
    if (date == null) return "";
    return "${date.year.toString().padLeft(4, '0')}"
        "${date.month.toString().padLeft(2, '0')}"
        "${date.day.toString().padLeft(2, '0')}";
  }

  String get expireDateFormatted {
    final date = _expDate;
    if (date == null) return "";
    return "${date.year.toString().padLeft(4, '0')}"
        "${date.month.toString().padLeft(2, '0')}"
        "${date.day.toString().padLeft(2, '0')}";
  }

  String get manufactureDateDisplay {
    final d = _mfgDate;
    if (d == null) return "";
    return "${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";
  }

  String get expireDateDisplay {
    final d = _expDate;
    if (d == null) return "";
    return "${d.year.toString().padLeft(4, '0')}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}";
  }

  String _normalizeManagerSix(String raw) {
    const fallback = 'TG424';
    String cleaned = raw.trim().toUpperCase();
    if (cleaned.isEmpty) cleaned = fallback;
    if (cleaned.length > 6) cleaned = cleaned.substring(0, 6);
    if (cleaned.length < 6) cleaned = cleaned.padLeft(6, ' ');
    return cleaned;
  }

  TagType? _selectedTagType;
  final List<TagType> _tagTypes = [];

  bool _isWriting = false;
  bool _isConnected = false;

  Future<void> _loadTagTypes() async {
    // Always start with built-in presets (cannot be deleted)
    _tagTypes.clear();
    _tagTypes.addAll(kBuiltInTagTypes.map((m) => TagType.fromJson(m)));

    // Load user-added tag types
    final sp = await SharedPreferences.getInstance();
    final rawList = sp.getStringList(_kTagTypesKey);
    if (rawList != null && rawList.isNotEmpty) {
      for (final s in rawList) {
        final tt = TagType.fromJson(jsonDecode(s));
        // Skip if it's a built-in (already added) - check by name match
        if (!tt.isBuiltIn) {
          _tagTypes.add(tt);
        }
      }
    }

    _selectedTagType ??= _tagTypes.first;
    _selectedFilter = _selectedTagType!.defaultFilter;
    // setState called by parent Future.wait completion
  }

  Future<void> _saveTagTypes() async {
    final sp = await SharedPreferences.getInstance();
    // Only save user-added tag types (not built-in)
    final userTypes = _tagTypes.where((t) => !t.isBuiltIn).toList();
    final rawList = userTypes.map((t) => jsonEncode(t.toJson())).toList();
    await sp.setStringList(_kTagTypesKey, rawList);
  }

  @override
  void initState() {
    super.initState();
    // Run all initializations in parallel for faster startup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _loadTagTypes(),
        _loadDropdownData(),
        _checkIfConnected(),
      ]);
      // Single setState after all data is loaded
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadDropdownData() async {
    final sp = await SharedPreferences.getInstance();
    _pnList = sp.getStringList(_kPnListKey) ?? _pnList;
    _mfrList = sp.getStringList(_kMfrListKey) ?? _mfrList;
    _prodList = sp.getStringList(_kProdListKey) ?? _prodList;
    _descList = sp.getStringList(_kDescListKey) ?? _descList;

    // Restore last-used selection (sticky batch writing); fall back to first item.
    final lastPn = sp.getString(_kLastPnKey);
    final lastMfr = sp.getString(_kLastMfrKey);
    final lastDesc = sp.getString(_kLastDescKey);
    final lastSerial = sp.getString(_kLastSerialKey);

    _selectedPN = (lastPn != null && _pnList.contains(lastPn))
        ? lastPn
        : (_pnList.isNotEmpty ? _pnList.first : '');
    _selectedManufacturer = (lastMfr != null && _mfrList.contains(lastMfr))
        ? lastMfr
        : (_mfrList.isNotEmpty ? _mfrList.first : '');
    _selectedDesc = (lastDesc != null && _descList.contains(lastDesc))
        ? lastDesc
        : (_descList.isNotEmpty ? _descList.first : '');
    if (lastSerial != null && lastSerial.isNotEmpty) {
      serialNumberController.text = lastSerial;
    }
    // setState called by parent Future.wait completion
  }

  // Persist last-used selection + serial so the next session (or next write)
  // starts where the user left off — key convenience for batch writing.
  Future<void> _saveLastUsed() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kLastPnKey, _selectedPN);
    await sp.setString(_kLastMfrKey, _selectedManufacturer);
    await sp.setString(_kLastDescKey, _selectedDesc);
    await sp.setString(_kLastSerialKey, serialNumberController.text.trim());
  }

  // Increment the trailing number of a serial (SN00001 -> SN00002), preserving
  // the prefix and zero-padding. Returns unchanged if there's no trailing number.
  String _incrementSerial(String s) {
    final m = RegExp(r'^(.*?)(\d+)$').firstMatch(s);
    if (m == null) return s;
    final prefix = m.group(1)!;
    final digits = m.group(2)!;
    final next = (int.parse(digits) + 1).toString().padLeft(digits.length, '0');
    return '$prefix$next';
  }

  Future<void> _saveList(String key, List<String> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(key, list);
  }

  Future<void> _addItemDialog({
    required String title,
    required String key,
    required List<String> target,
    required void Function(String newVal) onSelected,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          cursorColor: _brandNavy,
          decoration: InputDecoration(
            hintText: 'Enter value',
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: _brandNavy),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(foregroundColor: _brandNavy),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim().toUpperCase()),
            style: FilledButton.styleFrom(backgroundColor: _brandNavy),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    if (target.contains(result)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Already exists')),
      );
      return;
    }
    setState(() {
      target.add(result);
      onSelected(result);
    });
    await _saveList(key, target);
  }

  Future<void> _removeSelectedDialog({
    required String title,
    required String key,
    required List<String> target,
    required String selected,
    required void Function(String newSelected) onSelected,
  }) async {
    if (target.length <= 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one item must remain')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove $title'),
        content: Text('Delete "$selected"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              style: TextButton.styleFrom(foregroundColor: _brandNavy),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _brandNavy),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      target.remove(selected);
      onSelected(target.first);
    });
    await _saveList(key, target);
  }

  Future<void> _checkIfConnected() async {
    // Use ensureUhfConnected - it's already optimized with caching
    final ok = await RfidC72Plugin.ensureUhfConnected();
    if (mounted) {
      setState(() => _isConnected = ok);
    }
  }

  Future<void> _writeToTag() async {
    if (!_isConnected) {
      _showSnackBar("Not connected to the reader. Try again.");
      return;
    }

    final String partNumber = _selectedPN.trim().toUpperCase();
    final String serialNumber =
        serialNumberController.text.trim().toUpperCase();

    if (partNumber.isEmpty || serialNumber.isEmpty) {
      _showSnackBar("Please enter both Part Number and Serial Number.");
      return;
    }
    // ATA Spec 2000 TEI field length validation (Table 3, 5, 8)
    if (partNumber.length > 32) {
      _showSnackBar(
          "Part Number (PNR) is too long (max 32 chars per ATA Spec).");
      return;
    }
    if (serialNumber.length > 30) {
      _showSnackBar(
          "Serial Number (SER) is too long (max 30 chars per ATA Spec).");
      return;
    }
    if (_selectedManufacturer.trim().length != 5) {
      _showSnackBar(
          "CAGE Code (MFR) must be exactly 5 characters per ATA Spec.");
      return;
    }
    if (_selectedDesc.length > 32) {
      _showSnackBar(
          "Part Description (PDT) is too long (max 32 chars per ATA Spec).");
      return;
    }
    // Validate date format (YYYYMMDD = 8 chars)
    if (manufactureDateFormatted.isNotEmpty &&
        manufactureDateFormatted.length != 8) {
      _showSnackBar("Manufacture Date (DMF) must be YYYYMMDD format.");
      return;
    }
    if (expireDateFormatted.isNotEmpty && expireDateFormatted.length != 8) {
      _showSnackBar("Expiration Date (EXP) must be YYYYMMDD format.");
      return;
    }

    try {
      setState(() => _isWriting = true);

      final t = _selectedTagType ??
          TagType(
            name: 'Default DRT',
            recordType: 'DRT',
            epcWords: 12,
            userWords: 128, // ATA Spec: DRT minimum 2k bits = 128 words
            permalockWords: 8,
            defaultFilter: 14,
          );

      final configured = await RfidC72Plugin.configureChipAta(
        recordType: t.recordType,
        epcWords: t.epcWords,
        userWords: t.userWords,
        permalockWords: t.permalockWords,
        enablePermalock: t.enablePermalock,
        lockEpc: false,
        lockUser: false,
        accessPwd: '00000000',
      );
      if (configured != true) {
        _showSnackBar("Chip configuration failed; check reader connection.");
        return;
      }

      final managerSix = _normalizeManagerSix(_selectedManufacturer);
      final epcSuccess = await RfidC72Plugin.programConstruct2Epc(
            partNumber: partNumber,
            serialNumber: serialNumber,
            manager: managerSix,
            accessPwd: "00000000",
            filter: _selectedFilter,
          ) ??
          false;

      final bool? userMemSuccess =
          await RfidC72Plugin.writeAtaUserMemoryWithPayload(
        _selectedManufacturer,
        _selectedDesc,
        _selectedPN,
        serialNumber,
        manufactureDateFormatted,
        expireDateFormatted,
        extraFields: _collectExtraFields(),
      );

      // Apply permalock ONLY if the user enabled it for this tag type and the
      // USER write succeeded. Permalock is PERMANENT and IRREVERSIBLE.
      // SRT-U computes 0 lock words natively, so it stays rewritable even if toggled.
      bool permalockOk = true;
      if (userMemSuccess == true && t.enablePermalock) {
        permalockOk =
            (await RfidC72Plugin.applyAtaPermalock(accessPwd: '00000000')) ??
                false;
      }

      if (epcSuccess == true && userMemSuccess == true) {
        // Remember this selection and auto-increment the serial so the next tag
        // in a batch is ready with one tap (only the serial changed).
        await _saveLastUsed();
        if (mounted) {
          setState(() {
            serialNumberController.text =
                _incrementSerial(serialNumberController.text.trim());
          });
        }
        if (t.enablePermalock && !permalockOk) {
          _showSnackBar("Write OK, but PERMALOCK FAILED. Tag not locked.");
        } else if (t.enablePermalock) {
          _showSnackBar("EPC + User Memory written and permalocked!");
        } else {
          _showSnackBar("EPC and User Memory write successful!");
        }
      } else if (epcSuccess != true && userMemSuccess == true) {
        _showSnackBar("User Memory write successful, but EPC write failed.");
      } else if (epcSuccess == true && userMemSuccess != true) {
        _showSnackBar("EPC write successful, but User Memory write failed.");
      } else {
        _showSnackBar("Write failed. Check logs for details.");
      }
    } catch (e) {
      log("TagWriteScreen: Exception while writing: $e");
      _showSnackBar("Error writing to tag: $e");
    } finally {
      setState(() => _isWriting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    for (final f in _extraFields) {
      f.ctrl.dispose();
    }
    super.dispose();
  }

  // Collect non-empty optional TEIs as {CODE: value} for the universal write.
  Map<String, String> _collectExtraFields() {
    final map = <String, String>{};
    for (final f in _extraFields) {
      final v = f.ctrl.text.trim();
      if (v.isNotEmpty) map[f.tei.code] = v;
    }
    return map;
  }

  Future<void> _addExtraFieldDialog() async {
    final used = _extraFields.map((e) => e.tei.code).toSet();
    final available = kOptionalTeis.where((t) => !used.contains(t.code)).toList();
    if (available.isEmpty) {
      _showSnackBar('All optional fields already added.');
      return;
    }
    final picked = await showModalBottomSheet<OptionalTei>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: available
              .map((t) => ListTile(
                    title: Text('${t.code} — ${t.label}'),
                    onTap: () => Navigator.pop(ctx, t),
                  ))
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      setState(() => _extraFields.add(_ExtraField(picked)));
    }
  }

  // Optional ATA fields section: keeps the common form simple while letting any
  // spec TEI be added (universal). Shown after the common fields.
  Widget _buildExtraFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Optional ATA Fields',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add field'),
              onPressed: _addExtraFieldDialog,
            ),
          ],
        ),
        for (final f in _extraFields)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: f.ctrl,
                    maxLength: f.tei.maxLen,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      isDense: true,
                      counterText: '',
                      labelText: '${f.tei.code} — ${f.tei.label}',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() {
                    f.ctrl.dispose();
                    _extraFields.remove(f);
                  }),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      child: Scaffold(
        appBar: commonAppBar(context, 'TAG WRITER', showBack: true),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              // Brand color scheme
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: _brandNavy,
                    secondary: _brandNavy,
                  ),
              // Dropdown menu theme
              dropdownMenuTheme: DropdownMenuThemeData(
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.white),
                ),
              ),
              // Dialog theme
              dialogTheme: DialogTheme(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              // FilledButton theme (Delete button in dialogs)
              filledButtonTheme: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  backgroundColor: _brandNavy,
                  foregroundColor: Colors.white,
                ),
              ),
              // TextButton theme (Cancel button in dialogs)
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: _brandNavy,
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                labelStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                floatingLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _brandNavy),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: _brandNavy, width: 2),
                ),
              ),
            ),
            child: ListView(
              children: [
                _alignedFieldRow(
                  field: DropdownButtonFormField<TagType>(
                    value: _selectedTagType ??
                        (_tagTypes.isNotEmpty ? _tagTypes.first : null),
                    decoration: const InputDecoration(labelText: 'Tag Type'),
                    isDense: true,
                    isExpanded: true,
                    menuMaxHeight: _menuMaxHeight,
                    items: _tagTypes
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text(
                              t.isBuiltIn ? '🔒 ${t.toString()}' : t.toString(),
                              overflow: TextOverflow.ellipsis,
                            )))
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedTagType = v;
                      _selectedFilter = v?.defaultFilter ?? _selectedFilter;
                    }),
                  ),
                  addAction: IconButton(
                    tooltip: 'Add Tag Type',
                    icon: const Icon(Icons.add),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () async {
                      final created = await Navigator.push<TagType>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const TagTypeManagerPage()),
                      );
                      if (created != null) {
                        setState(() {
                          _tagTypes.add(created);
                          _selectedTagType = created;
                        });
                        await _saveTagTypes();
                      }
                    },
                  ),
                  removeAction: IconButton(
                    tooltip: _selectedTagType?.isBuiltIn == true
                        ? 'Built-in preset (cannot delete)'
                        : 'Remove Tag Type',
                    icon: Icon(
                      Icons.delete_outline,
                      color: _selectedTagType?.isBuiltIn == true
                          ? Colors.grey.shade400
                          : null,
                    ),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: _selectedTagType?.isBuiltIn == true
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Built-in presets cannot be deleted'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        : () async {
                            // Count non-built-in types
                            final userTypes =
                                _tagTypes.where((t) => !t.isBuiltIn).length;
                            if (userTypes <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('No custom types to delete')),
                              );
                              return;
                            }
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Remove Tag Type'),
                                content:
                                    Text('Delete "${_selectedTagType?.name}"?'),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      style: TextButton.styleFrom(
                                          foregroundColor: _brandNavy),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                          backgroundColor: _brandNavy),
                                      child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (ok == true) {
                              setState(() {
                                _tagTypes.remove(_selectedTagType);
                                _selectedTagType = _tagTypes.first;
                              });
                              await _saveTagTypes();
                            }
                          },
                  ),
                ),
                const SizedBox(height: 12),
                _alignedFieldRow(
                  field: DropdownButtonFormField<String>(
                    value: _pnList.contains(_selectedPN) ? _selectedPN : null,
                    decoration: const InputDecoration(labelText: "Part Number"),
                    isDense: true,
                    menuMaxHeight: _menuMaxHeight,
                    items: _pnList
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPN = v!),
                  ),
                  addAction: IconButton(
                    tooltip: 'Add PN',
                    icon: const Icon(Icons.add),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _addItemDialog(
                      title: 'Add Part Number',
                      key: _kPnListKey,
                      target: _pnList,
                      onSelected: (nv) => _selectedPN = nv,
                    ),
                  ),
                  removeAction: IconButton(
                    tooltip: 'Remove PN',
                    icon: const Icon(Icons.delete_outline),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _removeSelectedDialog(
                      title: 'Part Number',
                      key: _kPnListKey,
                      target: _pnList,
                      selected: _selectedPN,
                      onSelected: (nv) => _selectedPN = nv,
                    ),
                  ),
                ),
                _alignedFieldRow(
                  field: TextFormField(
                    controller: serialNumberController,
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                    ),
                  ),
                ),
                _alignedFieldRow(
                  field: DropdownButtonFormField<String>(
                    value: _mfrList.contains(_selectedManufacturer)
                        ? _selectedManufacturer
                        : null,
                    menuMaxHeight: _menuMaxHeight,
                    decoration:
                        const InputDecoration(labelText: "Manufacturer"),
                    isDense: true,
                    items: _mfrList
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedManufacturer = v!),
                  ),
                  addAction: IconButton(
                    tooltip: 'Add Manufacturer',
                    icon: const Icon(Icons.add),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _addItemDialog(
                      title: 'Add Manufacturer',
                      key: _kMfrListKey,
                      target: _mfrList,
                      onSelected: (nv) => _selectedManufacturer = nv,
                    ),
                  ),
                  removeAction: IconButton(
                    tooltip: 'Remove Manufacturer',
                    icon: const Icon(Icons.delete_outline),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _removeSelectedDialog(
                      title: 'Manufacturer',
                      key: _kMfrListKey,
                      target: _mfrList,
                      selected: _selectedManufacturer,
                      onSelected: (nv) => _selectedManufacturer = nv,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _alignedFieldRow(
                  field: DropdownButtonFormField<String>(
                    value: _descList.contains(_selectedDesc) ? _selectedDesc : null,
                    menuMaxHeight: _menuMaxHeight,
                    decoration:
                        const InputDecoration(labelText: "Item Description"),
                    isDense: true,
                    items: _descList
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDesc = v!),
                  ),
                  addAction: IconButton(
                    tooltip: 'Add Description',
                    icon: const Icon(Icons.add),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _addItemDialog(
                      title: 'Add Item Description',
                      key: _kDescListKey,
                      target: _descList,
                      onSelected: (nv) => _selectedDesc = nv,
                    ),
                  ),
                  removeAction: IconButton(
                    tooltip: 'Remove Description',
                    icon: const Icon(Icons.delete_outline),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: () => _removeSelectedDialog(
                      title: 'Item Description',
                      key: _kDescListKey,
                      target: _descList,
                      selected: _selectedDesc,
                      onSelected: (nv) => _selectedDesc = nv,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _alignedFieldRow(
                  field: DropdownButtonFormField<int>(
                    value: _selectedFilter,
                    decoration:
                        const InputDecoration(labelText: 'ATA EPC Filter'),
                    isDense: true,
                    isExpanded: true,
                    alignment: AlignmentDirectional.centerStart,
                    menuMaxHeight: _menuMaxHeight,
                    items: kAtaFilterOptions
                        .map((o) => DropdownMenuItem(
                              value: o.value,
                              child: Text(
                                '${o.value.toString().padLeft(2, '0')} – ${o.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ))
                        .toList(),
                    selectedItemBuilder: (context) => kAtaFilterOptions
                        .map((o) => Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '${o.value.toString().padLeft(2, '0')} – ${o.label}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedFilter = v ?? _selectedFilter),
                  ),
                ),
                const SizedBox(height: 12),
                _alignedFieldRow(
                  field: GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _mfgDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _brandNavy,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _mfgDate = picked);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller:
                            TextEditingController(text: manufactureDateDisplay),
                        decoration: const InputDecoration(
                          hintText: 'Manufacture Date (YYYY/MM/DD)',
                          labelText: 'Manufacture Date',
                        ),
                      ),
                    ),
                  ),
                  addAction: IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: _mfgDate == null
                        ? null
                        : () => setState(() => _mfgDate = null),
                  ),
                  removeAction: null,
                ),
                const SizedBox(height: 12),
                _alignedFieldRow(
                  field: GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _expDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _brandNavy,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) setState(() => _expDate = picked);
                    },
                    child: AbsorbPointer(
                      child: TextFormField(
                        controller:
                            TextEditingController(text: expireDateDisplay),
                        decoration: const InputDecoration(
                          hintText: 'Expire Date (YYYY/MM/DD)',
                          labelText: 'Expire Date',
                        ),
                      ),
                    ),
                  ),
                  addAction: IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    constraints: _iconButtonConstraints,
                    padding: _iconButtonPadding,
                    onPressed: _expDate == null
                        ? null
                        : () => setState(() => _expDate = null),
                  ),
                  removeAction: null,
                ),
                const SizedBox(height: 16),
                _buildExtraFieldsSection(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brandNavy,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          fixedSize: const Size.fromHeight(48),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final created = await Navigator.push<TagType>(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const TagTypeManagerPage()),
                          );
                          if (created != null) {
                            setState(() {
                              _tagTypes.add(created);
                              _selectedTagType = created;
                            });
                            await _saveTagTypes();
                          }
                        },
                        icon: const Icon(Icons.memory),
                        label: const Text('Create New Chip'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: _brandNavy,
                          shape: const StadiumBorder(),
                          fixedSize: const Size.fromHeight(48),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _isWriting ? null : _writeToTag,
                        child: _isWriting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Write To Tag'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
