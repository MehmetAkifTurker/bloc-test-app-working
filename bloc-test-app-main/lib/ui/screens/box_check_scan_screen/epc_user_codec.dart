// // lib/rfid/codec/epc_user_codec.dart
// library epc_user_codec;

// /// --- HEX <-> BİNARY yardımcıları ---
// String _hexToBinary(String hexValue) {
//   final buffer = StringBuffer();
//   for (int i = 0; i < hexValue.length; i++) {
//     final nibble = int.parse(hexValue[i], radix: 16);
//     buffer.write(nibble.toRadixString(2).padLeft(4, '0'));
//   }
//   return buffer.toString();
// }

// /// 6-bit ASCII tablo (ATA Spec 2000 tarzı)
// const Map<String, String> ASCII6_MAP = {
//   "000000": "NUL",
//   "000001": "A",
//   "000010": "B",
//   "000011": "C",
//   "000100": "D",
//   "000101": "E",
//   "000110": "F",
//   "000111": "G",
//   "001000": "H",
//   "001001": "I",
//   "001010": "J",
//   "001011": "K",
//   "001100": "L",
//   "001101": "M",
//   "001110": "N",
//   "001111": "O",
//   "010000": "P",
//   "010001": "Q",
//   "010010": "R",
//   "010011": "S",
//   "010100": "T",
//   "010101": "U",
//   "010110": "V",
//   "010111": "W",
//   "011000": "X",
//   "011001": "Y",
//   "011010": "Z",
//   "011011": "[",
//   "011100": "\\",
//   "011101": "]",
//   "011110": "^",
//   "011111": "_",
//   "110000": "0",
//   "110001": "1",
//   "110010": "2",
//   "110011": "3",
//   "110100": "4",
//   "110101": "5",
//   "110110": "6",
//   "110111": "7",
//   "111000": "8",
//   "111001": "9",
//   "111111": "?",
//   "100001": "!",
//   "100011": "#",
//   "100100": "\$",
//   "100101": "%",
//   "100110": "&",
//   "100111": "'",
//   "101000": "(",
//   "101001": ")",
//   "101010": "*",
//   "101011": "+",
//   "101100": ",",
//   "101101": "-",
//   "101110": ".",
//   "101111": "/",
//   "111010": ":",
//   "111011": ";",
//   "111100": "<",
//   "111101": "=",
//   "111110": ">",
//   "100000": " "
// };

// String _decodeSixBitString(String bits) {
//   final sb = StringBuffer();
//   for (int i = 0; i + 6 <= bits.length; i += 6) {
//     final chunk = bits.substring(i, i + 6);
//     final char = ASCII6_MAP[chunk] ?? "?";
//     if (char == "NUL") continue;
//     sb.write(char);
//   }
//   return sb.toString();
// }

// /// --- EPC Decode ---
// class DecodedEpcData {
//   final String headerBits;
//   final int filterValue;
//   final String cage;
//   final String partNumber;
//   final String serialNumber;

//   DecodedEpcData({
//     required this.headerBits,
//     required this.filterValue,
//     required this.cage,
//     required this.partNumber,
//     required this.serialNumber,
//   });
// }

// DecodedEpcData decodeEpc(String epcHex) {
//   final binary = _hexToBinary(epcHex);
//   final headerBits = binary.substring(0, 8);
//   final filterBits = binary.substring(8, 14);
//   final filterVal = int.parse(filterBits, radix: 2);
//   int pointer = 14;

//   // CAGE: 6 char * 6 bit = 36 bit
//   final cageBits = binary.substring(pointer, pointer + 36);
//   pointer += 36;

//   String pnBits = "";
//   bool delimiterDetected = false;
//   String snBits = "";

