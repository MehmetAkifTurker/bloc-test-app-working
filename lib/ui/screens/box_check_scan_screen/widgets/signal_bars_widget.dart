// lib/ui/screens/box_check_scan_screen/widgets/signal_bars_widget.dart
//
// Signal strength indicator bars widget
// Note: LocationStatusWidget is now in location_status_widget.dart

import 'package:flutter/material.dart';

/// Standalone signal bars for custom placement
class SignalBars extends StatelessWidget {
  final int activeLevel;
  const SignalBars({super.key, required this.activeLevel});

  Color _getBarColor(int barIndex) {
    if (barIndex > activeLevel) return Colors.grey.shade300;
    switch (activeLevel) {
      case 1:
        return Colors.red.shade400;
      case 2:
        return Colors.orange.shade400;
      case 3:
        return Colors.green.shade400;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final barIndex = i + 1;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: 6,
          height: 6.0 + (i * 4),
          decoration: BoxDecoration(
            color: _getBarColor(barIndex),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

