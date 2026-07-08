// Create Chip Screen - ATA Spec 2000 Tag Type Configuration
import 'package:flutter/material.dart';
import 'package:rfid_manager/ui/router/app_bar.dart';

/// Tag Type model for chip configuration
class TagType {
  final String name;
  final String recordType; // DRT | SRT-B | SRT-U | MRT
  final int epcWords;
  final int userWords;
  final int permalockWords;
  final int defaultFilter;
  final bool isBuiltIn; // Built-in presets cannot be deleted
  final bool enablePermalock; // Apply Block Permalock on write (off for SRT-U)

  TagType({
    required this.name,
    required this.recordType,
    required this.epcWords,
    required this.userWords,
    required this.permalockWords,
    required this.defaultFilter,
    this.isBuiltIn = false,
    this.enablePermalock = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'recordType': recordType,
        'epcWords': epcWords,
        'userWords': userWords,
        'permalockWords': permalockWords,
        'defaultFilter': defaultFilter,
        'isBuiltIn': isBuiltIn,
        'enablePermalock': enablePermalock,
      };

  factory TagType.fromJson(Map<String, dynamic> json) => TagType(
        name: json['name'],
        recordType: json['recordType'],
        epcWords: json['epcWords'],
        userWords: json['userWords'],
        permalockWords: json['permalockWords'],
        defaultFilter: json['defaultFilter'],
        isBuiltIn: json['isBuiltIn'] ?? false,
        enablePermalock: json['enablePermalock'] ?? true,
      );

  @override
  String toString() => '$name • $recordType';
}

/// Built-in presets per ATA Spec 2000 - cannot be deleted
const List<Map<String, dynamic>> kBuiltInTagTypes = [
  {
    'name': 'DRT Standard',
    'recordType': 'DRT',
    'epcWords': 12,
    'userWords': 128,
    'permalockWords': 12,
    'defaultFilter': 14,
    'isBuiltIn': true,
    'enablePermalock': true,
  },
  {
    'name': 'SRT Birth (Read-Only)',
    'recordType': 'SRT-B',
    'epcWords': 12,
    'userWords': 32,
    'permalockWords': 32,
    'defaultFilter': 14,
    'isBuiltIn': true,
    'enablePermalock': true,
  },
  {
    // "Rewritable" — must stay unlocked. enablePermalock MUST be false here;
    // it defaults to true (see fromJson), which made a write on this preset
    // report "permalocked!" even though 0 words were actually locked.
    'name': 'SRT Utility (Rewritable)',
    'recordType': 'SRT-U',
    'epcWords': 12,
    'userWords': 32,
    'permalockWords': 0,
    'defaultFilter': 14,
    'isBuiltIn': true,
    'enablePermalock': false,
  },
  {
    'name': 'MRT Multi-Record',
    'recordType': 'MRT',
    'epcWords': 12,
    'userWords': 512,
    'permalockWords': 20,
    'defaultFilter': 14,
    'isBuiltIn': true,
    'enablePermalock': true,
  },
];

/// Chip memory configuration
class ChipKind {
  final String id;
  final String name;
  final int epcMaxBits;
  final int userMaxBits;
  final String useCase;

  const ChipKind(
    this.id,
    this.name, {
    required this.epcMaxBits,
    required this.userMaxBits,
    required this.useCase,
  });