//   // PN ve SN arası 000000 ayırıcılarla ayrılıyor
//   while (pointer + 6 <= binary.length) {
//     final chunk = binary.substring(pointer, pointer + 6);
//     pointer += 6;
//     if (chunk == "000000") {
//       if (!delimiterDetected) {
//         delimiterDetected = true;
//         continue;
//       } else {
//         break;
//       }
//     }
//     if (!delimiterDetected) {
//       pnBits += chunk;
//     } else {
//       snBits += chunk;
//     }
//   }

//   final cageAscii = _decodeSixBitString(cageBits);
//   final pnAscii = _decodeSixBitString(pnBits);
//   final snAscii = _decodeSixBitString(snBits);

//   return DecodedEpcData(
//     headerBits: headerBits,
//     filterValue: filterVal,
//     cage: cageAscii,
//     partNumber: pnAscii,
//     serialNumber: snAscii,
//   );
// }

// /// --- USER MEMORY Decode (Header + 6-bit Payload) ---
// Map<String, dynamic> decodeUserMemory(String userMemoryHex) {
//   if (userMemoryHex.isEmpty || userMemoryHex.length < 16) return {};

//   final w0 = userMemoryHex.substring(0, 4);
//   final w1hex = userMemoryHex.substring(4, 8);
//   final w2 = userMemoryHex.substring(8, 12);
//   final w3 = userMemoryHex.substring(12, 16);
//   final payloadHex = userMemoryHex.substring(16);

//   final w1 = int.parse(w1hex, radix: 16);
//   final tocMajor = (w1 >> 12) & 0xF;
//   final tocMinor = (w1 >> 9) & 0x7;
//   final ataClass = (w1 >> 4) & 0x1F;
//   final tagType = w1 & 0xF;

//   final payloadBin = _hexToBinary(payloadHex);
//   final sb = StringBuffer();
//   for (int i = 0; i + 6 <= payloadBin.length; i += 6) {
//     final chunk = payloadBin.substring(i, i + 6);
//     if (chunk == '000000') break; // terminator
//     sb.write(ASCII6_MAP[chunk] ?? '?');
//   }

//   return {
//     'w0': w0,
//     'w1': w1hex,
//     'w2': w2,
//     'w3': w3,
//     'tocMajor': tocMajor,
//     'tocMinor': tocMinor,
//     'ataClass': ataClass,
//     'tagType': tagType,
//     'payloadText': sb.toString(),
//   };
// }
// lib/ui/screens/box_check_scan_screen/epc_user_codec.dart
library epc_user_codec;

import 'dart:math' as math;

/// ============== HEX <-> BINARY ==============
String _hexToBinary(String hexValue) {
  final b = StringBuffer();
  for (int i = 0; i < hexValue.length; i++) {
    final n = int.parse(hexValue[i], radix: 16);
    b.write(n.toRadixString(2).padLeft(4, '0'));
  }
  return b.toString();
}

/// ============== 6-bit ASCII (ATA Spec benzeri) ==============
const Map<String, String> ASCII6_MAP = {
  "000000": "NUL",
  "000001": "A",
  "000010": "B",
  "000011": "C",
  "000100": "D",
  "000101": "E",
  "000110": "F",
  "000111": "G",
  "001000": "H",
  "001001": "I",
  "001010": "J",
  "001011": "K",
  "001100": "L",
  "001101": "M",
  "001110": "N",
  "001111": "O",
  "010000": "P",
  "010001": "Q",
  "010010": "R",
  "010011": "S",
  "010100": "T",
  "010101": "U",
  "010110": "V",
  "010111": "W",
  "011000": "X",
  "011001": "Y",
  "011010": "Z",
  "011011": "[",
  "011100": "\\",
  "011101": "]",
  "011110": "^",
  "011111": "_",
  "110000": "0",
  "110001": "1",
  "110010": "2",
  "110011": "3",
  "110100": "4",
  "110101": "5",
  "110110": "6",
  "110111": "7",
  "111000": "8",
  "111001": "9",
  "111111": "?",
  "100001": "!",
  "100011": "#",
  "100100": "\$",
  "100101": "%",
  "100110": "&",
  "100111": "'",
  "101000": "(",
  "101001": ")",
  "101010": "*",
  "101011": "+",
  "101100": ",",
  "101101": "-",
  "101110": ".",
  "101111": "/",
  "111010": ":",
  "111011": ";",
  "111100": "<",
  "111101": "=",
  "111110": ">",
  "100000": " "
};

