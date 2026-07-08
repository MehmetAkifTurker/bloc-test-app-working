# Graph Report - rfid-manager  (2026-07-08)

## Corpus Check
- 104 files · ~716,863 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1350 nodes · 2026 edges · 74 communities (57 shown, 17 thin omitted)
- Extraction: 88% EXTRACTED · 12% INFERRED · 0% AMBIGUOUS · INFERRED: 242 edges (avg confidence: 0.8)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `6cebae7b`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- epc_user_codec.dart
- .getInstance
- .getReader
- tag_write_screen.dart
- rfid_c72_plugin.dart
- tag_detail_screen.dart
- create_chip_screen.dart
- InventoryManager
- box_check_scan_screen.dart
- GeneratedPluginRegistrant.swift
- UHFManager
- excel_export_helper.dart
- RFID Manager - Setup Guide
- record_types.dart
- SDKMethods - RFID SDK Modül Yapısı
- my_application.cc
- theme_constants.dart
- LocationManager
- tag_list_item.dart
- qr_scan_screen.dart
- win32_window.cpp
- lifecycle_dialog.dart
- package:flutter/material.dart
- six_bit_ascii.dart
- variables.dart
- FlutterWindow
- Color?
- diagnostic_screen.dart
- tag_item.dart
- List
- main_menu.dart
- ata_constants.dart
- record_card_widget.dart
- Win32Window
- filter_options.dart
- wWinMain
- app_router.dart
- button_with_text_and_value.dart
- manifest.json
- location_status_widget.dart
- State
- MessageHandler
- const.dart
- menu_card.dart
- RFID Manager
- widgets.dart
- rfid_status.dart
- .getInstance
- widgets.dart
- GeneratedPluginRegistrant.java
- gradlew
- shared.dart
- features.dart
- constants.dart
- RegisterPlugins
- TagKey.java
- core.dart
- script.js
- tag_write.dart
- flutter_export_environment.sh
- README.md
- package:rfid_manager/ui/screens/box_check_scan_screen/tag_detail_screen.dart
- _openDetail
- package:rfid_manager/models/epc_user_codec.dart
- TagDetailScreen
- TagTypeManagerPage
- TagWriteScreen
- flutter_export_environment.sh
- bool?
- String?

## God Nodes (most connected - your core abstractions)
1. `UHFHelper` - 63 edges
2. `UHFManager` - 36 edges
3. `MemoryWriter` - 28 edges
4. `LocationManager` - 27 edges
5. `MemoryReader` - 25 edges
6. `InventoryManager` - 22 edges
7. `Win32Window` - 22 edges
8. `EPC` - 21 edges
9. `AtaEncodingUtils` - 16 edges
10. `RfidC72Plugin` - 15 edges

## Surprising Connections (you probably didn't know these)
- `OnCreate` --calls--> `RegisterPlugins()`  [INFERRED]
  windows/runner/flutter_window.h → windows/flutter/generated_plugin_registrant.cc
- `wWinMain()` --calls--> `CreateAndAttachConsole()`  [INFERRED]
  windows/runner/main.cpp → windows/runner/utils.cpp
- `Win32Window::Win32Window()` --calls--> `Destroy`  [INFERRED]
  windows/runner/win32_window.cpp → windows/runner/win32_window.h
- `my_application_activate()` --calls--> `fl_register_plugins()`  [INFERRED]
  linux/my_application.cc → linux/flutter/generated_plugin_registrant.cc
- `main()` --calls--> `my_application_new()`  [INFERRED]
  linux/main.cc → linux/my_application.cc

## Import Cycles
- None detected.

## Communities (74 total, 17 thin omitted)

### Community 0 - "epc_user_codec.dart"
Cohesion: 0.02
Nodes (111): dart:math, ascii6Map, asciiFields, asciiText, ataClass, ataClassLabel, AtaDecodedRecord, ataHex (+103 more)

### Community 1 - ".getInstance"
Cohesion: 0.06
Nodes (20): FlutterEngine, Override, MainActivity, Context, Override, RfidC72Plugin, Context, EventSink (+12 more)

### Community 2 - ".getReader"
Cohesion: 0.09
Nodes (6): AtaEncodingUtils, Override, RFIDWithUHFUART, MemoryReader, RFIDWithUHFUART, MemoryWriter

