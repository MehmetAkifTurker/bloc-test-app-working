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

  final w0hex = hex.substring(0, 4); // DSFID per writer
  final w1hex =
      hex.substring(4, 8); // Short ToC header (major/minor/class/type)
  final w2 = hex.substring(8, 12);
  final w3 = hex.substring(12, 16);
  final payloadHex = hex.substring(16);

  // Decode header from w1 according to writer mapping:
  // w1 = [15..13 minor][12..9 major][8..5 tagType][4..0 ataClass]
  final w1 = int.parse(w1hex, radix: 16);
  final tocMinor = (w1 >> 13) & 0x7;
  final tocMajor = (w1 >> 9) & 0xF;
  final tagType = (w1 >> 5) & 0xF;
  final ataClass = (w1) & 0x1F;

  final payloadBin = _hexToBinary(payloadHex);
  final sb = StringBuffer();
  for (int i = 0; i + 6 <= payloadBin.length; i += 6) {
    final c = payloadBin.substring(i, i + 6);
    if (c == '000000') break; // explicit terminator only
    final ch = ASCII6_MAP[c] ?? '?';
    sb.write(ch);
  }

  final payloadText = sb.toString().trimRight();

  return {
    'w0': w0hex,
    'w1': w1hex,
    'w2': w2,
    'w3': w3,
    'tocMajor': tocMajor,
    'tocMinor': tocMinor,
    'ataClass': ataClass,
    'tagType': tagType,
    'payloadText': payloadText,
  };
}
