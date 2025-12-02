// lib/rfid/models/tag_item.dart
class TagItem {
  final String rawEpc;
  final String cage;
  final String partNumber;
  final String serialNumber;
  final String? tid; // Added TID for unique chip identification
  final int? filterValue;

  bool userRead;
  String? userHex;
  int? ataClass;

  TagItem({
    required this.rawEpc,
    required this.cage,
    required this.partNumber,
    required this.serialNumber,
    this.tid,
    this.filterValue,
    this.userRead = false,
    this.userHex,
    this.ataClass,
  });

  // Use EPC+TID combo for unique identity
  // (Must match _identityKey format in box_check_scan_screen.dart)
  String get uniqueId {
    final epcKey = rawEpc.toUpperCase();
    final tidKey = tid?.trim();
    if (tidKey != null && tidKey.isNotEmpty) {
      return '$epcKey|${tidKey.toUpperCase()}'; // EPC|TID format
    }
    return epcKey;
  }

  TagItem copyWith({
    String? rawEpc,
    String? cage,
    String? partNumber,
    String? serialNumber,
    String? tid,
    int? filterValue,
    bool? userRead,
    String? userHex,
    int? ataClass,
  }) {
    return TagItem(
      rawEpc: rawEpc ?? this.rawEpc,
      cage: cage ?? this.cage,
      partNumber: partNumber ?? this.partNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      tid: tid ?? this.tid,
      filterValue: filterValue ?? this.filterValue,
      userRead: userRead ?? this.userRead,
      userHex: userHex ?? this.userHex,
      ataClass: ataClass ?? this.ataClass,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TagItem && other.uniqueId == uniqueId;
  }

  @override
  int get hashCode => uniqueId.hashCode;
}
