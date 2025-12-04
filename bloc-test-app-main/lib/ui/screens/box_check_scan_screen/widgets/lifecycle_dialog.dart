import 'package:flutter/material.dart';

const Color _brandNavy = Color(0xFF003B5C);

/// Shows the Update Lifecycle dialog and returns field values if confirmed
Future<LifecycleUpdateData?> showUpdateLifecycleDialog(
    BuildContext context) async {
  final pnrCtrl = TextEditingController();
  final pmlCtrl = TextEditingController();
  final tdnCtrl = TextEditingController();

  DateTime? selectedExpDate;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) => Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: _brandNavy, width: 2),
            ),
            floatingLabelStyle: const TextStyle(color: _brandNavy),
          ),
        ),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _brandNavy.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.edit_note_rounded,
                      color: _brandNavy, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Update Lifecycle',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _brandNavy,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Updates rewritable Lifecycle data.\nBirth record remains locked.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pnrCtrl,
                    decoration: InputDecoration(
                      labelText: 'Current Part Number (PNR)',
                      hintText: 'e.g., TA6950-02',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pmlCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mod Level (PML)',
                      hintText: 'e.g., MOD-123',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedExpDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: _brandNavy,
                                onPrimary: Colors.white,
                                surface: Colors.white,
                                onSurface: Colors.black,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setDialogState(() => selectedExpDate = picked);
                      }
                    },
                    child: AbsorbPointer(
                      child: TextField(
                        controller: TextEditingController(
                          text: selectedExpDate == null
                              ? ''
                              : '${selectedExpDate!.year}/${selectedExpDate!.month.toString().padLeft(2, '0')}/${selectedExpDate!.day.toString().padLeft(2, '0')}',
                        ),
                        decoration: InputDecoration(
                          labelText: 'Expiration Date (EXP)',
                          hintText: 'YYYY/MM/DD',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          suffixIcon: selectedExpDate != null
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => setDialogState(
                                      () => selectedExpDate = null),
                                )
                              : const Icon(Icons.calendar_today,
                                  size: 18, color: _brandNavy),
                        ),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tdnCtrl,
                    decoration: InputDecoration(
                      labelText: 'Certificate Number (TDN)',
                      hintText: 'e.g., 8130-12345',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                    ),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Cancel',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Update',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (result != true) return null;

  // Format dates as YYYYMMDD
  String? expDateFormatted;
  if (selectedExpDate != null) {
    expDateFormatted = '${selectedExpDate!.year.toString().padLeft(4, '0')}'
        '${selectedExpDate!.month.toString().padLeft(2, '0')}'
        '${selectedExpDate!.day.toString().padLeft(2, '0')}';
  }

  // Note: selectedOvhDate is currently always null as there's no picker for it
  // Kept for future extensibility
  const String? ovhDateFormatted = null;

  return LifecycleUpdateData(
    currentPartNumber: pnrCtrl.text.trim().isEmpty
        ? null
        : pnrCtrl.text.trim().toUpperCase(),
    partModLevel: pmlCtrl.text.trim().isEmpty
        ? null
        : pmlCtrl.text.trim().toUpperCase(),
    expirationDate: expDateFormatted,
    certificateNumber: tdnCtrl.text.trim().isEmpty
        ? null
        : tdnCtrl.text.trim().toUpperCase(),
    lastOverhaulDate: ovhDateFormatted,
  );
}

/// Data class for lifecycle update form values
class LifecycleUpdateData {
  final String? currentPartNumber;
  final String? partModLevel;
  final String? expirationDate;
  final String? certificateNumber;
  final String? lastOverhaulDate;

  LifecycleUpdateData({
    this.currentPartNumber,
    this.partModLevel,
    this.expirationDate,
    this.certificateNumber,
    this.lastOverhaulDate,
  });
}

