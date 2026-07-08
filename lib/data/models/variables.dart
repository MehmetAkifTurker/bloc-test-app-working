import 'package:flutter/material.dart';

bool advancedView = false;
bool advancedViewForBoxSlaves = false;
int devCounter = 0;

// App bar: firma kırmızısı zemin + tam opak THY beyazı logo/başlık
// (eski white70 soluk görünüyordu).
Color titleTextAndIconColor = Colors.white;
Color titleBackgroundColor = const Color.fromRGBO(239, 46, 31, 1);

String globalDataToWriteTag = '';