String _decodeSixBitString(String bits) {
  final sb = StringBuffer();
  for (int i = 0; i + 6 <= bits.length; i += 6) {
    final chunk = bits.substring(i, i + 6);
    final ch = ASCII6_MAP[chunk] ?? "?";
    if (ch != "NUL") sb.write(ch);
  }
  return sb.toString();
}

const Map<int, String> kAtaTagTypeNames = {
  0x0000: 'Multi-Record',
  0x0001: 'Dual-Record',
  0x0002: 'Single Birth Record',
  0x000A: 'Single Utility Record',
};

const Map<int, String> kAtaRecordTypeNames = {
  0x00: 'Birth Record',
  0x01: 'Current Data Record',
  0x02: 'Scratchpad Record',
  0x03: 'Part History Record',
  0x04: 'Lifecycle Record',
};

String _hexWord(int value) =>
    value.toRadixString(16).padLeft(4, '0').toUpperCase();

class AtaTocHeader {
  final int dsfid;
  final int tocMajorVersion;
  final int tocMinorVersion;
  final int ataTagType;
  final int ataClass;
  final int flags;
  final int tocHeaderWords;
  final int recordDescriptorWords;
  final int ataMemoryWords;
  final bool replacementTag;
  final bool timestampIncluded;
  final bool pointer32Bit;
  final bool crcPresent;
  final bool correctedTag;

  AtaTocHeader({
    required this.dsfid,
    required this.tocMajorVersion,
    required this.tocMinorVersion,
    required this.ataTagType,
    required this.ataClass,
    required this.flags,
    required this.tocHeaderWords,
    required this.recordDescriptorWords,
    required this.ataMemoryWords,
    required this.replacementTag,
    required this.timestampIncluded,
    required this.pointer32Bit,
    required this.crcPresent,
    required this.correctedTag,
  });

  factory AtaTocHeader.fromWords(List<int> words) {
    if (words.length < 4) {
      throw ArgumentError('Not enough words for ToC header');
    }
    final dsfid = words[0] & 0xFFFF;
    final w1 = words[1] & 0xFFFF;
    final w2 = words[2] & 0xFFFF;

    final tocMinor = (w1 >> 13) & 0x7;
    final tocMajor = (w1 >> 9) & 0xF;
    final tagType = (w1 >> 5) & 0xF;
    final ataClass = w1 & 0x1F;

    final flags = (w2 >> 8) & 0xFF;
    int tocHeaderWords = (w2 >> 4) & 0xF;
    if (tocHeaderWords == 0) tocHeaderWords = 4;
    int recordDescriptorWords = w2 & 0xF;

    final replacementTag = (flags & 0x01) != 0;
    final timestampIncluded = (flags & 0x02) != 0;
    final pointer32Bit = (flags & 0x04) != 0;
    final crcPresent = (flags & 0x08) != 0;
    final correctedTag = (flags & 0x10) != 0;

    if (pointer32Bit && tocHeaderWords < 5) {
      tocHeaderWords = 5;
    }

    int ataMemoryWords;
    if (pointer32Bit && words.length >= 5) {
      ataMemoryWords = ((words[3] & 0xFFFF) << 16) | (words[4] & 0xFFFF);
    } else {
      ataMemoryWords = words[3] & 0xFFFF;
    }

    return AtaTocHeader(
      dsfid: dsfid,
      tocMajorVersion: tocMajor,
      tocMinorVersion: tocMinor,
      ataTagType: tagType,
      ataClass: ataClass,
      flags: flags,
      tocHeaderWords: tocHeaderWords,
      recordDescriptorWords: recordDescriptorWords,
      ataMemoryWords: ataMemoryWords,
      replacementTag: replacementTag,
      timestampIncluded: timestampIncluded,
      pointer32Bit: pointer32Bit,
      crcPresent: crcPresent,
      correctedTag: correctedTag,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dsfidHex': _hexWord(dsfid),
      'tocMajorVersion': tocMajorVersion,
      'tocMinorVersion': tocMinorVersion,
      'ataTagType': ataTagType,
      'ataTagTypeLabel': kAtaTagTypeNames[ataTagType],
      'ataClass': ataClass,
      'ataClassLabel': ataClassLabel(ataClass),
      'flags': {
        'replacementTag': replacementTag,
        'timestampIncluded': timestampIncluded,
        'pointer32Bit': pointer32Bit,
        'crcPresent': crcPresent,
        'correctedTag': correctedTag,
      },
      'tocHeaderWords': tocHeaderWords,
      'recordDescriptorWords': recordDescriptorWords,
      'ataMemoryWords': ataMemoryWords,
    };
  }
}

