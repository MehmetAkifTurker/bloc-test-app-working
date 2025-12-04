// lib/ui/screens/box_check_scan_screen/filter_options.dart
//
// ATA Spec 2000 Filter Options for RFID Tag Classification

/// Represents a filter option for ATA class filtering
class FilterOption {
  final int id;
  final String label;
  const FilterOption(this.id, this.label);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FilterOption && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Special filter option to show all tags
const FilterOption kFilterAll = FilterOption(-999, 'All — show everything');

/// ATA Spec 2000 Class Filter Options
/// Based on ATA Spec 2000 Chapter 9 - AIDC Equipment Classes
const List<FilterOption> kFilterOptions = [
  FilterOption(0, 'Other / Unspecified'),
  FilterOption(1, 'Item (general; not 8–63)'),
  FilterOption(2, 'Carton'),
  FilterOption(6, 'Pallet'),
  FilterOption(8, 'Seat Cushions'),
  FilterOption(9, 'Seat Covers'),
  FilterOption(10, 'Seat Belts / Belt Ext.'),
  FilterOption(11, 'Galley & Service Equip.'),
  FilterOption(12, 'Galley Ovens'),
  FilterOption(13, 'Aircraft Security Items'),
  FilterOption(14, 'Life Vests'),
  FilterOption(15, 'Oxygen Generators'),
  FilterOption(16, 'Engine & Engine Components'),
  FilterOption(17, 'Avionics'),
  FilterOption(18, 'Experimental ("flight test") equip.'),
  FilterOption(19, 'Other Emergency Equipment'),
  FilterOption(20, 'Other Rotables'),
  FilterOption(21, 'Other Repairables'),
  FilterOption(22, 'Other Cabin Interior'),
  FilterOption(23, 'Other Repair (e.g., structural)'),
  FilterOption(24, 'Seat & Seat Components (excl. 8–10)'),
  FilterOption(25, 'In-Flight Entertainment (IFE)'),
  FilterOption(56, 'Location Identifier'),
  FilterOption(57, 'Documentation'),
  FilterOption(58, 'Tools'),
  FilterOption(59, 'Ground Support Equipment'),
  FilterOption(60, 'Other Non-Flyable Equipment'),
];

/// Get filter label with ID prefix for display
String getFilterDisplayLabel(FilterOption option) {
  if (option.id == kFilterAll.id) {
    return option.label;
  }
  return '${option.id} — ${option.label}';
}

/// Get all filter options including "All"
List<FilterOption> getAllFilterOptions() => [kFilterAll, ...kFilterOptions];