### Community 3 - "tag_write_screen.dart"
Cohesion: 0.03
Nodes (73): _actionGap, _actionSlotSize, _addExtraFieldDialog, _addItemDialog, _alignedFieldRow, _brandNavy, build, _buildExtraFieldsSection (+65 more)

### Community 4 - "rfid_c72_plugin.dart"
Cohesion: 0.03
Nodes (71): applyAtaPermalock, _barcodeConnected, _barcodeCtrl, barcodeStream, _channel, clearRfidTriggerHandlers, configureChipAta, connectedStatusStream (+63 more)

### Community 5 - "tag_detail_screen.dart"
Cohesion: 0.04
Nodes (52): Duration, _autoFetch, _beepTimer, _bgLight, _borderLight, _brandNavy, build, _buildInfoRow (+44 more)

### Community 6 - "create_chip_screen.dart"
Cohesion: 0.04
Nodes (46): FormState, _applyPermalock, _applyRecommendedSettings, _brandNavy, build, _buildPermalockExplanation, _buildRecommendationRow, _buildRecordTypeSpecificSettings (+38 more)

### Community 7 - "InventoryManager"
Cohesion: 0.10
Nodes (5): EPC, InventoryManager, Handler, Override, TagThread

### Community 8 - "box_check_scan_screen.dart"
Cohesion: 0.05
Nodes (42): _applyInitialPower, _attachTriggerControls, _brandNavy, build, _buildAtaFilterDropdown, _buildButtonRow, _buildPowerSlider, _buildTagList (+34 more)

### Community 9 - "GeneratedPluginRegistrant.swift"
Cohesion: 0.06
Nodes (28): Any, Cocoa, Flutter, FlutterAppDelegate, FlutterMacOS, FlutterPluginRegistry, FlutterViewController, Foundation (+20 more)

### Community 10 - "UHFManager"
Cohesion: 0.08
Nodes (5): UHFListener, Context, RFIDWithUHFUART, UHFManager, BarcodeDecoder

### Community 11 - "excel_export_helper.dart"
Cohesion: 0.05
Nodes (34): bool get, dart:io, epc_decoder.dart, cage, DecodedEpcData, decodeEpc, extractFilterValue, filterValue (+26 more)

### Community 12 - "RFID Manager - Setup Guide"
Cohesion: 0.06
Nodes (33): 1. Open Project in IDE, 2. Install Dependencies, 3. Verify Flutter Setup, 4. Build & Run, Android Studio Plugins (Recommended), Build Release APK, Build Variants, Code Architecture (+25 more)

### Community 13 - "record_types.dart"
Cohesion: 0.07
Nodes (28): AtaRecordType, AtaTagType, birth, contains, currentData, dualRecord, formatAtaDate, getAtaClassLabel (+20 more)

### Community 14 - "SDKMethods - RFID SDK Modül Yapısı"
Cohesion: 0.08
Nodes (25): 1. Tag Okuma, 2. Tag Yazma, 3. Tag Bulma, 🔤 ATA Modülü (`ata/`), AtaEncodingUtils.java, 🔧 Core Modülü (`core/`), EPC.java, Event Channels: (+17 more)

### Community 15 - "my_application.cc"
Cohesion: 0.10
Nodes (20): FlPluginRegistry, GApplication, gboolean, gchar, GObject, GtkApplication, fl_register_plugins(), main() (+12 more)

### Community 16 - "theme_constants.dart"
Cohesion: 0.09
Nodes (22): BoxDecoration, ButtonStyle, kBgCard, kBgLight, kBorderLight, kBorderMedium, kBrandNavy, kBrandNavyLight (+14 more)

### Community 17 - "LocationManager"
Cohesion: 0.21
Nodes (5): Context, EventSink, RFIDWithUHFUART, LocationManager, ToneGenerator

### Community 18 - "tag_list_item.dart"
Cohesion: 0.11
Nodes (20): TagItem, BoxCheckScanScreen, RecordCardWidget, RecordSectionsWidget, brandColor, build, filteredCount, index (+12 more)

### Community 19 - "qr_scan_screen.dart"
Cohesion: 0.10
Nodes (19): dart:async, build, _connected, _continuous, _copy, createState, dispose, _handleDecoded (+11 more)

