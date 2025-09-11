import 'package:flutter/material.dart';

class ButtonWithTextAndValue extends StatelessWidget {
  final String title; // Text to display in the card
  final int value;
  final int? secondValue;
  final bool? isSelected; // Value to display below the title
  final Color? selectedColor; // Color for selected state (optional)
  final Color? unselectedColor; // Color for unselected state (optional)
  final VoidCallback? onTap; // Function to execute on tap (optional)

  const ButtonWithTextAndValue({
    super.key,
    required this.title,
    required this.value,
    this.secondValue,
    this.isSelected,
    this.selectedColor,
    this.unselectedColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = secondValue != null
        ? '${value.toString()} / ${secondValue.toString()}'
        : value.toString();
    return value > 0
        ? InkWell(
            onTap: onTap,
            child: Card(
              color: _getCardColor(),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Text(title),
                    Text(
                      valueText,
                      style: const TextStyle(fontSize: 35.0),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Color? _getCardColor() {
    if (selectedColor != null || unselectedColor != null) {
      return (isSelected ?? false) ? selectedColor : unselectedColor;
    } else {
      return null; // Default or use a theme color
    }
  }
}
