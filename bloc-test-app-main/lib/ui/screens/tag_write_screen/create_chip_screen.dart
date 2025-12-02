// import 'package:flutter/material.dart';

// /// Basit model
// class TagType {
//   final String name;
//   final String recordType; // DRT | SRT
//   final int epcWords; // EPC bank size (words)
//   final int userWords; // USER bank size (words)
//   final int permalockWords;
//   final int defaultFilter; // 0..63 (şimdilik bu sayfada göstermiyoruz)

//   TagType({
//     required this.name,
//     required this.recordType,
//     required this.epcWords,
//     required this.userWords,
//     required this.permalockWords,
//     required this.defaultFilter,
//   });

//   Map<String, dynamic> toJson() => {
//         'name': name,
//         'recordType': recordType,
//         'epcWords': epcWords,
//         'userWords': userWords,
//         'permalockWords': permalockWords,
//         'defaultFilter': defaultFilter,
//       };

//   factory TagType.fromJson(Map<String, dynamic> json) => TagType(
//         name: json['name'],
//         recordType: json['recordType'],
//         epcWords: json['epcWords'],
//         userWords: json['userWords'],
//         permalockWords: json['permalockWords'],
//         defaultFilter: json['defaultFilter'],
//       );

//   @override
//   String toString() => '$name • $recordType';
// }

// class TagTypeManagerPage extends StatefulWidget {
//   const TagTypeManagerPage({super.key});

//   @override
//   State<TagTypeManagerPage> createState() => _TagTypeManagerPageState();
// }

// class _TagTypeManagerPageState extends State<TagTypeManagerPage> {
//   final _form = GlobalKey<FormState>();
//   final _name = TextEditingController(text: 'My Tag Type');

//   // Sadece kısaltmalar (DRT/SRT)
//   String _recordType = 'DRT';

//   // Slider değerleri (words)
//   int _epcWords = 12; // ör: 12 word
//   int _userWords = 32; // ör: 32 word

//   // Metin girişi bırakıyoruz (istersen slider’a çevirebiliriz)
//   final _permalock = TextEditingController(text: '8');

//   // Bu sayfada göstermiyoruz; yazma ekranında kullanılacak
//   static const int _defaultFilterFallback = 14;

//   @override
//   void dispose() {
//     _name.dispose();
//     _permalock.dispose();
//     super.dispose();
//   }

//   void _save() {
//     if (!_form.currentState!.validate()) return;

//     final tagType = TagType(
//       name: _name.text.trim(),
//       recordType: _recordType, // 'DRT' ya da 'SRT'
//       epcWords: _epcWords, // slider
//       userWords: _userWords, // slider
//       permalockWords: int.parse(_permalock.text.trim()),
//       defaultFilter:
//           _defaultFilterFallback, // şimdilik sabit; yazma sayfasında değiştirilecektir
//     );
//     Navigator.pop(context, tagType); // oluşturulan tipi geri döndür
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Create Tag Type')),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: Form(
//             key: _form,
//             child: ListView(
//               children: [
//                 // İsim
//                 TextFormField(
//                   controller: _name,
//                   decoration: const InputDecoration(labelText: 'Name'),
//                   validator: (v) =>
//                       (v == null || v.trim().isEmpty) ? 'Name required' : null,
//                 ),
//                 const SizedBox(height: 12),

//                 // Record Type (DRT / SRT)
//                 DropdownButtonFormField<String>(
//                   value: _recordType,
//                   decoration: const InputDecoration(labelText: 'Record Type'),
//                   items: const [
//                     DropdownMenuItem(
//                         value: 'DRT', child: Text('Dual Record Type (DRT)')),
//                     DropdownMenuItem(
//                         value: 'SRT', child: Text('Single Record Type (SRT)')),
//                   ],
//                   onChanged: (v) => setState(() => _recordType = v ?? 'DRT'),
//                 ),
//                 const SizedBox(height: 12),

