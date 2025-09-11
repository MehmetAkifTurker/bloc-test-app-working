// import 'dart:developer';
// import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';
// import 'package:flutter/material.dart';
// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/bottom_navigation.dart';

// class TagWriteScreen extends StatefulWidget {
//   const TagWriteScreen({Key? key}) : super(key: key);

//   @override
//   _TagWriteScreenState createState() => _TagWriteScreenState();
// }

// class _TagWriteScreenState extends State<TagWriteScreen> {
//   final TextEditingController serialNumberController = TextEditingController();
//   String _selectedPN = "D0002-00-00"; // default part number (no fixed limit)
//   bool _isWriting = false;
//   bool _isConnected = false;

//   @override
//   void initState() {
//     super.initState();
//     _checkIfConnected();
//   }

//   Future<void> _checkIfConnected() async {
//     log("TagWriteScreen: Checking if RFID is already connected...");
//     final bool? alreadyConnected = await RfidC72Plugin.isConnected;
//     if (alreadyConnected == true) {
//       log("TagWriteScreen: Device is already connected!");
//       setState(() => _isConnected = true);
//     } else {
//       log("TagWriteScreen: Not connected; attempting to connect...");
//       final bool? connectResult = await RfidC72Plugin.connect;
//       if (connectResult == true) {
//         log("TagWriteScreen: Connected successfully!");
//         setState(() => _isConnected = true);
//       } else {
//         log("TagWriteScreen: Failed to connect.");
//       }
//     }
//   }

//   Future<void> _writeToTag() async {
//     if (!_isConnected) {
//       _showSnackBar("Not connected to the reader. Try again.");
//       return;
//     }
//     final String partNumber = _selectedPN.trim().toUpperCase();
//     final String serialNumber =
//         serialNumberController.text.trim().toUpperCase();

//     // Basic validations (you can remove these if you want no limit)
//     if (partNumber.isEmpty || serialNumber.isEmpty) {
//       _showSnackBar("Please enter both Part Number and Serial Number.");
//       return;
//     }
//     if (partNumber.length > 32) {
//       _showSnackBar("Part Number is too long (max 32 chars).");
//       return;
//     }
//     if (serialNumber.length > 30) {
//       _showSnackBar("Serial Number is too long (max 30 chars).");
//       return;
//     }

//     try {
//       setState(() => _isWriting = true);
//       // Call the plugin's writeTagADIConstruct2 method.
//       // The plugin will perform variable‑length encoding internally.
//       final bool? success = await RfidC72Plugin.writeTagADIConstruct2(
//         partNumber,
//         serialNumber,
//       );
//       if (success == true) {
//         _showSnackBar("Tag write successful!");
//       } else {
//         _showSnackBar("Tag write failed. Check logs for details.");
//       }
//     } catch (e) {
//       log("TagWriteScreen: Exception while writing: $e");
//       _showSnackBar("Error writing to tag: $e");
//     } finally {
//       setState(() => _isWriting = false);
//     }
//   }

//   void _showSnackBar(String message) {
//     ScaffoldMessenger.of(context)
//         .showSnackBar(SnackBar(content: Text(message)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: commonAppBar(context, 'RFID Writing Screen'),
//       bottomNavigationBar: bottomNavigationBar(context),
//       body: Padding(
//         padding: const EdgeInsets.all(10.0),
//         child: Column(
//           children: [
//             const Text(
//               'Select Part Number and Enter Serial Number',
//               style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
//               textAlign: TextAlign.center,
//             ),
//             DropdownButtonFormField<String>(
//               value: _selectedPN,
//               decoration: const InputDecoration(labelText: "Part Number"),
//               items: const [
//                 DropdownMenuItem(
//                   value: "D0002-00-00",
//                   child: Text("D0002-00-00"),
//                 ),
//                 DropdownMenuItem(
//                   value: "D0002-00-01",
//                   child: Text("D0002-00-01"),
//                 ),
//               ],
//               onChanged: (String? newValue) {
//                 if (newValue != null) {
//                   setState(() => _selectedPN = newValue);
//                 }
//               },
//             ),
//             TextFormField(
//               controller: serialNumberController,
//               decoration: const InputDecoration(
//                 hintText: 'Serial Number (e.g., SN00001)',
//               ),
//             ),
//             const SizedBox(height: 20),
//             ElevatedButton(
//               onPressed: _isWriting ? null : _writeToTag,
//               child: _isWriting
//                   ? const SizedBox(
//                       width: 24,
//                       height: 24,
//                       child: CircularProgressIndicator(
//                         color: Colors.white,
//                         strokeWidth: 2,
//                       ),
//                     )
//                   : const Text('Write EPC'),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
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
  FilterOption(18, 'Experimental (“flight test”) equip.'),
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

