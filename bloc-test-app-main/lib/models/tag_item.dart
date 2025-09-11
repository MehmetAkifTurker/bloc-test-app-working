// lib/rfid/models/tag_item.dart
class TagItem {
  final String rawEpc;
  final String cage;
  final String partNumber;
  final String serialNumber;
  final String? tid; // Added TID for unique chip identification

  bool userRead;
  String? userHex;

  TagItem({
    required this.rawEpc,
    required this.cage,
    required this.partNumber,
    required this.serialNumber,
    this.tid,
    this.userRead = false,
    this.userHex,
  });

  // Use TID for unique identification if available, fallback to EPC
  String get uniqueId => (tid?.isNotEmpty == true) ? tid! : rawEpc;

  TagItem copyWith({
    String? rawEpc,
    String? cage,
    String? partNumber,
    String? serialNumber,
    String? tid,
    bool? userRead,
    String? userHex,
  }) {
    return TagItem(
      rawEpc: rawEpc ?? this.rawEpc,
      cage: cage ?? this.cage,
      partNumber: partNumber ?? this.partNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      tid: tid ?? this.tid,
      userRead: userRead ?? this.userRead,
      userHex: userHex ?? this.userHex,
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
