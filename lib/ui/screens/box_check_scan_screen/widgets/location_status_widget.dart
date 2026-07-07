import 'package:flutter/material.dart';

/// Basit sinyal göstergesi — değer üst widget tarafından sağlanır
class LocationStatusWidget extends StatelessWidget {
  final bool isLocating;
  final int? signalStrength;
  
  const LocationStatusWidget({
    super.key, 
    required this.isLocating, 
    required this.signalStrength,
  });

  int getBarLevel(int? v) {
    if (v == null) return 0;
    if (v >= 70) return 3;
    if (v >= 40) return 2;
    if (v > 0) return 1;
    return 0;
  }

  Color getBarColor(int level, int activeLevel) {
    if (level > activeLevel) return Colors.grey.shade300;
    switch (level) {
      case 1:
        return Colors.green.shade900;
      case 2:
        return Colors.green.shade600;
      case 3:
        return Colors.green.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final int activeLevel = getBarLevel(signalStrength);

    if (!isLocating) {
      return const Card(
        margin: EdgeInsets.all(8),
        child: ListTile(
          title: Text('Tag search not started yet'),
          subtitle: Text('Press "Start Locate" to begin'),
        ),
      );
    }

    final String subtitleText = signalStrength == null
        ? 'Searching...'
        : 'Signal Strength: $signalStrength';

    final TextStyle subtitleStyle = signalStrength == null
        ? const TextStyle(color: Colors.orange)
        : TextStyle(
            fontWeight: FontWeight.w600, color: getBarColor(activeLevel, 3));

    return Card(
      margin: const EdgeInsets.all(8),
      child: ListTile(
        leading: SizedBox(
          width: 32,
          height: 32,
          child: _SignalBars(activeLevel: activeLevel),
        ),
        title: const Text('Location Signal Strength'),
        subtitle: Text(subtitleText, style: subtitleStyle),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  final int activeLevel;

  const _SignalBars({required this.activeLevel});

  Color _getBarColor(int level) {
    if (level > activeLevel) return Colors.grey.shade300;
    switch (level) {
      case 1:
        return Colors.green.shade900;
      case 2:
        return Colors.green.shade600;
      case 3:
        return Colors.green.shade300;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final int level = i + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 7,
            height: 10.0 + 7.0 * level,
            decoration: BoxDecoration(
              color: _getBarColor(level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

