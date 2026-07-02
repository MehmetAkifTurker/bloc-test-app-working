// lib/core/ata_spec/epc_decoder.dart
//
// ATA Spec 2000 EPC Memory Decoder
// Decodes EPC data from RFID tags according to ATA Spec 2000

import 'six_bit_ascii.dart';

/// Decoded EPC data structure
class DecodedEpcData {
  final String headerBits;
  final int filterValue;
  final String cage;
  final String partNumber;
  final String serialNumber;

  const DecodedEpcData({
    required this.headerBits,
    required this.filterValue,
    required this.cage,
    required this.partNumber,
    required this.serialNumber,
  });

  /// Check if this is an ATA Spec 2000 compliant EPC (header = 0x3B)
  bool get isAtaCompliant => headerBits == '00111011';

  /// Get header as hex
  String get headerHex {
    final val = int.tryParse(headerBits, radix: 2) ?? 0;
    return val.toRadixString(16).toUpperCase().padLeft(2, '0');
  }

  @override
  String toString() {
    return 'EPC(cage: $cage, pn: $partNumber, sn: $serialNumber, filter: $filterValue)';
  }
}

/// Decode EPC hex string to structured data
/// 
/// EPC Format (ATA Spec 2000):
/// - Bits 0-7: Header (0x3B for ATA compliant)
/// - Bits 8-13: Filter value (6 bits, 0-63)
/// - Bits 14-49: CAGE code (6 chars * 6 bits = 36 bits)
/// - Remaining: Part Number + NUL + Serial Number + NUL
DecodedEpcData decodeEpc(String epcHex) {
  try {
    final bin = hexToBinary(epcHex);

    // Ensure we have enough bits for basic ATA structure
    if (bin.length < 50) {
      throw Exception('EPC too short for ATA SPEC format');
    }

    final headerBits = bin.substring(0, 8);

    // HATA #9 FIX: Header must be 0x3B (00111011) for ATA compliance
    if (headerBits != '00111011') {
      throw Exception('Invalid EPC header: expected 0x3B (00111011), got $headerBits');
    }

    final filterBits = bin.substring(8, 14);
    final filterVal = int.parse(filterBits, radix: 2);

    // HATA #11 FIX: Filter value must be in range 0-63 (6-bit constraint)
    if (filterVal < 0 || filterVal > 63) {
      throw Exception('Invalid filter value: $filterVal (must be 0-63)');
    }

    int p = 14;

    // CAGE: 6 char * 6 bit (36 bits total)
    if (p + 36 > bin.length) {
      throw Exception('EPC too short for CAGE field');
    }
    final cageBits = bin.substring(p, p + 36);
    p += 36;

    String pnBits = '';
    String snBits = '';
    bool delim = false;

    // PN and SN are separated by NUL (000000), ends with NUL
    while (p + 6 <= bin.length) {
      final chunk = bin.substring(p, p + 6);
      p += 6;

      if (chunk == '000000') {
        if (!delim) {
          delim = true; // PN ended, SN starts
          continue;
        } else {
          break; // SN ended
        }
      }

      if (!delim) {
        pnBits += chunk;
      } else {
        snBits += chunk;
      }
    }

    // HATA #12 FIX: NUL terminator boundary check
    if (p < bin.length && (p + 6 > bin.length)) {
      throw Exception('Incomplete 6-bit sequence: ${bin.length - p} bits remaining (NUL terminator missing)');
    }

    return DecodedEpcData(
      headerBits: headerBits,
      filterValue: filterVal,
      cage: decode6BitString(cageBits),
      partNumber: decode6BitString(pnBits),
      serialNumber: decode6BitString(snBits),
    );
  } catch (e) {
    // HATA #14 FIX: Throw exception instead of returning fake data
    throw FormatException('EPC decode failed: ${e.toString()}');
  }
}

/// Check if EPC hex is ATA Spec 2000 compliant
bool isAtaCompliantEpc(String epcHex) {
  if (epcHex.length < 2) return false;
  final header = epcHex.substring(0, 2).toUpperCase();
  return header == '3B';
}

/// Extract filter value from EPC without full decode
int? extractFilterValue(String epcHex) {
  try {
    if (epcHex.length < 4) return null;
    final bin = hexToBinary(epcHex.substring(0, 4));
    if (bin.length < 14) return null;
    final filterBits = bin.substring(8, 14);
    return int.parse(filterBits, radix: 2);
  } catch (_) {
    return null;
  }
}

