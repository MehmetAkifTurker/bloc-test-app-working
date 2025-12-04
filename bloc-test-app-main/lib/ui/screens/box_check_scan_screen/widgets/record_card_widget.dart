import 'package:flutter/material.dart';

// Theme constants
const Color _brandNavy = Color(0xFF003B5C);
const Color _textSecondary = Color(0xFF666666);
const Color _bgLight = Color(0xFFF8F9FA);
const Color _borderLight = Color(0xFFE0E0E0);

const TextStyle _cardTitleStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w700, color: _brandNavy);
const TextStyle _labelStyle = TextStyle(
    fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary);
const TextStyle _valueStyle = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A), height: 1.3);

/// Widget to display a single ATA record (Birth, Lifecycle, Current Data, etc.)
class RecordCardWidget extends StatelessWidget {
  final Map<String, dynamic> record;
  
  const RecordCardWidget({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final descriptor = record['descriptor'] as Map?;
    final recordType = descriptor?['recordType'] ?? 0;
    final recordTypeLabel = descriptor?['recordTypeLabel'] ?? 'Unknown';
    final payloadText = record['payloadText']?.toString() ?? '';
    final fields = record['fields'] as Map?;

    final Map<String, String> recordFields = {};
    if (fields != null) {
      for (final entry in fields.entries) {
        final key = entry.key?.toString().toUpperCase();
        var value = entry.value?.toString().trim();
        if (key != null &&
            key.isNotEmpty &&
            value != null &&
            value.isNotEmpty) {
          // Format date fields (YYYYMMDD → YYYY/MM/DD)
          if ((key == 'DMF' ||
                  key == 'EXP' ||
                  key == 'OVD' ||
                  key == 'DOH' ||
                  key == 'DNH') &&
              value.length == 8 &&
              RegExp(r'^\d{8}$').hasMatch(value)) {
            value =
                '${value.substring(0, 4)}/${value.substring(4, 6)}/${value.substring(6, 8)}';
          }
          recordFields[key] = value;
        }
      }
    }

    // Icon based on record type
    IconData recordIcon;
    Color iconColor;
    switch (recordType) {
      case 0x00: // Birth
        recordIcon = Icons.cake;
        iconColor = _brandNavy;
        break;
      case 0x04: // Lifecycle
        recordIcon = Icons.autorenew;
        iconColor = Colors.orange.shade700;
        break;
      case 0x01: // Current Data
        recordIcon = Icons.update;
        iconColor = Colors.green.shade700;
        break;
      case 0x03: // Part History
        recordIcon = Icons.history;
        iconColor = Colors.blue.shade700;
        break;
      default:
        recordIcon = Icons.description;
        iconColor = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(recordIcon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(recordTypeLabel,
                    style: _cardTitleStyle.copyWith(color: iconColor)),
              ),
            ],
          ),
          if (recordFields.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...recordFields.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 50,
                        child: Text('${e.key}:', style: _labelStyle),
                      ),
                      Expanded(
                        child: Text(e.value,
                            style: _valueStyle.copyWith(fontSize: 13)),
                      ),
                    ],
                  ),
                )),
          ],
          if (payloadText.isNotEmpty && recordFields.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              payloadText,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget to display multiple records in a column
class RecordSectionsWidget extends StatelessWidget {
  final Map<String, dynamic> decodedUser;
  
  const RecordSectionsWidget({super.key, required this.decodedUser});

  @override
  Widget build(BuildContext context) {
    final records = decodedUser['records'];
    if (records == null || records is! List || records.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < records.length; i++)
          if (records[i] is Map) ...[
            if (i > 0) const SizedBox(height: 12),
            RecordCardWidget(record: records[i] as Map<String, dynamic>),
          ],
      ],
    );
  }
}

