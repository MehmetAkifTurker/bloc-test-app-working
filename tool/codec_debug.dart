// Debug tool for testing ATA Spec 2000 decoder
// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:rfid_manager/ui/screens/box_check_scan_screen/epc_user_codec.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tool/codec_debug.dart <USER_HEX>');
    return;
  }
  final hex = args.first.trim();
  final decoded = decodeUserMemory(hex);
  final pretty = const JsonEncoder.withIndent('  ').convert(decoded);
  print(pretty);
}