  int get epcMaxWords => (epcMaxBits / 16).floor();
  int get userMaxWords => (userMaxBits / 16).floor();
}

/// Available chip memory configurations (powers of 2)
/// Sorted by USER memory size (largest first)
const List<ChipKind> kChipKinds = [
  // Large memory - for MRT
  ChipKind(
    '4096w',
    '64 Kbit (4096 words)',
    epcMaxBits: 256,
    userMaxBits: 65536, // 64 kbit = 4096 words
    useCase: 'MRT - Multi Record',
  ),
  
  // Medium memory - for DRT
  ChipKind(
    '1024w',
    '16 Kbit (1024 words)',
    epcMaxBits: 256,
    userMaxBits: 16384, // 16 kbit = 1024 words
    useCase: 'DRT - Large',
  ),
  ChipKind(
    '512w',
    '8 Kbit (512 words)',
    epcMaxBits: 256,
    userMaxBits: 8192, // 8 kbit = 512 words
    useCase: 'DRT - Standard',
  ),
  ChipKind(
    '256w',
    '4 Kbit (256 words)',
    epcMaxBits: 256,
    userMaxBits: 4096, // 4 kbit = 256 words
    useCase: 'DRT - Compact',
  ),
  ChipKind(
    '128w',
    '2 Kbit (128 words)',
    epcMaxBits: 256,
    userMaxBits: 2048, // 2 kbit = 128 words
    useCase: 'DRT - Minimum',
  ),
  
  // Small memory - for SRT only
  ChipKind(
    '64w',
    '1 Kbit (64 words)',
    epcMaxBits: 256,
    userMaxBits: 1024, // 1 kbit = 64 words
    useCase: 'SRT - Large',
  ),
  ChipKind(
    '32w',
    '512 bit (32 words)',
    epcMaxBits: 256,
    userMaxBits: 512, // 512 bit = 32 words
    useCase: 'SRT - Standard',
  ),
];

class TagTypeManagerPage extends StatefulWidget {
  const TagTypeManagerPage({super.key});

  @override
  State<TagTypeManagerPage> createState() => _TagTypeManagerPageState();
}

class _TagTypeManagerPageState extends State<TagTypeManagerPage> {
  static const Color _brandNavy = Color(0xFF003B5C);
  static const int _kEpcMin = 8;
  static const int _kEpcMax = 64;
  static const int _kUserMin = 0;
  static const int _kUserMax = 1024; // ATA Spec: DRT max 2 Kbyte = 1024 words

  ChipKind _chip = kChipKinds.first;
  
  /// Get suitable chip options based on record type
  /// ATA Spec 2000 Requirements:
  /// - SRT: 32-128 words (512-2048 bits)
  /// - DRT: 128-1024 words (2048-16384 bits)
  /// - MRT: 4096+ words (65536+ bits)
  List<ChipKind> get _suitableChips {
    switch (_recordTypeUi) {
      case 'SRT (Birth)':
      case 'SRT (Utility)':
        // SRT needs 32-128 words
        return kChipKinds.where((c) => 
          c.userMaxWords >= 32 && c.userMaxWords <= 128
        ).toList();
      case 'DRT':
        // DRT needs 128-1024 words
        return kChipKinds.where((c) => 
          c.userMaxWords >= 128 && c.userMaxWords <= 1024
        ).toList();
      case 'MRT':
        // MRT needs 4096+ words
        return kChipKinds.where((c) => c.userMaxWords >= 4096).toList();
      default:
        return kChipKinds;
    }
  }
  
  /// Get recommended chip for current record type
  ChipKind get _recommendedChip {
    final suitable = _suitableChips;
    if (suitable.isEmpty) return kChipKinds.first;
    
    switch (_recordTypeUi) {
      case 'SRT (Birth)':
      case 'SRT (Utility)':
        // Prefer 32 words for SRT (minimum required)
        return suitable.last;
      case 'DRT':
        // Prefer 128 words for DRT (minimum required)
        return suitable.firstWhere(
          (c) => c.id == '128w',
          orElse: () => suitable.last,
        );
      case 'MRT':
        // MRT needs largest chip
        return suitable.first;
      default:
        return suitable.first;
    }
  }

  int get _epcMaxDyn => _chip.epcMaxWords.clamp(_kEpcMin, _kEpcMax);
  int get _userMaxDyn => _chip.userMaxWords.clamp(_kUserMin, _kUserMax);

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'My Tag Type');

  String _recordTypeUi = 'DRT';
  String get _recordTypeKey {
    switch (_recordTypeUi) {
      case 'SRT (Birth)':
        return 'SRT-B';
      case 'SRT (Utility)':
        return 'SRT-U';
      case 'MRT':
        return 'MRT';
      case 'DRT':
      default:
        return 'DRT';
    }
  }

  int _epcWords = 12;
  int _userWords = 128; // ATA Spec: DRT minimum 128 words

  final _permalock = TextEditingController(text: '12');
  bool _applyPermalock = true;

