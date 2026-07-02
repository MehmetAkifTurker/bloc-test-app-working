// lib/ui/screens/box_check_scan_screen/ata_constants.dart
//
// ATA Spec 2000 Constants and Mappings
// Common constants used across RFID tag reading, writing, and display

/// ATA Class Names - Equipment categories per ATA Spec 2000
const Map<int, String> kAtaClassNames = {
  0: 'Other',
  1: 'Item (general; not 8–63)',
  2: 'Carton',
  6: 'Pallet',
  8: 'Seat Cushions',
  9: 'Seat Covers',
  10: 'Seat Belts / Belt Ext.',
  11: 'Galley & Service Equip.',
  12: 'Galley Ovens',
  13: 'Aircraft Security Items',
  14: 'Life Vests',
  15: 'Oxygen Generators',
  16: 'Engine & Engine Components',
  17: 'Avionics',
  18: 'Experimental Equip.',
  19: 'Other Emergency Equipment',
  20: 'Other Rotables',
  21: 'Other Repairables',
  22: 'Other Cabin Interior',
  23: 'Other Repair (structural)',
  24: 'Seat & Components',
  25: 'IFE & related',
  56: 'Location Identifier',
  57: 'Documentation',
  58: 'Tools',
  59: 'Ground Support Equipment',
  60: 'Other Non-Flyable Equipment',
};

/// ATA Tag Type Names - Tag memory configurations
const Map<int, String> kAtaTagTypeNames = {
  0x0000: 'Multi-Record',
  0x0001: 'Dual-Record',
  0x0002: 'Single Birth Record',
  0x000A: 'Single Utility Record',
};

/// ATA Record Type Names (per ATA Spec 2000 Record Descriptor, Figure 54:
/// only 0x00-0x04 are defined by the spec).
const Map<int, String> kAtaRecordTypeNames = {
  0x00: 'Birth Record',
  0x01: 'Current Data Record (CDR)',
  0x02: 'User Scratchpad Record',
  0x03: 'Part History Record (PHR)',
  0x04: 'Lifecycle Record',
};

/// Standard TEI field order for display
const List<String> kAtaUserFieldOrder = [
  'MFR', 'CAG', 'SPL', 'SER', 'SEQ', 'UCN',
  'PNR', 'PNO', 'UIC', 'DMF', 'EXP', 'PDT',
  'ESD', 'LLE', 'ICC', 'LOT', 'LTN', 'CNT',
  'WGT', 'UNT', 'HAZ', 'ECC', 'SWI', 'TDN',
  'NSN', 'FAB', 'DOH', 'DNH', 'OVD', 'OMM',
];

/// TEI Field Labels - Human readable names (per ATA Spec 2000 Ch.9 CSDD/Table 3)
const Map<String, String> kAtaUserFieldLabels = {
  'MFR': 'Manufacturer',
  'CAG': 'CAGE Code',
  'SPL': 'Supplier Code',
  'SER': 'Serial Number',
  'SEQ': 'Serial Sequence',
  'UCN': 'Unique Component Number',
  'PNR': 'Part Number (Current)',
  'PNO': 'Part Number (Original)',
  'UIC': 'UID Construct Number',
  'DMF': 'Date of Manufacture',
  'EXP': 'Expiration Date',
  'PDT': 'Part Description',
  'ESD': 'ESD Sensitive Indicator',
  'LLE': 'Life Limited Equipment Indicator',
  'ICC': 'International Commodity Code',
  'LOT': 'Lot/Batch Number',
  'LTN': 'Enterprise Lot Number',
  'CNT': 'Count/Quantity',
  'WGT': 'Weight',
  'UNT': 'Unit of Measure',
  'HAZ': 'Hazardous Material',
  'ECC': 'Equipment Condition',
  'SWI': 'Software Indicator',
  'TDN': 'Certificate Tracking Number',
  'NSN': 'NATO Stock Number',
  'FAB': 'Fabricator (CAGE)',
  'DOH': 'Last Hydrostatic Test Date',
  'DNH': 'Next Hydrostatic Test Date',
  'OVD': 'Overhaul Date',
  'OMM': 'OEM Code (CAGE)',
  'PML': 'Part Modification Level',
};

/// 6-bit ASCII Map for ATA Spec 2000 encoding
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
  '100010': '"', // ASCII 34 double quote (Appendix B Table 25)
  '100011': '#', '100100': '\$', '100101': '%',
  '100110': '&', '100111': "'",
  '101000': '(', '101001': ')', '101010': '*',
  '101011': '+', '101100': ',', '101101': '-',
  '101110': '.', '101111': '/',
  '111010': ':', '111011': ';', '111100': '<',
  '111101': '=', '111110': '>',
};

/// Reverse map for encoding (char -> 6-bit)
final Map<String, String> kAscii6Reverse = {
  for (final e in kAscii6Map.entries)
    if (e.value != 'NUL') e.value: e.key,
};

/// NOTE: ATA Spec 2000 USER memory is self-describing via ASCII TEI mnemonics
/// ("MFR value*PNR value*...") delimited by '*'. There is NO binary TEI-header-ID
/// scheme in the spec; the map below is informational only and is not used to
/// decode tag memory.
const Map<int, String> kTeiHeaderIds = {
  0x00: 'MFR', 0x01: 'CAG', 0x02: 'SPL', 0x03: 'SER',
  0x04: 'SEQ', 0x05: 'UCN', 0x10: 'PNR', 0x11: 'PNO',
  0x12: 'UIC', 0x20: 'DMF', 0x21: 'EXP', 0x22: 'PDT',
  0x23: 'ESD', 0x24: 'LLE', 0x30: 'ICC', 0x31: 'LOT',
  0x32: 'LTN', 0x33: 'CNT', 0x34: 'WGT', 0x35: 'UNT',
  0x40: 'HAZ', 0x50: 'ECC', 0x51: 'SWI', 0x52: 'TDN',
  0x53: 'NSN', 0x54: 'FAB', 0x60: 'DOH', 0x61: 'DNH',
  0x62: 'OVD', 0x63: 'OMM', 0x64: 'PML',
};

/// Get ATA class label by ID
String getAtaClassLabel(int id) {
  return kAtaClassNames[id] ?? 'Unknown ($id)';
}

/// Get ATA tag type label
String getAtaTagTypeLabel(int tagType) {
  return kAtaTagTypeNames[tagType] ?? 'Unknown (0x${tagType.toRadixString(16)})';
}

/// Get TEI field label
String getTeiFieldLabel(String fieldId) {
  return kAtaUserFieldLabels[fieldId] ?? fieldId;
}

/// Format date from YYYYMMDD to YYYY/MM/DD
String formatAtaDate(String? raw) {
  if (raw == null || raw.length != 8) return raw ?? '';
  if (!RegExp(r'^\d{8}$').hasMatch(raw)) return raw;
  return '${raw.substring(0, 4)}/${raw.substring(4, 6)}/${raw.substring(6, 8)}';
}

/// Check if a field contains date data (YYYYMMDD TEIs per ATA Spec 2000 Table 3).
/// PDT (Part Description), ESD/LLE (indicators) are NOT dates.
bool isDateField(String fieldId) {
  return const {'DMF', 'EXP', 'OVD', 'DOH', 'DNH'}.contains(fieldId);
}

