// lib/core/ata_spec/record_types.dart
//
// ATA Spec 2000 Record Types, Tag Types, and TEI Field Definitions

/// ATA Tag Type IDs
abstract class AtaTagType {
  static const int multiRecord = 0x0000;
  static const int dualRecord = 0x0001;
  static const int singleBirth = 0x0002;
  static const int singleUtility = 0x000A;
}

/// ATA Record Type IDs
abstract class AtaRecordType {
  static const int birth = 0x00;
  static const int currentData = 0x01;
  static const int scratchpad = 0x02;
  static const int partHistory = 0x03;
  static const int lifecycle = 0x04;
  static const int supplemental = 0x05;
  static const int sensor = 0x06;
}

/// ATA Tag Type Names
const Map<int, String> kAtaTagTypeNames = {
  AtaTagType.multiRecord: 'Multi-Record',
  AtaTagType.dualRecord: 'Dual-Record',
  AtaTagType.singleBirth: 'Single Birth Record',
  AtaTagType.singleUtility: 'Single Utility Record',
};

/// ATA Record Type Names
const Map<int, String> kAtaRecordTypeNames = {
  AtaRecordType.birth: 'Birth Record',
  AtaRecordType.currentData: 'Current Data Record',
  AtaRecordType.scratchpad: 'Scratchpad',
  AtaRecordType.partHistory: 'Part History Record',
  AtaRecordType.lifecycle: 'Lifecycle Record',
  AtaRecordType.supplemental: 'Supplemental Record',
  AtaRecordType.sensor: 'Sensor Record',
};

/// ATA Equipment Class Names
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

/// TEI Header IDs (per ATA Spec 2000)
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

/// TEI Field Labels - Human readable names
const Map<String, String> kTeiFieldLabels = {
  'MFR': 'Manufacturer',
  'CAG': 'CAGE Code',
  'SPL': 'Supplier Code',
  'SER': 'Serial Number',
  'SEQ': 'Serial Sequence',
  'UCN': 'Unique Component Number',
  'PNR': 'Part Number (Replacement)',
  'PNO': 'Part Number (Original)',
  'UIC': 'Unique Item Code',
  'DMF': 'Date of Manufacture',
  'EXP': 'Expiration Date',
  'PDT': 'Production Date',
  'ESD': 'Effective Service Date',
  'LLE': 'Limited Life Expires',
  'ICC': 'Item Class Code',
  'LOT': 'Lot/Batch Number',
  'LTN': 'Lot Traceability Number',
  'CNT': 'Count/Quantity',
  'WGT': 'Weight',
  'UNT': 'Unit of Measure',
  'HAZ': 'Hazardous Material',
  'ECC': 'Equipment Condition',
  'SWI': 'Software ID',
  'TDN': 'Tag Data Number',
  'NSN': 'NATO Stock Number',
  'FAB': 'Fabrication',
  'DOH': 'Date of Overhaul',
  'DNH': 'Date Next Overhaul',
  'OVD': 'Overhaul Date',
  'OMM': 'OEM Maintenance Manual',
  'PML': 'Prime Mfr Life Limit',
};

/// Standard TEI field order for display
const List<String> kTeiFieldOrder = [
  'MFR', 'CAG', 'SPL', 'SER', 'SEQ', 'UCN',
  'PNR', 'PNO', 'UIC', 'DMF', 'EXP', 'PDT',
  'ESD', 'LLE', 'ICC', 'LOT', 'LTN', 'CNT',
  'WGT', 'UNT', 'HAZ', 'ECC', 'SWI', 'TDN',
  'NSN', 'FAB', 'DOH', 'DNH', 'OVD', 'OMM', 'PML',
];

/// Date fields for formatting
const Set<String> kDateFields = {
  'DMF', 'EXP', 'PDT', 'ESD', 'LLE', 'DOH', 'DNH', 'OVD'
};

/// Get ATA class label by ID
String getAtaClassLabel(int id) {
  return kAtaClassNames[id] ?? 'Unknown ($id)';
}

/// Get ATA tag type label
String getAtaTagTypeLabel(int tagType) {
  return kAtaTagTypeNames[tagType] ?? 'Unknown (0x${tagType.toRadixString(16)})';
}

/// Get ATA record type label
String getAtaRecordTypeLabel(int recordType) {
  return kAtaRecordTypeNames[recordType] ?? 'Unknown (0x${recordType.toRadixString(16)})';
}

/// Get TEI field label
String getTeiFieldLabel(String fieldId) {
  return kTeiFieldLabels[fieldId] ?? fieldId;
}

/// Check if a field contains date data
bool isDateField(String fieldId) {
  return kDateFields.contains(fieldId);
}

/// Format date from YYYYMMDD to YYYY/MM/DD
String formatAtaDate(String? raw) {
  if (raw == null || raw.length != 8) return raw ?? '';
  if (!RegExp(r'^\d{8}$').hasMatch(raw)) return raw;
  return '${raw.substring(0, 4)}/${raw.substring(4, 6)}/${raw.substring(6, 8)}';
}

/// Get record priority for sorting (Birth first, then Lifecycle, etc.)
int getRecordPriority(int recordType) {
  switch (recordType) {
    case AtaRecordType.birth:
      return 0;
    case AtaRecordType.lifecycle:
      return 1;
    case AtaRecordType.currentData:
      return 2;
    case AtaRecordType.partHistory:
      return 3;
    case AtaRecordType.scratchpad:
      return 4;
    default:
      return 5;
  }
}