  // ATA Spec 2000 Memory Requirements:
  // SRT (Utility/Birth): 512 bits - 2k bits = 32-128 words
  // DRT: 2k bits - 2 Kbyte = 128-1024 words  
  // MRT: 8k bytes+ = 4096+ words
  void _applyRecommendedSettings(String recordType) {
    int targetUserWords;
    int targetPermalock;
    bool enablePermalock;
    
    switch (recordType) {
      case 'DRT':
        targetUserWords = 128;
        targetPermalock = 12;
        enablePermalock = true;
        break;
      case 'SRT (Birth)':
        targetUserWords = 32;
        targetPermalock = 32;
        enablePermalock = true;
        break;
      case 'SRT (Utility)':
        targetUserWords = 32;
        targetPermalock = 0;
        enablePermalock = false;
        break;
      case 'MRT':
        targetUserWords = 512;
        targetPermalock = 20;
        enablePermalock = true;
        break;
      default:
        targetUserWords = 128;
        targetPermalock = 12;
        enablePermalock = true;
    }
    
    // Select recommended chip for this record type
    _chip = _recommendedChip;
    
    // Clamp to chip capacity
    _epcWords = 12.clamp(_kEpcMin, _epcMaxDyn);
    _userWords = targetUserWords.clamp(_kUserMin, _userMaxDyn);
    _permalock.text = targetPermalock.clamp(0, _userWords).toString();
    _applyPermalock = enablePermalock;
  }

  @override
  void initState() {
    super.initState();
    // Clamp initial values to chip capacity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _epcWords = _epcWords.clamp(_kEpcMin, _epcMaxDyn);
        _userWords = _userWords.clamp(_kUserMin, _userMaxDyn);
        if (_permalockVal > _userWords) {
          _permalock.text = '$_userWords';
        }
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _permalock.dispose();
    super.dispose();
  }

  int get _permalockVal => int.tryParse(_permalock.text.trim()) ?? 0;

  void _saveOnly() {
    if (!_form.currentState!.validate()) return;
    final tagType = TagType(
      name: _name.text.trim(),
      recordType: _recordTypeKey,
      epcWords: _epcWords,
      userWords: _userWords,
      permalockWords: _userWords == 0 ? 0 : _permalockVal,
      defaultFilter: 14,
      enablePermalock: _applyPermalock,
    );
    Navigator.pop(context, tagType);
  }

  String? _validateName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Name required' : null;

  String? _validatePermalock(String? v) {
    if (!_applyPermalock || _userWords == 0) return null;
    if (v == null || v.trim().isEmpty) return 'Required';
    final n = int.tryParse(v.trim());
    if (n == null) return 'Numeric';
    if (n < 0) return 'Must be ≥ 0';
    if (n > _userWords) return 'Cannot exceed USER size ($_userWords)';
    if (_recordTypeUi == 'DRT' && n < 8) {
      return 'DRT requires minimum 8 words (ToC + RDs)';
    }
    if (_recordTypeUi == 'DRT' && n > _userWords - 20) {
      return 'DRT: leave space for Lifecycle (max ${_userWords - 20})';
    }
    return null;
  }

