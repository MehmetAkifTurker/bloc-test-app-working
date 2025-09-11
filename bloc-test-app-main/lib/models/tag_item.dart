// lib/rfid/models/tag_item.dart
class TagItem {
  final String rawEpc;
  final String cage;
  final String partNumber;
  final String serialNumber;

  bool userRead;
  String? userHex;

  TagItem({
    required this.rawEpc,
    required this.cage,
    required this.partNumber,
    required this.serialNumber,
    this.userRead = false,
    this.userHex,
  });

  TagItem copyWith({
    String? rawEpc,
    String? cage,
    String? partNumber,
    String? serialNumber,
    bool? userRead,
    String? userHex,
  }) {
    return TagItem(
      rawEpc: rawEpc ?? this.rawEpc,
      cage: cage ?? this.cage,
      partNumber: partNumber ?? this.partNumber,
      serialNumber: serialNumber ?? this.serialNumber,
      userRead: userRead ?? this.userRead,
      userHex: userHex ?? this.userHex,
    );
  }
}
