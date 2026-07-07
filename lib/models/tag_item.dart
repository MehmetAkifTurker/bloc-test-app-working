// lib/models/tag_item.dart
/// Represents an RFID tag with EPC, TID, and USER memory data.
/// 
/// Uses EPC+TID combination for unique identification to handle cases
/// where multiple tags may share the same TID (manufacturing duplicates).
class TagItem {
  /// Raw EPC hex string from tag
  final String rawEpc;
  
  /// CAGE code (manufacturer identifier) decoded from EPC
  final String cage;
  
  /// Part number decoded from EPC
  final String partNumber;
  
  /// Serial number decoded from EPC
  final String serialNumber;
  
  /// Tag Identifier (TID) - unique chip ID (may be null for some tags)
  final String? tid;
  
  /// Filter value (0-63) from EPC header - corresponds to ATA class
  final int? filterValue;

  /// Whether USER memory has been successfully read
  bool userRead;
  
  /// Raw USER memory hex string (contains ToC + Records)
  String? userHex;
  
  /// ATA class ID (parsed from USER memory ToC header)
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

  /// Returns unique identifier for this tag using EPC+TID combination.
  /// 
  /// Format: "EPC|TID" (e.g., "3B060131...|E200F451...")
  /// Falls back to EPC only if TID is unavailable.
  /// 
  /// Note: Must match _identityKey format in box_check_scan_screen.dart exactly
  /// Both methods must use .toUpperCase().trim() for consistent key generation
  /// 
  /// The TID field is only set when SDK's validTid flag is true, so checking
  /// for non-null/non-empty TID here is equivalent to the validTid check.
  String get uniqueId {
    final epcKey = rawEpc.toUpperCase().trim(); // Must match _identityKey
    final tidKey = tid?.trim();
    if (tidKey != null && tidKey.isNotEmpty) {
      return '$epcKey|${tidKey.toUpperCase()}'; // EPC|TID format
    }
    return epcKey;
  }

  /// Sentinel object to distinguish "not provided" from "explicitly null"
  static const Object _sentinel = Object();

  /// Creates a copy of this TagItem with the given fields replaced.
  /// 
  /// For nullable fields like [tid], use the sentinel pattern:
  /// - Pass nothing to keep the current value
  /// - Pass null explicitly to clear the value (set to null)
  /// - Pass a value to update to that value
  TagItem copyWith({
    String? rawEpc,
    String? cage,
    String? partNumber,
    String? serialNumber,
    Object? tid = _sentinel, // Sentinel allows explicit null
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
      // If tid is sentinel (not provided), keep current; otherwise use new value (including null)
      tid: identical(tid, _sentinel) ? this.tid : (tid as String?),
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