  /// Builds record type specific UI settings
  List<Widget> _buildRecordTypeSpecificSettings(bool permEnabled) {
    final isUtility = _recordTypeUi == 'SRT (Utility)';
    final isBirth = _recordTypeUi == 'SRT (Birth)';
    
    // SRT (Utility) - No locking, fully rewritable
    if (isUtility) {
      return [
        Card(
          color: Colors.green.shade50,
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✏️ Rewritable Tag',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'SRT (Utility) tags are fully rewritable.\n'
                  '• No permalock will be applied\n'
                  '• Data can be updated anytime\n'
                  '• Suitable for temporary/changeable data',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    
    // SRT (Birth) - All data locked, no configuration needed
    if (isBirth) {
      return [
        Card(
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '🔒 Fully Locked Tag',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  'SRT (Birth) tags are fully permalocked.\n'
                  '• All $_userWords words will be permanently locked\n'
                  '• Data cannot be modified after creation\n'
                  '• Suitable for factory-original identity data',
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action is PERMANENT and cannot be undone!',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ];
    }
    
    // DRT and MRT - Full configuration options
    return [
      Card(
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🔒 Permalock Settings',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Permalock permanently locks specified word range (CANNOT be unlocked!).',
                style: TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildPermalockExplanation(),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        title: const Text('Enable Permalock'),
        subtitle: Text(permEnabled
            ? 'First $_permalockVal words will be locked'
            : 'Disabled - no area will be locked'),
        value: _applyPermalock,
        activeColor: _brandNavy,
        activeTrackColor: _brandNavy.withOpacity(.35),
        onChanged: (val) => setState(() => _applyPermalock = val),
      ),
      TextFormField(
        controller: _permalock,
        enabled: permEnabled,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Permalock Range (words)',
          helperText: permEnabled
              ? 'Word 0 to ${_permalockVal - 1} will be locked'
              : null,
          helperMaxLines: 2,
        ),
        validator: _validatePermalock,
      ),
    ];
  }

  Widget _buildPermalockExplanation() {
    // Dynamic explanation based on selected record type
    final isUtility = _recordTypeUi == 'SRT (Utility)';
    final isBirth = _recordTypeUi == 'SRT (Birth)';
    final isMrt = _recordTypeUi == 'MRT';
    
    if (isUtility) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SRT (Utility): No permalock needed',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
          SizedBox(height: 4),
          Text('• Utility records are rewritable by design\n'
               '• Used for temporary/updatable data',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      );
    }
    
    if (isBirth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('SRT (Birth): All data permalocked',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 4),
          Text('• All $_userWords words will be locked\n'
               '• Birth data is immutable (factory original)',
              style: const TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      );
    }
    
    if (isMrt) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MRT: ToC + Birth permalocked, History open',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
          SizedBox(height: 4),
          Text('• Word 0-1: ToC Header (DSFID, Tag Type, Size)\n'
               '• Word 2-5: Record Descriptors (RD1-RD2)\n'
               '• Word 6-19: Birth Record (~14 words)\n'
               '• Word 20+: CDR/PHR records (rewritable)',
              style: TextStyle(fontSize: 11, color: Colors.black54)),
        ],
      );
    }
    
    // DRT explanation (default)
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DRT: Why 12 words permalocked?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
        SizedBox(height: 4),
        Text('ATA Spec 2000 Memory Layout:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        SizedBox(height: 2),
        Text('• Word 0-1: ToC Header (DSFID, Tag Type, Size)\n'
             '• Word 2-3: RD1 - Lifecycle Record Descriptor\n'
             '• Word 4-5: RD2 - Birth Record Descriptor\n'
             '• Word 6-11: Birth Record start (Type, Size, MFR, PNR...)',
            style: TextStyle(fontSize: 11, color: Colors.black54)),
        SizedBox(height: 4),
        Text('Total: 12 words locked = Birth protected, Lifecycle open',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green)),
      ],
    );
  }

  Widget _buildRecommendationRow(String type, String settings) {
    final isSelected = _recordTypeUi == type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isSelected ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            '$type: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Expanded(
            child: Text(
              settings,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final permEnabled = _applyPermalock && _userWords > 0;

    return Scaffold(
      appBar: commonAppBar(
        context,
        'CREATE TAG TYPE',
        showBack: true,
        onBack: () {
          Navigator.pushNamedAndRemoveUntil(context, '/write', (r) => false);
        },
      ),
      body: SafeArea(
        child: Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              primary: _brandNavy,
              secondary: _brandNavy,
            ),
            inputDecorationTheme: InputDecorationTheme(
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _brandNavy, width: 2),
              ),
              floatingLabelStyle: const TextStyle(color: _brandNavy),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _form,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _name,
                    cursorColor: _brandNavy,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g., Galley Equip V1',
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _recordTypeUi,
                    decoration: const InputDecoration(labelText: 'Record Type'),
                    menuMaxHeight: 260,
                  items: const [
                    DropdownMenuItem(
                      value: 'DRT',
                      child: Text('Dual-Record (Birth + Lifecycle)'),
                    ),
                    DropdownMenuItem(
                      value: 'SRT (Birth)',
                      child: Text('Single Birth (Locked, Read-only)'),
                    ),
                    DropdownMenuItem(
                      value: 'SRT (Utility)',
                      child: Text('Single Utility (Rewritable)'),
                    ),
                    DropdownMenuItem(
                      value: 'MRT',
                      child: Text('Multi-Record (Birth + History)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _recordTypeUi = v;
                      _applyRecommendedSettings(v);
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Show only suitable chips for selected record type
                if (_suitableChips.length > 1)
                  DropdownButtonFormField<ChipKind>(
                    value: _suitableChips.contains(_chip) ? _chip : _suitableChips.first,
                    decoration: InputDecoration(
                      labelText: 'Memory Size',
                      helperText: '${_suitableChips.length} options for $_recordTypeUi',
                      helperStyle: TextStyle(fontSize: 11, color: Colors.green.shade700),
                    ),
                    isExpanded: true,
                    menuMaxHeight: 320,
                    items: _suitableChips
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text('${c.name} - ${c.useCase}'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _chip = v;
                        if (_epcWords > _epcMaxDyn) _epcWords = _epcMaxDyn;
                        if (_userWords > _userMaxDyn) _userWords = _userMaxDyn;
                        if (_permalockVal > _userWords) {
                          _permalock.text = '$_userWords';
                        }
                      });
                    },
                  )
                else if (_suitableChips.isNotEmpty)
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.memory, color: _brandNavy),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _suitableChips.first.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _suitableChips.first.useCase,
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Card(
                    color: Colors.red.shade50,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No compatible memory size for this record type',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text('EPC Size: $_epcWords words',
                    style: theme.textTheme.titleMedium),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _brandNavy,
                    inactiveTrackColor: _brandNavy.withOpacity(.2),
                    thumbColor: _brandNavy,
                    overlayColor: _brandNavy.withOpacity(.1),
                  ),
                  child: Slider(
                    value: _epcWords.clamp(_kEpcMin, _epcMaxDyn).toDouble(),
                    min: _kEpcMin.toDouble(),
                    max: _epcMaxDyn.toDouble(),
                    divisions: (_epcMaxDyn - _kEpcMin).clamp(1, 1000),
                    label: _epcWords.clamp(_kEpcMin, _epcMaxDyn).toString(),
                    onChanged: (v) => setState(() => _epcWords = v.toInt()),
                  ),
                ),
                Text('USER Size: $_userWords words',
                    style: theme.textTheme.titleMedium),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _brandNavy,
                    inactiveTrackColor: _brandNavy.withOpacity(.2),
                    thumbColor: _brandNavy,
                    overlayColor: _brandNavy.withOpacity(.1),
                  ),
                  child: Slider(
                    value: _userWords.clamp(_kUserMin, _userMaxDyn).toDouble(),
                    min: _kUserMin.toDouble(),
                    max: _userMaxDyn.toDouble(),
                    divisions: (_userMaxDyn - _kUserMin).clamp(1, 1000),
                    label: _userWords.clamp(_kUserMin, _userMaxDyn).toString(),
                    onChanged: (v) {
                      setState(() {
                        _userWords = v.toInt();
                        if (_permalockVal > _userWords) {
                          _permalock.text = '$_userWords';
                        }
                      });
                    },
                  ),
                ),
                // Dynamic content based on record type
                ..._buildRecordTypeSpecificSettings(permEnabled),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _brandNavy,
                          shape: const StadiumBorder(),
                          fixedSize: const Size.fromHeight(48),
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: _saveOnly,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Type'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  color: Colors.grey.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📋 ATA Spec 2000 Requirements',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        _buildRecommendationRow(
                            'DRT', '128+ words (2k bits min), 12 permalock'),
                        _buildRecommendationRow(
                            'SRT (Birth)', '32-128 words, all permalocked'),
                        _buildRecommendationRow(
                            'SRT (Utility)', '32-128 words, 0 permalock'),
                        _buildRecommendationRow(
                            'MRT', '512+ words (8k bytes min), 20 permalock'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Note: Filter value is selected in Tag Write screen. '
                  'This screen only configures ATA-compliant memory pre-allocation and locking.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
