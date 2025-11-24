import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';

class DiagnosticScreen extends StatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  State<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends State<DiagnosticScreen> {
  final List<Map<String, dynamic>> _diagnosticResults = [];
  bool _isRunning = false;

  Future<void> _runDiagnostic() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _diagnosticResults.clear();
    });

    log("🔬 DIAGNOSTIC: Starting individual tag analysis");

    try {
      // Test up to 10 reads to see what we get
      for (int i = 0; i < 10; i++) {
        final String? result = await RfidC72Plugin.diagnosticReadSingleTag();
        if (result == null || result.isEmpty) {
          log("🔬 DIAGNOSTIC: No tag detected on attempt ${i + 1}");
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        try {
          final Map<String, dynamic> tagData = jsonDecode(result);
          if (tagData.containsKey('error')) {
            log("🔬 DIAGNOSTIC: Error - ${tagData['error']}");
            continue;
          }

          setState(() {
            _diagnosticResults.add({
              ...tagData,
              'attempt': i + 1,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          });

          log("🔬 DIAGNOSTIC: Result ${i + 1}:");
          log("🔬   EPC: ${tagData['epc']}");
          log("🔬   TID: ${tagData['tid']}");
          log("🔬   Direct TID: ${tagData['directTid']}");
          log("🔬   Has USER Memory: ${tagData['hasUserMemory']}");
          log("🔬   USER Preview: ${tagData['userMemory']?.toString().substring(0, 16)}...");

          await Future.delayed(const Duration(milliseconds: 800));
        } catch (e) {
          log("🔬 DIAGNOSTIC: JSON parse error: $e");
        }
      }
    } catch (e) {
      log("🔬 DIAGNOSTIC: Exception: $e");
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RFID Diagnostic')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runDiagnostic,
              child: Text(_isRunning ? 'Running...' : 'Start Diagnostic'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _diagnosticResults.length,
              itemBuilder: (context, index) {
                final result = _diagnosticResults[index];
                final hasUser = result['hasUserMemory'] == true;

                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  color: hasUser ? Colors.green.shade50 : Colors.red.shade50,
                  child: ListTile(
                    title:
                        Text('Attempt ${result['attempt']}: ${result['epc']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TID: ${result['tid']}'),
                        Text('Direct TID: ${result['directTid']}'),
                        Text('RSSI: ${result['rssi']}'),
                        Text('Has USER: ${result['hasUserMemory']}'),
                        Text(
                            'USER: ${result['userMemory']?.toString().substring(0, 32)}...'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
