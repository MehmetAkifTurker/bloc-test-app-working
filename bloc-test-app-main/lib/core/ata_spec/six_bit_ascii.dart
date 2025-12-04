// lib/core/ata_spec/six_bit_ascii.dart
//
// ATA Spec 2000 6-bit ASCII Codec
// Encoding and decoding for ATA Spec 2000 compliant data

/// 6-bit ASCII Map for ATA Spec 2000 encoding
/// Maps 6-bit binary strings to characters
const Map<String, String> kAscii6Map = {
  '000000': 'NUL',
  '000001': 'A', '000010': 'B', '000011': 'C',
  '000100': 'D', '000101': 'E', '000110': 'F',
  '000111': 'G', '001000': 'H', '001001': 'I',
  '001010': 'J', '001011': 'K', '001100': 'L',
  '001101': 'M', '001110': 'N', '001111': 'O',
  '010000': 'P', '010001': 'Q', '010010': 'R',
  '010011': 'S', '010100': 'T', '010101': 'U',
  '010110': 'V', '010111': 'W', '011000': 'X',
  '011001': 'Y', '011010': 'Z',
  '011011': '[', '011100': '\\', '011101': ']',
  '011110': '^', '011111': '_',
  '110000': '0', '110001': '1', '110010': '2',
  '110011': '3', '110100': '4', '110101': '5',
  '110110': '6', '110111': '7', '111000': '8',
  '111001': '9',
  '111111': '?',
  '100000': ' ',
  '100001': '!',
  '100011': '#', '100100': '\$', '100101': '%',
  '100110': '&', '100111': "'",
  '101000': '(', '101001': ')', '101010': '*',
  '101011': '+', '101100': ',', '101101': '-',
  '101110': '.', '101111': '/',
  '111010': ':', '111011': ';', '111100': '<',
  '111101': '=', '111110': '>',
};

/// Reverse map for encoding (char -> 6-bit binary)
final Map<String, String> kAscii6Reverse = {
  for (final e in kAscii6Map.entries)
    if (e.value != 'NUL') e.value: e.key,
};

/// Convert hex string to binary string
String hexToBinary(String hexValue) {
  final buffer = StringBuffer();
  for (int i = 0; i < hexValue.length; i++) {
    final nibble = int.parse(hexValue[i], radix: 16);
    buffer.write(nibble.toRadixString(2).padLeft(4, '0'));
  }
  return buffer.toString();
}

/// Convert binary string to hex string
String binaryToHex(String binary) {
  final buffer = StringBuffer();
  // Pad to multiple of 4
  final padded = binary.padLeft((binary.length + 3) ~/ 4 * 4, '0');
  for (int i = 0; i < padded.length; i += 4) {
    final nibble = int.parse(padded.substring(i, i + 4), radix: 2);
    buffer.write(nibble.toRadixString(16).toUpperCase());
  }
  return buffer.toString();
}

/// Decode 6-bit encoded string to ASCII
String decode6BitString(String bits) {
  final sb = StringBuffer();
  for (int i = 0; i + 6 <= bits.length; i += 6) {
    final chunk = bits.substring(i, i + 6);
    final char = kAscii6Map[chunk] ?? '?';
    if (char == 'NUL') continue;
    sb.write(char);
  }
  return sb.toString();
}

/// Encode ASCII string to 6-bit binary
String encode6BitString(String text) {
  final buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final char = text[i].toUpperCase();
    final bits = kAscii6Reverse[char] ?? '111111'; // '?' for unknown
    buffer.write(bits);
  }
  return buffer.toString();
}

/// Decode hex string to 6-bit ASCII text
String hexTo6BitAscii(String hex) {
  if (hex.isEmpty) return '';
  final binary = hexToBinary(hex);
  return decode6BitString(binary);
}

/// Encode ASCII text to hex string using 6-bit encoding
String ascii6BitToHex(String text) {
  if (text.isEmpty) return '';
  final binary = encode6BitString(text);
  return binaryToHex(binary);
}

/// Decode hex string to 8-bit ASCII text
String hexToAscii8Bit(String hex) {
  if (hex.isEmpty) return '';
  final sb = StringBuffer();
  for (int i = 0; i + 2 <= hex.length; i += 2) {
    final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (byte == null) continue;
    if (byte >= 32 && byte < 127) {
      sb.write(String.fromCharCode(byte));
    } else if (byte == 0) {
      // NUL terminator - stop decoding
      break;
    }
  }
  return sb.toString();
}

/// Encode ASCII text to hex string using 8-bit encoding
String ascii8BitToHex(String text) {
  final buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final code = text.codeUnitAt(i);
    buffer.write(code.toRadixString(16).padLeft(2, '0').toUpperCase());
  }
  return buffer.toString();
}

