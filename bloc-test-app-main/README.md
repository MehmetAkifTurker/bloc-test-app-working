# RFID Manager

Professional RFID tag reading, writing, and lifecycle management application for Turkish Airlines, built with Flutter and compliant with ATA Spec 2000.

## Features

### 📖 Tag Reading
- **Real-time multi-tag scanning** with EPC+TID+USER memory
- **ATA Spec 2000 compliant** decoding (Birth, Lifecycle, Current Data records)
- **128-word USER memory** support (SRT, DRT, MRT tag types)
- **Tag location** feature with signal strength indicator
- **Excel export** functionality

### ✍️ Tag Writing
- **Single/Dual/Multi-Record** tag programming
- **Configurable chip settings** (EPC, USER, Permalock)
- **6-bit ASCII encoding** per ATA Spec
- **Chunked writing** for large payloads

### 🔄 Lifecycle Management
- **Update lifecycle records** on Dual-Record tags
- **TEI field management** (PNR, PML, EXP, CER, DOH)
- **Date validation** and formatting

### 🎨 UI/UX
- **Turkish Airlines branding** (Navy blue theme)
- **Responsive design** with optimized layouts
- **Material Design** components
- **Real-time updates** and visual feedback

## Quick Start

### Prerequisites
- Flutter SDK (3.0+)
- Android Studio / VS Code
- C66 RFID Reader (or compatible UHF RFID device)

### Installation

```bash
# Navigate to project directory
cd bloc-test-app-main

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Or build release APK
flutter build apk --release
```

### Building

```bash
# Debug build
flutter build apk --debug

# Release build
flutter build apk --release
```

## Usage

1. **Launch:** Open "RFID Manager" app
2. **Scan Tags:** Press hardware scan button or tap "Start Scan"
3. **View Details:** Tap any tag to see full information
4. **Update Lifecycle:** For Dual-Record tags, use "Update Lifecycle" button
5. **Export Data:** Share tag list via Excel file
6. **Write New Tags:** Use Tag Write screen from main menu

## Technical Stack

- **Framework:** Flutter 3.x
- **Language:** Dart, Java
- **RFID SDK:** DeviceAPI (C66 compatible)
- **Platform:** Android
- **Spec:** ATA Spec 2000 Chapter 9

## Configuration

### RFID Settings
- **Power Level:** 5-30 dBm (adjustable)
- **Scan Mode:** EPC+TID+USER (128 words)
- **Scan Interval:** 400ms for optimal performance
- **TagFocus:** Enabled for multi-tag detection

### Supported Tag Types
| Type | Description | Capacity | Records |
|------|-------------|----------|---------|
| SRT  | Single Birth Record | ~32 words | Birth only |
| DRT  | Dual Record | ~55 words | Birth + Lifecycle |
| MRT  | Multi Record | 100+ words | Birth + Multiple |

## Documentation

- **Setup Guide:** See [SETUP.md](SETUP.md) for installation and troubleshooting
- **ATA Spec:** See [304-Spec2000_AIDCCh9v2020dot1.pdf](304-Spec2000_AIDCCh9v2020dot1.pdf)
- **SDK Docs:** See [RFIDWithUHFUART.html](RFIDWithUHFUART.html) and [IUHF.html](IUHF.html)

## Project Structure

```
lib/
├── main.dart                     # Entry point
├── models/                       # Data models
├── java_comm/                    # Native bridge
└── ui/
    ├── screens/                  # Screen widgets
    │   ├── box_check_scan_screen/  # Tag scanning
    │   └── tag_write_screen/       # Tag writing
    ├── router/                   # Navigation
    └── widgets/                  # Reusable components

my_rfid_plugin/
└── android/                      # Native Android code
    └── src/main/java/
        └── ...my_rfid_plugin/
            ├── UHFHelper.java    # Core RFID logic
            └── RfidC72Plugin.java # Flutter bridge
```

## License

Proprietary - Turkish Airlines

## Support

For technical questions, contact the development team.

---

**Application:** RFID Manager  
**Version:** 1.0.0  
**Last Updated:** December 2025  
**Platform:** Android (C66 RFID Reader)  
**Client:** Turkish Airlines