class AtaRecordDescriptor {
  final int recordAddress;
  final int recordType;
  final int rawFlags;
  final bool eightBitEncoding;
  final bool correctedBirth;

  AtaRecordDescriptor({
    required this.recordAddress,
    required this.recordType,
    required this.rawFlags,
    required this.eightBitEncoding,
    required this.correctedBirth,
  });

  Map<String, dynamic> toJson() => {
        'recordAddress': recordAddress,
        'recordType': recordType,
        'recordTypeLabel': kAtaRecordTypeNames[recordType],
        'flags': {
          'raw': rawFlags,
          'eightBitEncoding': eightBitEncoding,
          'correctedBirth': correctedBirth,
        },
      };
}

class AtaDecodedRecord {
  final AtaRecordDescriptor descriptor;
  final int sizeWords;
  final String payloadHex;
  final String payloadText;
  final Map<String, String> fields;

  AtaDecodedRecord({
    required this.descriptor,
    required this.sizeWords,
    required this.payloadHex,
    required this.payloadText,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
        'descriptor': descriptor.toJson(),
        'sizeWords': sizeWords,
        'payloadHex': payloadHex,
        'payloadText': payloadText,
        'fields': fields,
      };
}

class _PrioritizedField {
  final String value;
  final int priority;
  _PrioritizedField(this.value, this.priority);
}

int _recordPriority(int recordType) {
  switch (recordType) {
    case 0x00: // Birth Record
      return 0;
    case 0x04: // Lifecycle Record
      return 1;
    case 0x01: // Current Data Record
      return 2;
    case 0x03: // Part History Record
      return 3;
    case 0x02: // Scratchpad
      return 4;
    default:
      return 5;
  }
}

/// ============== Yardımcı: ATA sınıfı adı ==============
String ataClassLabel(int id) {
  const labels = {
    0: "All others",
    1: "Item (general; not 8–63)",
    2: "Carton",
    6: "Pallet",
    8: "Seat Cushions",
    9: "Seat Covers",
    10: "Seat Belts / Belt Ext.",
    11: "Galley & Service Equip.",
    12: "Galley Ovens",
    13: "Aircraft Security Items",
    14: "Life Vests",
    15: "Oxygen Generators",
    16: "Engine & Components",
    17: "Avionics",
    18: "Flight-test Equipment",
    19: "Other Emergency Equipment",
    20: "Other Rotables",
    21: "Other Repairables",
    22: "Other Cabin Interior",
    23: "Other Repair",
    24: "Seat & Seat Components",
    25: "IFE & related",
    56: "Location Identifier",
    57: "Documentation",
    58: "Tools",
    59: "Ground Support Equipment",
    60: "Other Non-Flyable Equipment",
  };
  return labels[id] ?? "-";
}

/// ============== EPC Decode ==============
/// EPC: [8 bit header][6 bit filter][CAGE 6*6][PN ... 000000 ... SN ... 000000]
class DecodedEpcData {
  final String headerBits;
  final int filterValue; // 0..63
  final String cage, partNumber, serialNumber;

