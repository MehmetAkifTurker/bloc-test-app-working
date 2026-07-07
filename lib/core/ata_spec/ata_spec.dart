// lib/core/ata_spec/ata_spec.dart
//
// ATA Spec 2000 - Barrel Export
// Import this file to access all ATA Spec 2000 utilities

export 'six_bit_ascii.dart';
export 'record_types.dart';
export 'epc_decoder.dart';

// USER Memory decoder is still in the legacy location
// Will be migrated in a future update
export 'package:rfid_manager/ui/screens/box_check_scan_screen/epc_user_codec.dart'
    show decodeUserMemory, AtaTocHeader, AtaRecordDescriptor, AtaDecodedRecord;