### Community 20 - "win32_window.cpp"
Cohesion: 0.18
Nodes (14): Point, Size, wchar_t, Scale(), Create, Destroy, UpdateTheme, Win32Window::Win32Window() (+6 more)

### Community 21 - "lifecycle_dialog.dart"
Cohesion: 0.12
Nodes (16): DateTime?, _brandNavy, certificateNumber, currentPartNumber, expDateFormatted, expirationDate, lastOverhaulDate, LifecycleUpdateData (+8 more)

### Community 22 - "package:flutter/material.dart"
Cohesion: 0.12
Nodes (12): app_router.dart, bottomNavigationBar, activeLevel, build, _getBarColor, SignalBars, build, SplashScreen (+4 more)

### Community 23 - "six_bit_ascii.dart"
Cohesion: 0.12
Nodes (15): ascii6BitToHex, ascii8BitToHex, binary, binaryToHex, buffer, decode6BitString, encode6BitString, hexTo6BitAscii (+7 more)

### Community 24 - "variables.dart"
Cohesion: 0.12
Nodes (15): advancedView, advancedViewForBoxSlaves, colorDeneme1, colorDeneme2, colorDeneme3, colorDeneme4, devCounter, globalDataToWriteTag (+7 more)

### Community 25 - "FlutterWindow"
Cohesion: 0.13
Nodes (13): unique_ptr, DartProject, HWND, LPARAM, LRESULT, UINT, WPARAM, FlutterWindow (+5 more)

### Community 26 - "Color?"
Cohesion: 0.13
Nodes (12): Color?, backgroundColor, commonAppBar, textAndIconColor, backgroundColor, commonDrawer, textAndIconColor, package:rfid_manager/data/models/const.dart (+4 more)

### Community 27 - "diagnostic_screen.dart"
Cohesion: 0.13
Nodes (12): dart:convert, dart:developer, build, createState, _diagnosticResults, _isRunning, _runDiagnostic, package:rfid_manager/java_comm/rfid_c72_plugin.dart (+4 more)

### Community 28 - "tag_item.dart"
Cohesion: 0.13
Nodes (14): ataClass, cage, copyWith, filterValue, hashCode, operator, partNumber, rawEpc (+6 more)

### Community 29 - "List"
Cohesion: 0.26
Nodes (5): TagLocateListener, UserReadJob, AudioManager, List, Map

### Community 30 - "main_menu.dart"
Cohesion: 0.14
Nodes (13): IconData, accent, build, createState, _go, icon, onTap, subtitle (+5 more)

### Community 31 - "ata_constants.dart"
Cohesion: 0.14
Nodes (13): formatAtaDate, getAtaClassLabel, getAtaTagTypeLabel, getTeiFieldLabel, isDateField, kAscii6Map, kAscii6Reverse, kAtaClassNames (+5 more)

### Community 32 - "record_card_widget.dart"
Cohesion: 0.14
Nodes (13): _bgLight, _borderLight, _brandNavy, build, _cardTitleStyle, decodedUser, _labelStyle, record (+5 more)

### Community 33 - "Win32Window"
Cohesion: 0.20
Nodes (14): RECT, OnCreate, OnDestroy, HWND, Win32Window, child_content_, GetClientArea, OnCreate (+6 more)

### Community 34 - "filter_options.dart"
Cohesion: 0.17
Nodes (11): FilterOption, int get, FilterOption, getAllFilterOptions, getFilterDisplayLabel, hashCode, id, kFilterAll (+3 more)

### Community 35 - "wWinMain"
Cohesion: 0.24
Nodes (9): _In_, _In_opt_, vector, wWinMain(), string, wchar_t, CreateAndAttachConsole(), GetCommandLineArguments() (+1 more)

### Community 36 - "app_router.dart"
Cohesion: 0.17
Nodes (10): build, main, MyApp, AppRouter, onGenerateRoute, pageNames, package:flutter/services.dart, package:rfid_manager/ui/screens/main_menu/main_menu.dart (+2 more)

### Community 37 - "button_with_text_and_value.dart"
Cohesion: 0.17
Nodes (11): build, ButtonWithTextAndValue, _getCardColor, isSelected, onTap, secondValue, selectedColor, title (+3 more)

