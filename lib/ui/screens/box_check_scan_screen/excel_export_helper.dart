// lib/ui/screens/box_check_scan_screen/excel_export_helper.dart
//
// Excel Export Helper for RFID Tag Data

import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:rfid_manager/models/tag_item.dart';
import 'package:rfid_manager/ui/screens/box_check_scan_screen/epc_user_codec.dart';

/// Excel export column headers
const List<String> kExcelHeaders = [
  'No',
  'EPC',
  'TID',
  'PN (EPC)',
  'SN (EPC)',
  'CAGE',
  'Filter',
  'Tag Type',
  'MFR',
  'SER',
  'PNO',
  'PNR',
  'DMF',
  'EXP',
  'PDT',
  'UIC',
  'PML',
  'TDN',
  'Record Count',
  'USER (HEX)',
];

/// Format date from YYYYMMDD to YYYY/MM/DD
String formatDateField(String? raw) {
  if (raw == null || raw.length != 8) return raw ?? '';
  if (!RegExp(r'^\d{8}$').hasMatch(raw)) return raw;
  return '${raw.substring(0, 4)}/${raw.substring(4, 6)}/${raw.substring(6, 8)}';
}

/// Generate timestamp string for file naming
String generateTimestamp() {
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
}

/// Create Excel row data from TagItem
List<dynamic> createTagRow(int index, TagItem tag) {
  final userHex = tag.userHex ?? '';
  final decoded = decodeUserMemory(userHex);
  final fields = decoded['fields'] as Map? ?? {};
  final tocHeader = decoded['tocHeader'] as Map?;
  final tagTypeLabel = tocHeader?['ataTagTypeLabel'] ?? '';

  return [
    index,
    tag.rawEpc,
    tag.tid ?? '',
    tag.partNumber,
    tag.serialNumber,
    tag.cage,
    tag.filterValue ?? '',
    tagTypeLabel,
    fields['MFR'] ?? '',
    fields['SER'] ?? '',
    fields['PNO'] ?? '',
    fields['PNR'] ?? '',
    formatDateField(fields['DMF']?.toString()),
    formatDateField(fields['EXP']?.toString()),
    fields['PDT'] ?? '',
    fields['UIC'] ?? '',
    fields['PML'] ?? '',
    fields['TDN'] ?? '',
    decoded['recordCount'] ?? '',
    userHex,
  ];
}

/// Export tags to Excel file and share
/// 
/// Returns true if export was successful, false otherwise
Future<bool> exportTagsToExcel(List<TagItem> tags) async {
  if (tags.isEmpty) return false;

  try {
    final excel = Excel.createExcel();
    final String sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel.sheets[sheetName];
    if (sheet == null) return false;

    // Add header row
    sheet.appendRow(kExcelHeaders);

    // Add data rows
    int i = 1;
    for (final tag in tags) {
      sheet.appendRow(createTagRow(i++, tag));
    }

    // Encode and save
    final bytes = excel.encode();
    if (bytes == null) return false;

    final dir = await getTemporaryDirectory();
    final stamp = generateTimestamp();
    final fileName = 'RFID-READ-TAGS-$stamp.xlsx';
    final file = File('${dir.path}/$fileName')..createSync(recursive: true);
    await file.writeAsBytes(bytes, flush: true);

    // Share file
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          name: fileName,
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: 'RFID Tag Export - $stamp',
      text: 'Attached: RFID tag data including EPC, TID, USER memory and decoded TEI fields.',
    );

    return true;
  } catch (e) {
    return false;
  }
}