//                 // EPC Size (Slider)
//                 Text(
//                   'EPC Size: $_epcWords words',
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 Slider(
//                   value: _epcWords.toDouble(),
//                   min: 8,
//                   max: 64,
//                   divisions: 56, // 8..64 arası her adım 1 word
//                   label: _epcWords.toString(),
//                   onChanged: (v) => setState(() => _epcWords = v.toInt()),
//                 ),
//                 const SizedBox(height: 8),

//                 // USER Size (Slider)
//                 Text(
//                   'USER Size: $_userWords words',
//                   style: const TextStyle(fontWeight: FontWeight.w600),
//                 ),
//                 Slider(
//                   value: _userWords.toDouble(),
//                   min: 8,
//                   max: 128,
//                   divisions: 120, // 8..128 arası
//                   label: _userWords.toString(),
//                   onChanged: (v) => setState(() => _userWords = v.toInt()),
//                 ),
//                 const SizedBox(height: 12),

//                 // Permalock (şimdilik TextField)
//                 TextFormField(
//                   controller: _permalock,
//                   keyboardType: TextInputType.number,
//                   decoration: const InputDecoration(
//                     labelText: 'Block Permalock (words)',
//                   ),
//                   validator: _posInt,
//                 ),

//                 const SizedBox(height: 20),
//                 FilledButton.icon(
//                   onPressed: _save,
//                   icon: const Icon(Icons.save),
//                   label: const Text('Save'),
//                 ),
//                 const SizedBox(height: 8),

//                 // Not
//                 const Text(
//                   'Note:\n'
//                   '• Filter değeri bu sayfada gizlendi; Tag Write ekranında seçilecektir.\n'
//                   '• DRT/SRT kısaltmaları kullanılıyor. Gerekirse ileride MRT vb. eklenebilir.\n'
//                   '• EPC/USER boyutları kaydırıcı ile ayarlanır (words).',
//                   style: TextStyle(fontSize: 12, color: Colors.grey),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   String? _posInt(String? v) {
//     if (v == null || v.trim().isEmpty) return 'Required';
//     final n = int.tryParse(v.trim());
//     if (n == null || n <= 0) return 'Positive integer';
//     return null;
//   }
// }
import 'package:flutter/material.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

/// Mevcut model (değiştirmedik)
class TagType {
  final String name;
  final String recordType; // DRT | SRT
  final int epcWords;
  final int userWords;
  final int permalockWords;
  final int defaultFilter;

  TagType({
    required this.name,
    required this.recordType,
    required this.epcWords,
    required this.userWords,
    required this.permalockWords,
    required this.defaultFilter,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'recordType': recordType,
        'epcWords': epcWords,
        'userWords': userWords,
        'permalockWords': permalockWords,
        'defaultFilter': defaultFilter,
      };

  factory TagType.fromJson(Map<String, dynamic> json) => TagType(
        name: json['name'],
        recordType: json['recordType'],
        epcWords: json['epcWords'],
        userWords: json['userWords'],
        permalockWords: json['permalockWords'],
        defaultFilter: json['defaultFilter'],
      );

  @override
  String toString() => '$name • $recordType';
}

class ChipKind {
  final String id;
  final String name;

  /// EPC için izin verilen en fazla bit
  final int epcMaxBits;

  /// USER için izin verilen en fazla bit
  final int userMaxBits;
  const ChipKind(this.id, this.name,
      {required this.epcMaxBits, required this.userMaxBits});

  int get epcMaxWords => (epcMaxBits / 16).floor();
  int get userMaxWords => (userMaxBits / 16).floor();
}

/// İsterseniz kendi ürün listenize göre burayı genişletin
const List<ChipKind> kChipKinds = [
  // Örnekler:
  ChipKind('64k', '64 kbit',
      epcMaxBits: 240, userMaxBits: 64 * 1024), // İstediğiniz gibi
  ChipKind('8k', '8 kbit', epcMaxBits: 240, userMaxBits: 8 * 1024),
  ChipKind('2k', '2 kbit', epcMaxBits: 240, userMaxBits: 2 * 1024),
  ChipKind('512b', '512 bit', epcMaxBits: 240, userMaxBits: 512),
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
  static const int _kUserMax = 128;

  ChipKind _chip = kChipKinds.first;

  /// Kaydırıcıların dinamik üst sınırları (words)
  int get _epcMaxDyn => _chip.epcMaxWords.clamp(_kEpcMin, _kEpcMax);
  int get _userMaxDyn => _chip.userMaxWords.clamp(_kUserMin, _kUserMax);

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'My Tag Type');

  // STid ekranlarındaki gibi: SRT (Birth) / SRT (Utility) / DRT / MRT
  String _recordTypeUi = 'DRT'; // UI etiketi
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
  int _userWords = 64;

  final _permalock = TextEditingController(text: '12');
  bool _applyPermalock = true;

  bool _lockEpc = false;
  bool _lockUser = false;
  
  // Helper: Apply recommended settings when record type changes
  void _applyRecommendedSettings(String recordType) {
    switch (recordType) {
      case 'DRT':
        _epcWords = 12;
        _userWords = 64; // Birth(~20) + Lifecycle(~30) + overhead(~10)
        _permalock.text = '12'; // ToC(4) + RDs(4) + partial Birth(4)
        _applyPermalock = true;
        break;
      case 'SRT (Birth)':
        _epcWords = 12;
        _userWords = 16; // Küçük birth data için yeterli
        _permalock.text = '16'; // Tümünü lock et
        _applyPermalock = true;
        break;
      case 'SRT (Utility)':
        _epcWords = 12;
        _userWords = 16;
        _permalock.text = '0'; // Hiç lock etme (rewritable)
        _applyPermalock = false;
        break;
      case 'MRT':
        _epcWords = 12;
        _userWords = 128; // Maksimum (çok history için)
        _permalock.text = '20'; // ToC + RDs + Birth
        _applyPermalock = true;
        break;
    }
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
      recordType: _recordTypeKey, // SRT-B / SRT-U / DRT / MRT
      epcWords: _epcWords,
      userWords: _userWords,
      permalockWords: _userWords == 0 ? 0 : _permalockVal,
      defaultFilter: 14, // bu ekranda filtre yok; yazma ekranında seçiliyor
    );
    Navigator.pop(context, tagType);
  }

  Future<void> _createOnReader() async {
    if (!_form.currentState!.validate()) return;

    final ok = await RfidC72Plugin.configureChipAta(
      recordType: _recordTypeKey,
      epcWords: _epcWords,
      userWords: _userWords,
      permalockWords: _userWords == 0 ? 0 : _permalockVal,
      enablePermalock: _applyPermalock && _userWords > 0 && _permalockVal > 0,
      lockEpc: _lockEpc,
      lockUser: _lockUser,
      accessPwd: '00000000', // gerekirse değiştir
    );

    final msg = (ok == true)
        ? 'Chip pre-allocation/lock operation successful.'
        : 'Operation failed (configureChipAta returned false).';
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
    
    // Record type specific warnings
    if (_recordTypeUi == 'DRT' && n < 8) {
      return 'DRT requires minimum 8 words (ToC + RDs)';
    }
    if (_recordTypeUi == 'DRT' && n > _userWords - 20) {
      return 'DRT: leave space for Lifecycle (max ${_userWords - 20})';
    }
    return null;
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: ListView(
              children: [
                TextFormField(
                  controller: _name,
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
                DropdownButtonFormField<ChipKind>(
                  value: _chip,
                  decoration:
                      const InputDecoration(labelText: 'Chip Type / Memory'),
                  menuMaxHeight: 260,
                  items: kChipKinds
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                                '${c.name}  •  EPC≤${c.epcMaxBits} bits, USER≤${c.userMaxBits} bits'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _chip = v;

                      // Seçim değişince mevcut değerleri yeni sınırlara sıkıştır
                      if (_epcWords > _epcMaxDyn) _epcWords = _epcMaxDyn;
                      if (_userWords > _userMaxDyn) _userWords = _userMaxDyn;

                      // Permalock değeri USER’a taşsın diye kontrol
                      if (_permalockVal > _userWords) {
                        _permalock.text = '$_userWords';
                      }
                    });
                  },
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
                    value: _epcWords.toDouble(),
                    min: _kEpcMin.toDouble(),
                    max: _epcMaxDyn.toDouble(),
                    divisions: (_epcMaxDyn - _kEpcMin).clamp(1, 1000),
                    label: _epcWords.toString(),
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
                    value: _userWords.toDouble(),
                    min: _kUserMin.toDouble(),
                    max: _userMaxDyn.toDouble(), // ⬅ dinamik
                    divisions: (_userMaxDyn - _kUserMin).clamp(1, 1000),
                    label: _userWords.toString(),
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
                        const SizedBox(height: 4),
                        const Text(
                          'Permalock: Permanently locks specified word range (cannot be unlocked!).\n'
                          '• DRT: ToC + RDs + Birth locked, Lifecycle remains open\n'
                          '• SRT (Birth): All data locked\n'
                          '• SRT (Utility): Not locked (rewritable)',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
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
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Lock EPC (after creation)'),
                  value: _lockEpc,
                  activeColor: _brandNavy,
                  activeTrackColor: _brandNavy.withOpacity(.35),
                  onChanged: (v) => setState(() => _lockEpc = v),
                ),
                SwitchListTile(
                  title: const Text('Lock USER (after creation)'),
                  value: _lockUser,
                  activeColor: _brandNavy,
                  activeTrackColor: _brandNavy.withOpacity(.35),
                  onChanged: (v) => setState(() => _lockUser = v),
                ),
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
                          '📋 Recommended Settings',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        _buildRecommendationRow('DRT', '64 words USER, 12 permalock'),
                        _buildRecommendationRow('SRT (Birth)', '16 words USER, 16 permalock (all)'),
                        _buildRecommendationRow('SRT (Utility)', '16 words USER, 0 permalock'),
                        _buildRecommendationRow('MRT', '128 words USER, 20 permalock'),
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
    );
  }
}
