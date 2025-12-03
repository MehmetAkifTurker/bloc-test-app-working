# RFID Manager - Setup Guide

## Initial Setup

### 1. Open Project in IDE

**VS Code / Cursor:**

```bash
cd bloc-test-app-main
code .
```

**Android Studio:**

- File → Open → Select `bloc-test-app-main` folder

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Verify Flutter Setup

```bash
flutter doctor
```

Expected output:

- ✅ Flutter (3.0+)
- ✅ Android toolchain
- ✅ Connected device (C66 RFID Reader)

### 4. Build & Run

```bash
# First run (clean build)
flutter clean
flutter pub get
flutter run

# Subsequent runs
flutter run
```

---

## Troubleshooting

### Issue: Gradle "com.android.library not found"

**Cause:** IDE trying to build `my_rfid_plugin` as standalone project

**Solution 1 - Recommended:**
Close and reopen IDE. The plugin will build automatically with main project.

**Solution 2 - Manual:**

```bash
flutter clean
flutter pub get
```

**Solution 3 - IDE Settings:**
Already configured in `.vscode/settings.json`:

- Plugin folder excluded from Java indexing
- Build configuration disabled for plugin

### Issue: Hot Reload Not Working

**Solution:**

```bash
# Full restart
flutter run
# Then press 'R' for hot restart
```

### Issue: USB Device Not Detected

**Solution:**

```bash
# Check connected devices
flutter devices

# Enable USB debugging on C66
# Settings → Developer Options → USB Debugging
```

### Issue: Build Fails

**Solution:**

```bash
# Clean all build artifacts
flutter clean
cd android
./gradlew clean
cd ..

# Rebuild
flutter pub get
flutter run
```

---

## IDE-Specific Setup

### VS Code Extensions (Recommended)

- Dart
- Flutter
- Flutter Widget Snippets (optional)

### Android Studio Plugins (Recommended)

- Flutter
- Dart

### Cursor (Already Configured)

- `.vscode/settings.json` includes all necessary configs
- Dart formatting on save enabled
- Auto-fix on save enabled

---

## Build Variants

### Debug Build

- Includes debug logs
- Larger APK size
- Hot reload enabled

```bash
flutter build apk --debug
```

### Release Build

- No debug logs (kDebugMode checks)
- Optimized & minified
- Smaller APK size

```bash
flutter build apk --release
```

### Profile Build (Performance Testing)

```bash
flutter build apk --profile
flutter run --profile
```

---

## Configuration Files

### Key Files

- `pubspec.yaml` - Dependencies
- `android/app/build.gradle` - Android config
- `android/app/src/main/AndroidManifest.xml` - App name & permissions
- `.vscode/settings.json` - IDE configuration

### Don't Edit

- `my_rfid_plugin/android/build.gradle` - Auto-managed by Flutter
- `.dart_tool/` - Generated files
- `build/` - Build outputs

---

## First Time Setup Checklist

- [ ] Open project in IDE
- [ ] Run `flutter pub get`
- [ ] Run `flutter doctor` (verify setup)
- [ ] Connect C66 RFID Reader via USB
- [ ] Run `flutter devices` (verify device detected)
- [ ] Run `flutter run` (first build takes ~2 minutes)
- [ ] Test scan function with RFID tags
- [ ] Test tag write function
- [ ] Test Excel export
- [ ] Verify app name shows as "RFID Manager"

---

## Daily Development Workflow

```bash
# Morning startup
cd bloc-test-app-main
flutter run

# During development
# Press 'r' for hot reload
# Press 'R' for hot restart
# Press 'q' to quit

# Before committing code
flutter analyze
flutter test (if tests exist)
```

---

## Production Deployment

### Build Release APK

```bash
flutter build apk --release --split-per-abi
```

### Outputs

```
build/app/outputs/flutter-apk/
├── app-armeabi-v7a-release.apk  (32-bit ARM)
├── app-arm64-v8a-release.apk    (64-bit ARM - use this for C66)
└── app-x86_64-release.apk       (x86 64-bit)
```

### Install on Device

```bash
# Via USB
flutter install

# Or manually
# 1. Copy app-arm64-v8a-release.apk to device
# 2. Install via file manager
# 3. Launch "RFID Manager"
```

---

## 📂 Project Structure (Developer Reference)

```
lib/
├── main.dart                          # App entry point
├── models/
│   └── tag_item.dart                  # TagItem model (EPC, TID, USER)
├── java_comm/
│   └── rfid_c72_plugin.dart          # Flutter ↔ Java bridge
└── ui/
    ├── router/                        # Navigation & routing
    ├── screens/
    │   ├── box_check_scan_screen/     # 🔍 Main scan & detail
    │   ├── tag_write_screen/          # ✍️ Tag writing
    │   └── main_menu/                 # Home screen
    └── widgets/                       # Reusable components

my_rfid_plugin/android/src/main/java/
├── UHFHelper.java                     # Core RFID operations
├── RfidC72Plugin.java                 # Method channel handler
└── MainActivity.java                  # Hardware key handling
```

### Key Files to Know

**Core Logic:**

- `UHFHelper.java` - RFID SDK wrapper (128-word USER read, EPC+TID+USER mode)
- `epc_user_codec.dart` - ATA Spec 2000 decoder (ToC, Records, TEI fields)
- `box_check_scan_screen.dart` - Main scanning logic
- `tag_detail_screen.dart` - Tag details & lifecycle update

**Configuration:**

- `android/app/build.gradle` - App version, SDK versions
- `pubspec.yaml` - Flutter dependencies
- `AndroidManifest.xml` - App name, permissions

---

## 🎯 Development Tips

### Code Architecture

- **Identity:** Tags use `EPC|TID` combination (see `TagItem.uniqueId`)
- **Caching:** USER memory cached per unique ID
- **SDK Mode:** `setEPCAndTIDUserMode(0, 128)` in `UHFHelper.connect()`
- **Scan Speed:** 400ms interval in `_toggleScan()`

### Common Modifications

**Change scan speed:**

```dart
// box_check_scan_screen.dart line ~1670
Timer.periodic(const Duration(milliseconds: 400), ...)
```

**Change USER memory size:**

```java
// UHFHelper.java line ~119
mReader.setEPCAndTIDUserMode(0, 128);
```

**Change theme color:**

```dart
// Search for: Color(0xFF003B5C)
// Replace with your brand color
```

---

**Setup Time:** ~5 minutes  
**First Build:** ~2 minutes  
**Subsequent Builds:** ~30 seconds

---

**Application:** RFID Manager v1.0.0  
**Status:** Production Ready ✅