class TagWriteScreen extends StatefulWidget {
  const TagWriteScreen({Key? key}) : super(key: key);

  @override
  _TagWriteScreenState createState() => _TagWriteScreenState();
}

class _TagWriteScreenState extends State<TagWriteScreen> {
  final TextEditingController serialNumberController =
      TextEditingController(text: "SN00001");
  final TextEditingController manufacturerController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController manufactureDateController =
      TextEditingController();
  String _selectedPN = "D0002-00-00";
  String _selectedManufacturer = "TG424";
  static const double _menuMaxHeight = 260.0;
  static const BoxConstraints _iconButtonConstraints =
      BoxConstraints.tightFor(width: 40, height: 40);
  static const EdgeInsets _iconButtonPadding = EdgeInsets.zero;
  static const Color _brandNavy = Color(0xFF003B5C);

  int _selectedFilter = 14;
  DateTime? _pickedDate;
  // SharedPreferences key'leri
  static const _kPnListKey = 'pn_list';
  static const _kMfrListKey = 'manufacturer_list';
  static const _kProdListKey = 'product_name_list';
  static const _kTagTypesKey = 'tag_types';

  // SharedPreferences key
  static const _kDescListKey = 'item_description_list';

// Kalıcı “Item Description” listesi
  List<String> _descList = ["WATER BOILER"]; // varsayılan örnek
  String _selectedDesc = "WATER BOILER";

// Kalıcı listeler (varsayılanlarla başla)
  List<String> _pnList = ["D0002-00-00", "D0002-00-01"];
  List<String> _mfrList = ["TG424"];
  List<String> _prodList = ["WATER BOILER"];

  String get manufactureDateFormatted {
    final date = _pickedDate ?? DateTime.now(); // default = bugün
    return "${date.year.toString().padLeft(4, '0')}"
        "${date.month.toString().padLeft(2, '0')}"
        "${date.day.toString().padLeft(2, '0')}";
  }

  TagType? _selectedTagType;
  final List<TagType> _tagTypes = [
    TagType(
      name: 'Default DRT',
      recordType: 'DRT',
      epcWords: 12,
      userWords: 32,
      permalockWords: 8,
      defaultFilter: 14,
    ),
  ];

  bool _isWriting = false;
  bool _isConnected = false;

  Future<void> _loadTagTypes() async {
    final sp = await SharedPreferences.getInstance();
    final rawList = sp.getStringList(_kTagTypesKey);
    if (rawList != null && rawList.isNotEmpty) {
      _tagTypes
        ..clear()
        ..addAll(rawList.map((s) => TagType.fromJson(jsonDecode(s))));
      _selectedTagType ??= _tagTypes.first;
      _selectedFilter = _selectedTagType!.defaultFilter; // NEW
      if (mounted) setState(() {});
    }
    // boşsa en az 1 varsayılan kalsın
    if (_tagTypes.isEmpty) {
      _tagTypes.add(TagType(
        name: 'Default DRT',
        recordType: 'DRT',
        epcWords: 12,
        userWords: 32,
        permalockWords: 8,
        defaultFilter: 14,
      ));
    }
    // seçili değer ayarla
    _selectedTagType ??= _tagTypes.first;
    if (mounted) setState(() {});
  }

  Future<void> _saveTagTypes() async {
    final sp = await SharedPreferences.getInstance();
    final rawList = _tagTypes.map((t) => jsonEncode(t.toJson())).toList();
    await sp.setStringList(_kTagTypesKey, rawList);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadTagTypes();
      await _loadDropdownData();
      await _checkIfConnected();
    });
  }

  Future<void> _loadDropdownData() async {
    final sp = await SharedPreferences.getInstance();

    _pnList = sp.getStringList(_kPnListKey) ?? _pnList;
    _mfrList = sp.getStringList(_kMfrListKey) ?? _mfrList;
    _prodList = sp.getStringList(_kProdListKey) ?? _prodList;
    _descList = sp.getStringList(_kDescListKey) ?? _descList;

    // seçili değerler listenin içinde mi, değilse ilk elemana düzelt
    if (!_pnList.contains(_selectedPN)) _selectedPN = _pnList.first;
    if (!_mfrList.contains(_selectedManufacturer))
      _selectedManufacturer = _mfrList.first;
    if (!_descList.contains(_selectedDesc)) _selectedDesc = _descList.first;

    if (mounted) setState(() {});
  }

  Future<void> _saveList(String key, List<String> list) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(key, list);
  }

// Ekle diyalogu
  Future<void> _addItemDialog({
    required String title,
    required String key,
    required List<String> target,
    required void Function(String newVal) onSelected,
  }) async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Enter value'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, ctrl.text.trim().toUpperCase()),
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