  DecodedEpcData({
    required this.headerBits,
    required this.filterValue,
    required this.cage,
    required this.partNumber,
    required this.serialNumber,
  });
}

DecodedEpcData decodeEpc(String epcHex) {
  try {
    final bin = _hexToBinary(epcHex);

    // Ensure we have enough bits for basic ATA structure
    if (bin.length < 50) {
      throw Exception('EPC too short for ATA SPEC format');
    }

    final headerBits = bin.substring(0, 8);
    final filterBits = bin.substring(8, 14);
    final filterVal = int.parse(filterBits, radix: 2);

    int p = 14;

    // CAGE: 6 char * 6 bit (36 bits total)
    if (p + 36 > bin.length) {
      throw Exception('EPC too short for CAGE field');
    }
    final cageBits = bin.substring(p, p + 36);
    p += 36;

    String pnBits = "";
    String snBits = "";
    bool delim = false;

    // PN ve SN arası 000000 ile ayrılır, sonunda yine 000000 gelir
    while (p + 6 <= bin.length) {
      final chunk = bin.substring(p, p + 6);
      p += 6;

      if (chunk == "000000") {
        if (!delim) {
          delim = true; // PN bitti, SN başlıyor
          continue;
        } else {
          break; // SN de bitti
        }
      }

      if (!delim) {
        pnBits += chunk;
      } else {
        snBits += chunk;
      }
    }

    return DecodedEpcData(
      headerBits: headerBits,
      filterValue: filterVal,
      cage: _decodeSixBitString(cageBits),
      partNumber: _decodeSixBitString(pnBits),
      serialNumber: _decodeSixBitString(snBits),
    );
  } catch (e) {
    // Return a default structure for non-compliant or corrupted EPCs
    print('EPC decode error for $epcHex: $e');
    return DecodedEpcData(
      headerBits: '00000000',
      filterValue: 0,
      cage: 'UNKNOWN',
      partNumber: 'DECODE_ERROR',
      serialNumber: epcHex, // Show raw EPC for debugging
    );
  }
}

/// ============== USER MEMORY Decode ==============
/// Not: Bu şemada ToC başlığı w0 içindedir:
/// w0: [15..12 ToC major][11..8 ToC minor][7..3 ATA class][2..0 tag type]
Map<String, dynamic> decodeUserMemory(String hex) {
  if (hex.isEmpty || hex.length < 16) return {};

  final words = <int>[];
  for (int i = 0; i + 4 <= hex.length; i += 4) {
    words.add(int.parse(hex.substring(i, i + 4), radix: 16));
  }

  AtaTocHeader? tocHeader;
  try {
    tocHeader = AtaTocHeader.fromWords(words);
  } catch (_) {}

  int ataMemoryWords = tocHeader?.ataMemoryWords ?? words.length;
  if (ataMemoryWords < 0) ataMemoryWords = 0;
  if (ataMemoryWords > words.length) ataMemoryWords = words.length;
  final List<int> ataWords = words.sublist(0, ataMemoryWords);
  final String ataHex = hex.substring(0, ataMemoryWords * 4);

  int headerWords = tocHeader?.tocHeaderWords ?? 4;
  if (headerWords < 0) headerWords = 0;
  int headerHexLen = headerWords * 4;
  if (headerHexLen < 0) headerHexLen = 0;
  if (headerHexLen > ataHex.length) headerHexLen = ataHex.length;

  const int trailerWords = 2;
  final bool hasTrailer = ataWords.length >= trailerWords;
  final int tocRecordCount =
      hasTrailer ? (ataWords[ataWords.length - 2] & 0xFFFF) : 0;
  final int tocCrc = hasTrailer ? (ataWords.last & 0xFFFF) : 0;

  final int descriptorEntryWords = tocHeader?.recordDescriptorWords ??
      (tocHeader?.pointer32Bit == true ? 3 : 2);
  final bool pointer32Bit = tocHeader?.pointer32Bit ?? false;

  int descriptorWordBudget = ataWords.length - trailerWords - headerWords;
  if (descriptorWordBudget < 0) descriptorWordBudget = 0;
  int descriptorWordCount = 0;
  if (descriptorEntryWords > 0 && descriptorWordBudget > 0) {
    if (tocRecordCount > 0) {
      descriptorWordCount = math.min(
        tocRecordCount * descriptorEntryWords,
        descriptorWordBudget,
      );
    } else {
      descriptorWordCount = descriptorWordBudget;
    }
  }
  final int descriptorHexLen = descriptorWordCount * 4;
  final descriptorHex = descriptorHexLen > 0
      ? ataHex.substring(
          headerHexLen,
          math.min(headerHexLen + descriptorHexLen, ataHex.length),
        )
      : '';

  final payloadStartHex = headerHexLen + descriptorHexLen;
  final payloadEndHex = math.max(0, ataHex.length - trailerWords * 4);
  final payloadHex = payloadStartHex >= payloadEndHex
      ? ''
      : ataHex.substring(payloadStartHex, payloadEndHex);

  String payloadText =
      _normalizePayloadText(_decodeSixBitPayload(payloadHex).trimRight());
  Map<String, String> fields = _parsePayloadFields(payloadText);

  if (fields.isEmpty) {
    final asciiText =
        _normalizePayloadText(_decodeAsciiPayload(payloadHex).trim());
    final asciiFields = _parsePayloadFields(asciiText);
    if (asciiFields.isNotEmpty) {
      payloadText = asciiText;
      fields = asciiFields;
    }
  }

  final List<AtaRecordDescriptor> descriptors = [];
  if (descriptorWordCount > 0 && descriptorEntryWords > 0) {
    final int descriptorStartWord = headerWords;
    final int descriptorAreaEndWord = descriptorStartWord + descriptorWordCount;
    final int maxDescriptors = descriptorWordCount ~/ descriptorEntryWords;
    final int recordLoopCount = tocRecordCount > 0
        ? math.min(tocRecordCount, maxDescriptors)
        : maxDescriptors;

    for (int i = 0; i < recordLoopCount; i++) {
      final int startWord = descriptorStartWord + i * descriptorEntryWords;
      final int endWord = startWord + descriptorEntryWords;

      if (endWord > descriptorAreaEndWord ||
          endWord > ataWords.length - trailerWords) {
        break;
      }

      final seg = ataWords.sublist(startWord, endWord);
      final desc = _parseRecordDescriptor(seg, pointer32Bit);
      if (desc == null) {
        break;
      }

      if (desc.recordAddress <= headerWords ||
          desc.recordAddress >= ataWords.length - trailerWords) {
        break;
      }

      descriptors.add(desc);
    }
  }

  final List<AtaDecodedRecord> decodedRecords = [];
  final Map<String, _PrioritizedField> mergedFields = {};
  if (descriptors.isNotEmpty) {
    // Sort descriptors by record address (high memory records come first)
    final sortedDescriptors = descriptors.toList()
      ..sort((a, b) => a.recordAddress.compareTo(b.recordAddress));

    final List<int> usableWords =
        ataWords.sublist(0, math.max(0, ataWords.length - trailerWords));
    for (final desc in sortedDescriptors) {
      final record = _decodeRecord(
        usableWords,
        desc,
        tocHeader,
        trailerWords,
      );
      if (record.sizeWords == 0 || record.payloadHex.isEmpty) {
        continue;
      }
      decodedRecords.add(record);
      final priority = _recordPriority(desc.recordType);
      record.fields.forEach((key, value) {
        if (value.isEmpty) return;
        final existing = mergedFields[key];
        if (existing == null || priority < existing.priority) {
          mergedFields[key] = _PrioritizedField(value, priority);
        }
      });
    }
    if (mergedFields.isNotEmpty) {
      fields
        ..clear()
        ..addEntries(mergedFields.entries.map(
          (e) => MapEntry(e.key, e.value.value),
        ));
      payloadText = decodedRecords.map((r) => r.payloadText).join('\n');
    }
  }

  return {
    'w0': words.isNotEmpty ? _hexWord(words[0]) : '',
    'w1': words.length > 1 ? _hexWord(words[1]) : '',
    'w2': words.length > 2 ? _hexWord(words[2]) : '',
    'w3': words.length > 3 ? _hexWord(words[3]) : '',
    'recordCount': tocRecordCount,
    'tocCrc': _hexWord(tocCrc),
    'recordDescriptorHex': descriptorHex,
    'payloadHex': payloadHex,
    'rawHexLength': ataHex.length,
    'tocHeader': tocHeader?.toJson(),
    'tocMajor': tocHeader?.tocMajorVersion,
    'tocMinor': tocHeader?.tocMinorVersion,
    'ataClass': tocHeader?.ataClass,
    'tagType': tocHeader?.ataTagType,
    'recordDescriptors': descriptors.map((e) => e.toJson()).toList(),
    'records': decodedRecords.map((e) => e.toJson()).toList(),
    'payloadText': payloadText,
    'fields': fields,
    'ataClassLabel':
        tocHeader != null ? ataClassLabel(tocHeader.ataClass) : null,
    ...fields,
  };
}

AtaRecordDescriptor? _parseRecordDescriptor(
    List<int> descriptorWords, bool pointer32Bit) {
  if (descriptorWords.isEmpty) return null;
  final int pointerWordCount = pointer32Bit ? 2 : 1;
  if (descriptorWords.length < pointerWordCount + 1) return null;

  int recordAddress;
  if (pointer32Bit) {
    recordAddress =
        ((descriptorWords[0] & 0xFFFF) << 16) | (descriptorWords[1] & 0xFFFF);
  } else {
    recordAddress = descriptorWords[0] & 0xFFFF;
  }

  final int typeWord = descriptorWords[pointerWordCount] & 0xFFFF;
  final int recordType = (typeWord >> 8) & 0xFF;
  final int flags = typeWord & 0xFF;

  return AtaRecordDescriptor(
    recordAddress: recordAddress,
    recordType: recordType,
    rawFlags: flags,
    eightBitEncoding: (flags & 0x01) != 0,
    correctedBirth: (flags & 0x02) != 0,
  );
}

AtaDecodedRecord _decodeRecord(
  List<int> words,
  AtaRecordDescriptor descriptor,
  AtaTocHeader? tocHeader,
  int trailerWords,
) {
  const int headerWords = 2;
  const int crcWords = 1;
  const int baseOverhead = headerWords + crcWords;
  const int timestampWords = 2;
  final bool timestampIncluded = tocHeader?.timestampIncluded ?? false;

  final int startWord = descriptor.recordAddress;
  if (startWord < 0 || startWord >= words.length) {
    return AtaDecodedRecord(
      descriptor: descriptor,
      sizeWords: 0,
      payloadHex: '',
      payloadText: '',
      fields: const {},
    );
  }

  final int recordSize =
      startWord < words.length ? (words[startWord] & 0xFFFF) : 0;
  if (recordSize <= baseOverhead || recordSize > (words.length - startWord)) {
    return AtaDecodedRecord(
      descriptor: descriptor,
      sizeWords: 0,
      payloadHex: '',
      payloadText: '',
      fields: const {},
    );
  }
  final int overhead = baseOverhead + (timestampIncluded ? timestampWords : 0);
  int payloadWordCount = recordSize - overhead;
  if (payloadWordCount < 0) payloadWordCount = 0;

  final int payloadStartWord =
      startWord + headerWords + (timestampIncluded ? timestampWords : 0);
  if (payloadStartWord >= words.length) {
    return AtaDecodedRecord(
      descriptor: descriptor,
      sizeWords: recordSize,
      payloadHex: '',
      payloadText: '',
      fields: const {},
    );
  }
  final int recordEndWord = math.min(words.length, startWord + recordSize);
  final int payloadEndWord = math.min(
    payloadStartWord + payloadWordCount,
    math.max(0, recordEndWord - crcWords),
  );
  if (payloadEndWord < payloadStartWord) {
    return AtaDecodedRecord(
      descriptor: descriptor,
      sizeWords: recordSize,
      payloadHex: '',
      payloadText: '',
      fields: const {},
    );
  }

  final payloadWords =
      words.sublist(payloadStartWord, payloadEndWord).map(_hexWord).toList();
  final payloadHex = payloadWords.join();

  final String payloadText;
  if (descriptor.eightBitEncoding) {
    payloadText = _normalizePayloadText(_decodeAsciiPayload(payloadHex).trim());
  } else {
    payloadText =
        _normalizePayloadText(_decodeSixBitPayload(payloadHex).trimRight());
  }
  final payloadFields = _parsePayloadFields(payloadText);

  return AtaDecodedRecord(
    descriptor: descriptor,
    sizeWords: recordSize,
    payloadHex: payloadHex,
    payloadText: payloadText,
    fields: payloadFields,
  );
}

String _decodeAsciiPayload(String hex) {
  final codeUnits = <int>[];
  bool started = false;
  for (int i = 0; i + 2 <= hex.length; i += 2) {
    final byte = int.parse(hex.substring(i, i + 2), radix: 16);
    if (byte == 0) {
      if (!started) continue;
      break;
    }
    started = true;
    codeUnits.add(byte);
  }
  return String.fromCharCodes(codeUnits);
}

String _decodeSixBitPayload(String hex) {
  final payloadBin = _hexToBinary(hex);
  final sb = StringBuffer();
  bool started = false;
  for (int i = 0; i + 6 <= payloadBin.length; i += 6) {
    final c = payloadBin.substring(i, i + 6);
    if (c == '000000') {
      if (!started) continue;
      break;
    }
    started = true;
    final ch = ASCII6_MAP[c] ?? '?';
    sb.write(ch);
  }
  return sb.toString();
}

String _normalizePayloadText(String text) {
  if (text.isEmpty) return text;
  String normalized = text.replaceAll(RegExp(r'[\x00-\x1F]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  return normalized;
}

Map<String, String> _parsePayloadFields(String text) {
  final result = <String, String>{};
  if (text.isEmpty) return result;
  final sanitized = text.replaceAll('\n', ' ');
  final reg = RegExp(r'(?:^|[*!])([A-Z0-9]{3,5})\s+([^*!]+)');
  for (final match in reg.allMatches(sanitized)) {
    final key = match.group(1)?.trim().toUpperCase();
    final rawValue = match.group(2) ?? '';
    final value = rawValue.replaceAll(RegExp(r'[\x00-\x1F]'), ' ').trim();
    if (key == null || key.isEmpty || value.isEmpty) continue;
    result[key] = value;
  }

  void sanitize(String key, RegExp allowed) {
    final current = result[key];
    if (current == null || current.isEmpty) return;
    final match = allowed.firstMatch(current);
    if (match != null) {
      result[key] = match.group(0)!;
    }
  }

  sanitize('PNO', RegExp(r'[0-9A-Z\-./]{1,32}'));
  sanitize('PNR', RegExp(r'[0-9A-Z\-./]{1,32}'));

  return result;
}
