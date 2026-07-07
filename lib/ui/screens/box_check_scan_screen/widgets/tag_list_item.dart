// lib/ui/screens/box_check_scan_screen/widgets/tag_list_item.dart
//
// Tag list item widget for scan screen

import 'package:flutter/material.dart';
import 'package:rfid_manager/models/tag_item.dart';

/// Single tag item in the scan list
class TagListItem extends StatelessWidget {
  final TagItem item;
  final int index;
  final VoidCallback onTap;
  final Color brandColor;

  const TagListItem({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    this.brandColor = const Color(0xFF003B5C),
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Index badge
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: brandColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  color: brandColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Tag info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(label: 'PN', value: item.partNumber),
                    _InfoRow(label: 'SN', value: item.serialNumber),
                    _InfoRow(label: 'CAGE', value: item.cage),
                  ],
                ),
              ),
            ),
            // Status indicator
            _StatusIndicator(userRead: item.userRead),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      softWrap: true,
      style: const TextStyle(fontSize: 13),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  final bool userRead;

  const _StatusIndicator({required this.userRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: userRead ? Colors.green.shade400 : Colors.orange.shade300,
      ),
    );
  }
}

/// Tag count header for the list
class TagCountHeader extends StatelessWidget {
  final int filteredCount;
  final int totalCount;
  final Color brandColor;

  const TagCountHeader({
    super.key,
    required this.filteredCount,
    required this.totalCount,
    this.brandColor = const Color(0xFF003B5C),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.style, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Text(
            "Tags",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$filteredCount",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          if (filteredCount != totalCount) ...[
            const SizedBox(width: 4),
            Text(
              "/ $totalCount",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