// Sil diyalogu
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
      builder: (_) => AlertDialog(
        title: Text('Remove $title'),
        content: Text('Delete "$selected"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
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
    log("TagWriteScreen: Checking if RFID is already connected...");
    final bool? alreadyConnected = await RfidC72Plugin.isConnected;
    if (alreadyConnected == true) {
      log("TagWriteScreen: Device is already connected!");
      setState(() => _isConnected = true);
    } else {
      log("TagWriteScreen: Not connected; attempting to connect...");
      final bool? connectResult = await RfidC72Plugin.connect;
      if (connectResult == true) {
        log("TagWriteScreen: Connected successfully!");
        setState(() => _isConnected = true);
      } else {
        log("TagWriteScreen: Failed to connect.");
      }
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
    // final String manufacturer =
    //     manufacturerController.text.trim().toUpperCase();
    // final String productName = productNameController.text.trim().toUpperCase();
    // final String manufactureDate =
    //     manufactureDateController.text.trim().toUpperCase();

    if (partNumber.isEmpty || serialNumber.isEmpty) {
      _showSnackBar("Please enter both Part Number and Serial Number.");
      return;
    }
    if (partNumber.length > 32) {
      _showSnackBar("Part Number is too long (max 32 chars).");
      return;
    }
    if (serialNumber.length > 30) {
      _showSnackBar("Serial Number is too long (max 30 chars).");
      return;
    }

    try {
      setState(() => _isWriting = true);

      // Write to EPC first
      // final bool? epcSuccess = await RfidC72Plugin.writeTagADIConstruct2(
      //   partNumber,
      //   serialNumber,
      // );

      final t = _selectedTagType ??
          TagType(
            name: 'Default DRT',
            recordType: 'DRT',
            epcWords: 12,
            userWords: 32,
            permalockWords: 8,
            defaultFilter: 14,
          );

      await RfidC72Plugin.configureChipAta(
        recordType: t.recordType, // 'DRT', 'SRT-B', 'SRT-U', 'MRT'...
        epcWords: t.epcWords,
        userWords: t.userWords,
        permalockWords: t.permalockWords,
        enablePermalock: false, // istersen yazımdan sonra true yaparsın
        lockEpc:
            false, // EPC/USER kilitlemeyi yazım başarı sonrası yapman daha güvenli
        lockUser: false,
        accessPwd: '00000000',
      );
      final epcSuccess = await RfidC72Plugin.programConstruct2Epc(
            partNumber: partNumber,
            serialNumber: serialNumber,
            manager: " TG424",
            accessPwd: "00000000",
            filter: _selectedFilter,
          ) ??
          false;

      // Then write to User Memory

      final bool? userMemSuccess =
          await RfidC72Plugin.writeAtaUserMemoryWithPayload(
        _selectedManufacturer,
        _selectedDesc, // productName (Item Description)  ✅

        _selectedPN,
        serialNumber,
        manufactureDateFormatted,
      );

      if (epcSuccess == true && userMemSuccess == true) {
        _showSnackBar("EPC and User Memory write successful!");
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

  Future<bool> _goHome() async {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    return false; // bu sayfayı pop etme
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // geri eylemini biz yöneteceğiz
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // Navigator zaten pop ettiyse dokunma
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      },
      child: Scaffold(
        appBar: commonAppBar(context, 'TAG WRITER', showBack: true),
        // bottomNavigationBar: bottomNavigationBar(context),
        body: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: const InputDecorationTheme(
                labelStyle:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                floatingLabelStyle:
                    TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
            child: ListView(
              children: [
                // Top action removed; moved near bottom next to Write To Tag
                // const Text(
                //   'Select Part Number and Enter Serial Number',
                //   style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                //   textAlign: TextAlign.center,
                // ),
                // DropdownButtonFormField<TagType>(
                //   value: _selectedTagType ??
                //       (_tagTypes.isNotEmpty ? _tagTypes.first : null),
                //   decoration: const InputDecoration(labelText: 'Tag Type'),
                //   items: _tagTypes
                //       .map((t) =>
                //           DropdownMenuItem(value: t, child: Text(t.toString())))
                //       .toList(),
                //   onChanged: (v) => setState(() => _selectedTagType = v),
                // ),
                // const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<TagType>(
                        value: _selectedTagType ??
                            (_tagTypes.isNotEmpty ? _tagTypes.first : null),
                        decoration:
                            const InputDecoration(labelText: 'Tag Type'),
                        isDense: true,
                        menuMaxHeight: _menuMaxHeight,
                        items: _tagTypes
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text(t.toString())))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedTagType = v;
                          _selectedFilter =
                              v?.defaultFilter ?? _selectedFilter; // NEW
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
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
                    IconButton(
                      tooltip: 'Remove Tag Type',
                      icon: const Icon(Icons.delete_outline),
                      constraints: _iconButtonConstraints,
                      padding: _iconButtonPadding,
                      onPressed: () async {
                        if (_tagTypes.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('At least one Tag Type must remain')),
                          );
                          return;
                        }
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Remove Tag Type'),
                            content:
                                Text('Delete "${_selectedTagType?.name}"?'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
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
                  ],
                ),
                const SizedBox(height: 12),

                // DropdownButtonFormField<String>(
                //   value: _selectedPN,
                //   decoration: const InputDecoration(labelText: "Part Number"),
                //   items: const [
                //     DropdownMenuItem(
                //       value: "D0002-00-00",
                //       child: Text("D0002-00-00"),
                //     ),
                //     DropdownMenuItem(
                //       value: "D0002-00-01",
                //       child: Text("D0002-00-01"),
                //     ),
                //   ],
                //   onChanged: (String? newValue) {
                //     if (newValue != null) {
                //       setState(() => _selectedPN = newValue);
                //     }
                //   },
                // ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPN,
                        decoration:
                            const InputDecoration(labelText: "Part Number"),
                        isDense: true,
                        menuMaxHeight: _menuMaxHeight,
                        items: _pnList
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedPN = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
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
                    IconButton(
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
                  ],
                ),

                TextFormField(
                  controller: serialNumberController,
                  decoration: const InputDecoration(
                    // hintText: 'Serial Number (e.g., SN00001)',
                    labelText: 'Serial Number',
                  ),
                ),
                // DropdownButtonFormField<String>(
                //   value: _selectedManufacturer,
                //   decoration: const InputDecoration(labelText: "Manufacturer"),
                //   items: const [
                //     DropdownMenuItem(
                //       value: "TG424",
                //       child: Text("Turkish Technic Inc."),
                //     ),
                //   ],
                //   onChanged: (String? newValue) {
                //     if (newValue != null) {
                //       setState(() => _selectedManufacturer = newValue);
                //     }
                //   },
                // ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedManufacturer,
                        menuMaxHeight: _menuMaxHeight,
                        decoration:
                            const InputDecoration(labelText: "Manufacturer"),
                        isDense: true,
                        items: _mfrList
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedManufacturer = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
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
                    IconButton(
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
                  ],
                ),
                const SizedBox(height: 12),
                // --- Item Description (User Memory) ---
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedDesc,
                        menuMaxHeight: _menuMaxHeight,
                        decoration: const InputDecoration(
                            labelText: "Item Description"),
                        isDense: true,
                        items: _descList
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedDesc = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
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
                    IconButton(
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
                  ],
                ),
                const SizedBox(height: 12),

                // DropdownButtonFormField<String>(
                //   value: _selectedProductName,
                //   decoration: const InputDecoration(labelText: "Product Name"),
                //   items: const [
                //     DropdownMenuItem(
                //       value: "WATER BOILER",
                //       child: Text("WATER BOILER"),
                //     ),
                //   ],
                //   onChanged: (String? newValue) {
                //     if (newValue != null) {
                //       setState(() => _selectedProductName = newValue);
                //     }
                //   },
                // ),
                // Row(
                //   children: [
                //     Expanded(
                //       child: DropdownButtonFormField<String>(
                //         value: _selectedProductName,
                //         decoration:
                //             const InputDecoration(labelText: "Product Name"),
                //         items: _prodList
                //             .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                //             .toList(),
                //         onChanged: (v) => setState(() => _selectedProductName = v!),
                //       ),
                //     ),
                //     const SizedBox(width: 8),
                //     IconButton(
                //       tooltip: 'Add Product',
                //       icon: const Icon(Icons.add),
                //       onPressed: () => _addItemDialog(
                //         title: 'Add Product Name',
                //         key: _kProdListKey,
                //         target: _prodList,
                //         onSelected: (nv) => _selectedProductName = nv,
                //       ),
                //     ),
                //     IconButton(
                //       tooltip: 'Remove Product',
                //       icon: const Icon(Icons.delete_outline),
                //       onPressed: () => _removeSelectedDialog(
                //         title: 'Product Name',
                //         key: _kProdListKey,
                //         target: _prodList,
                //         selected: _selectedProductName,
                //         onSelected: (nv) => _selectedProductName = nv,
                //       ),
                //     ),
                //   ],
                // ),
                DropdownButtonFormField<int>(
                  value: _selectedFilter,
                  decoration:
                      const InputDecoration(labelText: 'ATA EPC Filter'),
                  isDense: true,
                  isExpanded: true,
                  alignment: AlignmentDirectional.centerStart,
                  menuMaxHeight: _menuMaxHeight, // ~5 satır
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
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _pickedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        _pickedDate = picked;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller:
                          TextEditingController(text: manufactureDateFormatted),
                      decoration: const InputDecoration(
                        hintText: 'Manufacture Date (e.g., 20240601)',
                        labelText: 'Manufacture Date',
                      ),
                    ),
                  ),
                ),
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
