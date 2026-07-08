// lib/ui/screens/box_check_scan_screen/theme_constants.dart
//
// Common theme constants and styles for RFID screens

import 'package:flutter/material.dart';

/// Brand colors
const Color kBrandNavy = Color(0xFF003B5C); // primary accent, body text
const Color kBrandNavyLight = Color(0xFF1A5276);
const Color kBrandRed = Color(0xFFEF2E1F); // app-bar / firma red
const Color kConfirmGreen = Color(0xFF43A047); // confirm/commit actions
const Color kDangerRed = Color(0xFFE53935); // stop/destructive actions

/// Background colors
const Color kBgLight = Color(0xFFFAFBFC);
const Color kBgCard = Color(0xFFF8F9FA);

/// Border colors
const Color kBorderLight = Color(0xFFE8EAED);
const Color kBorderMedium = Color(0xFFDEE2E6);

/// Text colors
const Color kTextPrimary = Color(0xFF1A1A1A);
const Color kTextSecondary = Color(0xFF6C757D);
const Color kTextMuted = Color(0xFF9CA3AF);

/// Common text styles
const TextStyle kLabelStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: kTextSecondary,
  letterSpacing: 0.3,
);

const TextStyle kValueStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kTextPrimary,
  height: 1.3,
);

const TextStyle kCardTitleStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.3,
);

const TextStyle kSectionTitleStyle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: kTextPrimary,
  letterSpacing: 0.3,
);

/// Card decoration
BoxDecoration kCardDecoration = BoxDecoration(
  color: kBgLight,
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: kBorderLight),
);

/// Input decoration theme for navy focus
InputDecorationTheme navyInputTheme(BuildContext context) {
  return InputDecorationTheme(
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBrandNavy, width: 2),
    ),
    floatingLabelStyle: const TextStyle(color: kBrandNavy),
  );
}

/// Date picker theme for navy color
ThemeData navyDatePickerTheme(BuildContext context) {
  return Theme.of(context).copyWith(
    colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: kBrandNavy,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
    dialogBackgroundColor: Colors.white,
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kBrandNavy,
      ),
    ),
  );
}

/// Common elevated button style
ButtonStyle kNavyButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: kBrandNavy,
  foregroundColor: Colors.white,
  elevation: 0,
  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);

/// Common outlined button style
ButtonStyle kOutlinedButtonStyle = OutlinedButton.styleFrom(
  foregroundColor: kBrandNavy,
  side: const BorderSide(color: kBrandNavy),
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
);

/// Common text button style (for cancel actions)
ButtonStyle kCancelButtonStyle = TextButton.styleFrom(
  foregroundColor: kTextSecondary,
  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
);

