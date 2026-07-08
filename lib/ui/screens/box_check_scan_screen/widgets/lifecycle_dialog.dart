import 'package:flutter/material.dart';

const Color _brandNavy = Color(0xFF003B5C);

String _fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String _yyyymmdd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';

/// Shows the Update Lifecycle dialog and returns field values if confirmed.
/// All fields here belong to the rewritable Lifecycle Record (ATA Spec Table 6)
/// — the Birth Record stays locked. TEIs: PNR (current part no), PML (mod
/// level), EXP (expiration), OVD (last overhaul), DOH (hydrostatic test), TDN
/// (certificate), CND (condition).
Future<LifecycleUpdateData?> showUpdateLifecycleDialog(
    BuildContext context) async {
  final pnrCtrl = TextEditingController();
  final pmlCtrl = TextEditingController();
  final tdnCtrl = TextEditingController();
  final cndCtrl = TextEditingController();

  DateTime? expDate;
  DateTime? ovhDate;
  DateTime? dohDate;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Reusable date-picker field (EXP / OVD / DOH share the same look).
        Widget dateField({
          required String label,
          required DateTime? value,
          required ValueChanged<DateTime?> onChanged,
        }) {
          return GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: _brandNavy,
                      onPrimary: Colors.white,
                      surface: Colors.white,
                      onSurface: Colors.black,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onChanged(picked);
            },
            child: AbsorbPointer(
              child: TextField(
                controller:
                    TextEditingController(text: value == null ? '' : _fmtDate(value)),
                decoration: InputDecoration(
                  labelText: label,
                  hintText: 'YYYY/MM/DD',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  suffixIcon: value != null
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => onChanged(null),
                        )
                      : const Icon(Icons.calendar_today,
                          size: 18, color: _brandNavy),
                ),
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          );
        }

        Widget textField(TextEditingController c, String label, String hint,
            {bool caps = true}) {
          return TextField(
            controller: c,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            textCapitalization:
                caps ? TextCapitalization.characters : TextCapitalization.none,
          );
        }

        return Theme(
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
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
                    child: Text('Update Lifecycle',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _brandNavy,
                          letterSpacing: 0.3,
                        )),
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
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.blue),
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
                    textField(pnrCtrl, 'Current Part Number (PNR)',
                        'e.g., TA6950-02'),
                    const SizedBox(height: 12),
                    textField(pmlCtrl, 'Mod Level (PML)', 'e.g., MOD-123'),
                    const SizedBox(height: 12),
                    dateField(
                      label: 'Expiration Date (EXP)',
                      value: expDate,
                      onChanged: (d) => setDialogState(() => expDate = d),
                    ),
                    const SizedBox(height: 12),
                    dateField(
                      label: 'Last Overhaul Date (OVD)',
                      value: ovhDate,
                      onChanged: (d) => setDialogState(() => ovhDate = d),
                    ),
                    const SizedBox(height: 12),
                    dateField(
                      label: 'Hydrostatic Test Date (DOH)',
                      value: dohDate,
                      onChanged: (d) => setDialogState(() => dohDate = d),
                    ),
                    const SizedBox(height: 12),
                    textField(tdnCtrl, 'Certificate Number (TDN)',
                        'e.g., 8130-12345',
                        caps: false),
                    const SizedBox(height: 12),
                    textField(cndCtrl, 'Condition (CND)', 'SRV / UNS / UNK'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Update',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  if (result != true) return null;

  String? nn(String s) => s.trim().isEmpty ? null : s.trim().toUpperCase();

  return LifecycleUpdateData(
    currentPartNumber: nn(pnrCtrl.text),
    partModLevel: nn(pmlCtrl.text),
    expirationDate: expDate == null ? null : _yyyymmdd(expDate!),
    certificateNumber: nn(tdnCtrl.text),
    lastOverhaulDate: ovhDate == null ? null : _yyyymmdd(ovhDate!),
    hydrostaticTestDate: dohDate == null ? null : _yyyymmdd(dohDate!),
    conditionCode: nn(cndCtrl.text),
  );
}

/// Data class for lifecycle update form values
class LifecycleUpdateData {
  final String? currentPartNumber;
  final String? partModLevel;
  final String? expirationDate;
  final String? certificateNumber;
  final String? lastOverhaulDate;
  final String? hydrostaticTestDate;
  final String? conditionCode;

  LifecycleUpdateData({
    this.currentPartNumber,
    this.partModLevel,
    this.expirationDate,
    this.certificateNumber,
    this.lastOverhaulDate,
    this.hydrostaticTestDate,
    this.conditionCode,
  });
}