### Community 38 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 39 - "location_status_widget.dart"
Cohesion: 0.20
Nodes (9): int?, activeLevel, build, getBarColor, getBarLevel, isLocating, LocationStatusWidget, _SignalBars (+1 more)

### Community 40 - "State"
Cohesion: 0.27
Nodes (10): _BoxCheckScanBody, _BoxCheckScanBodyState, DiagnosticScreen, _DiagnosticScreenState, MainMenu, _MainMenuState, QrScanScreen, _QrScanScreenState (+2 more)

### Community 41 - "MessageHandler"
Cohesion: 0.36
Nodes (10): HWND, LPARAM, LRESULT, UINT, WPARAM, EnableFullDpiSupportIfAvailable(), GetHandle, GetThisFromHandle (+2 more)

### Community 42 - "const.dart"
Cohesion: 0.22
Nodes (8): boxTagNo, collectionPath, filterExpCheck, filterNone, maxPowerLevel, minPowerLevel, tagType, toolTagNo

### Community 43 - "menu_card.dart"
Cohesion: 0.22
Nodes (8): build, CardTapCallback, description, imageUrl, MenuCard, onTap, title, typedef

### Community 44 - "RFID Manager"
Cohesion: 0.22
Nodes (8): Gereksinimler, Hangi Standart?, Kurulum, Ne İçin Kullanılır?, Ne İşe Yarar?, Proje Yapısı, RFID Manager, Özellikler

### Community 45 - "widgets.dart"
Cohesion: 0.25
Nodes (6): package:rfid_manager/ui/screens/box_check_scan_screen/box_check_scan_screen.dart, package:rfid_manager/ui/screens/box_check_scan_screen/excel_export_helper.dart, package:rfid_manager/ui/screens/box_check_scan_screen/widgets/widgets.dart, package:rfid_manager/ui/widgets/button_with_text_and_value.dart, package:rfid_manager/ui/widgets/list_builder.dart, package:rfid_manager/ui/widgets/menu_card.dart

### Community 46 - "rfid_status.dart"
Cohesion: 0.29
Nodes (6): connectingStatus, getFrequencyMode, getPower, getTemperature, platformName, RfidStatus

### Community 48 - "widgets.dart"
Cohesion: 0.33
Nodes (5): lifecycle_dialog.dart, location_status_widget.dart, record_card_widget.dart, signal_bars_widget.dart, tag_list_item.dart

### Community 49 - "GeneratedPluginRegistrant.java"
Cohesion: 0.60
Nodes (3): GeneratedPluginRegistrant, FlutterEngine, Keep

### Community 50 - "gradlew"
Cohesion: 0.60
Nodes (3): gradlew script, die(), warn()

### Community 51 - "shared.dart"
Cohesion: 0.50
Nodes (3): constants/constants.dart, models/models.dart, widgets/widgets.dart

### Community 52 - "features.dart"
Cohesion: 0.50
Nodes (3): scan/scan.dart, tag_detail/tag_detail.dart, tag_write/tag_write.dart

### Community 53 - "constants.dart"
Cohesion: 0.50
Nodes (3): package:rfid_manager/core/ata_spec/record_types.dart, package:rfid_manager/ui/screens/box_check_scan_screen/filter_options.dart, package:rfid_manager/ui/screens/box_check_scan_screen/theme_constants.dart

## Knowledge Gaps
- **701 isolated node(s):** `flutter_export_environment.sh script`, `+registerWithRegistry`, `DecodedEpcData`, `headerBits`, `filterValue` (+696 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `UHFHelper` connect `.getInstance` to `List`?**
  _High betweenness centrality (0.069) - this node is a cross-community bridge._
- **Why does `UHFManager` connect `UHFManager` to `.getReader`, `List`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **Why does `InventoryManager` connect `InventoryManager` to `List`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **What connects `flutter_export_environment.sh script`, `+registerWithRegistry`, `DecodedEpcData` to the rest of the system?**
  _701 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `epc_user_codec.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.017857142857142856 - nodes in this community are weakly interconnected._
- **Should `.getInstance` be split into smaller, more focused modules?**
  _Cohesion score 0.05713058419243986 - nodes in this community are weakly interconnected._
- **Should `.getReader` be split into smaller, more focused modules?**
  _Cohesion score 0.09107737874861163 - nodes in this community are weakly interconnected._