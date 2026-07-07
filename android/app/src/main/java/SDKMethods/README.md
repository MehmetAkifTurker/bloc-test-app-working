# SDKMethods - RFID SDK Modül Yapısı

Bu klasör, C66/C72 RFID cihazları için ATA Spec 2000 uyumlu okuma/yazma işlemlerini yöneten Java kodlarını içerir.

## 📁 Klasör Yapısı

```
SDKMethods/
│
├── MainActivity.java          ─ Android uygulama giriş noktası
├── RfidC72Plugin.java         ─ Flutter MethodChannel plugin
├── UHFHelper.java             ─ Facade (tüm işlemleri delege eder)
│
├── core/                      ─ Temel bileşenler
│   ├── UHFManager.java        ─ Bağlantı, güç, barkod yönetimi
│   ├── UHFListener.java       ─ Event listener arayüzü
│   ├── EPC.java               ─ Tag veri modeli
│   └── TagKey.java            ─ JSON anahtar sabitleri
│
├── inventory/                 ─ Tarama işlemleri
│   └── InventoryManager.java  ─ Envanter, tag listesi yönetimi
│
├── reader/                    ─ Bellek okuma işlemleri
│   └── MemoryReader.java      ─ USER memory okuma
│
├── writer/                    ─ Bellek yazma işlemleri
│   └── MemoryWriter.java      ─ EPC/USER memory yazma
│
├── location/                  ─ Tag bulma özelliği
│   └── LocationManager.java   ─ Sinyal gücü ile tag konumlama
│
└── ata/                       ─ ATA Spec 2000 encoding
    └── AtaEncodingUtils.java  ─ 6-bit encoding, CRC hesaplama
```

---

## 🔧 Core Modülü (`core/`)

### UHFManager.java
RFID okuyucu bağlantısı ve temel yapılandırma.

```java
// Singleton erişim
UHFManager.getInstance()

// Önemli Metodlar
.connect()              // RFID okuyucuya bağlan
.close()                // Bağlantıyı kapat
.isConnected()          // Bağlantı durumu

// Güç & Frekans
.setPowerLevel("30")    // Okuma gücü (1-30 dBm)
.getPowerLevel()        // Mevcut güç seviyesi
.setWorkArea("1")       // Frekans bölgesi
.getFrequencyMode()     // Mevcut frekans modu
.getTemperature()       // Cihaz sıcaklığı

// Filtre
.setEpcFilter(epcHex)   // EPC filtresi ayarla
.clearFilter()          // Filtreyi temizle

// Barkod
.connectBarcode()       // Barkod okuyucu bağla
.scanBarcode()          // Barkod tarama başlat
.stopScan()             // Taramayı durdur
.readBarcode()          // Son okunan barkod

// Ses
.playSound()            // Başarı sesi
.playErrorSound()       // Hata sesi
```

### UHFListener.java
Tag okuma ve bağlantı olayları için arayüz.

```java
public abstract class UHFListener {
    void onRead(String tagsJson);                    // Tag okunduğunda
    void onConnect(boolean isConnected, int power);  // Bağlantı değiştiğinde
}
```

### EPC.java
Okunan tag'ı temsil eden veri modeli.

```java
EPC tag = new EPC();
tag.setEpc("3B0E1234...");   // EPC hex değeri
tag.setRssi("-45");          // Sinyal gücü
tag.setCount("5");           // Okuma sayısı
```

---

## 📡 Inventory Modülü (`inventory/`)

### InventoryManager.java
Tag tarama ve envanter yönetimi.

```java
// Singleton erişim
InventoryManager.getInstance()

// Tarama Kontrolü
.start(true)            // Tek tag okuma
.start(false)           // Sürekli tarama başlat
.stop()                 // Taramayı durdur
.isStarted()            // Tarama durumu
.clearData()            // Tag listesini temizle
.isEmptyTags()          // Liste boş mu?

// Tag Okuma
.readSingleTagEPC()     // Tek tag EPC oku
.readSingleTagMeta()    // Tag meta bilgileri (EPC, TID, USER, RSSI)
.scanMultipleTags(10)   // Birden fazla tag tara

// Tag Listesi
.getCurrentTagsJson()   // Tüm tagleri JSON olarak al
```

**readSingleTagMeta() Dönüş Formatı:**
```json
{
  "epc": "3B0E1234ABCD...",
  "tid": "E200341201...",
  "rssi": "-42",
  "validTid": true,
  "userMemory": "1E00..."
}
```

---

## 📖 Reader Modülü (`reader/`)

### MemoryReader.java
USER memory okuma işlemleri (ATA Spec 2000 uyumlu).

```java
// Singleton erişim
MemoryReader.getInstance()

// Temel Okuma
.readUserMemory()                    // En yakın tag'ın USER belleği

// EPC Filtreli Okuma (Chunked, Retry destekli)
.readUserMemoryForEpcFull(epcHex)    // EPC ile filtreleyerek tam okuma
.readUserMemoryForEpcWithFilter(epc) // SDK filter ile okuma

// TID Filtreli Okuma
.readUserMemoryForTid(tidHex)        // TID ile filtreleyerek okuma

// ATA Field Parsing
.readUserFieldsForEpc(epcHex)        // Decode edilmiş alanlar

// Diagnostik
.diagnosticReadSingleTag()           // Detaylı tag analizi
```

**readUserFieldsForEpc() Dönüş Formatı:**
```json
{
  "rawHex": "1E00...",
  "rawText": "MFR BOEING*PNR 123-456*SER ABC123*...",
  "MFR": "BOEING",
  "PNR": "123-456",
  "SER": "ABC123",
  "DMF": "20240101",
  "EXP": "20290101",
  "PDT": "GASKET",
  "UIC": "2"
}
```

**Chunked Reading Özellikleri:**
- 32 word'lük parçalar halinde okur
- ToC header'dan toplam boyutu parse eder
- Başarısız chunk'lar için 3 deneme yapar
- 512 word'e kadar dinamik okuma

---

## ✏️ Writer Modülü (`writer/`)

### MemoryWriter.java
EPC ve USER memory yazma işlemleri.

```java
// Singleton erişim
MemoryWriter.getInstance()

// Chip Yapılandırma
.prepareAtaChip(
    "DRT",           // recordType: "SRT", "DRT", "MRT"
    12,              // epcWords
    32,              // userWords
    0,               // permalockWords
    false,           // enablePermalock
    false,           // lockEpc
    false,           // lockUser
    "00000000"       // accessPwd
)

// EPC Yazma
.writeTagADIConstruct2(partNumber, serialNumber)
.programConstruct2Epc(partNumber, serialNumber, manager, pwd, filter)

// USER Memory Yazma (ATA Format)
.writeAtaUserMemoryWithPayload(
    manufacturer,    // "BOEING"
    productName,     // "GASKET"
    partNumber,      // "123-456"
    serialNumber,    // "ABC123"
    manufactureDate, // "20240101"
    expireDate       // "20290101"
)

// Lifecycle Record Güncelleme (DRT tag'lar için)
.updateLifecycleRecord(
    epcHex,
    currentPartNumber,
    partModLevel,
    expirationDate,
    certificateNumber,
    lastOverhaulDate
)
```

**Desteklenen Tag Tipleri:**
| Tip | Açıklama | ToC |
|-----|----------|-----|
| SRT | Single Birth-Record | Short ToC (4 word header) |
| DRT | Dual-Record (Birth + Lifecycle) | Full ToC + RDs |
| MRT | Multi-Record | Full ToC + Multiple RDs |

---

## 📍 Location Modülü (`location/`)

### LocationManager.java
Tag konumlama (sinyal gücü takibi).

```java
// Singleton erişim
LocationManager.getInstance()

// Konum Takibi
.startLocation(context, epcLabel, bank, ptr)  // Takibi başlat
.stopLocation()                                // Takibi durdur

// Flutter Event Stream
LocationManager.setLocationSink(eventSink)    // Sinyal değerlerini stream et
```

**Sinyal Değerleri:** 0-100 arası (100 = en yakın)

---

## 🔤 ATA Modülü (`ata/`)

### AtaEncodingUtils.java
ATA Spec 2000 encoding/decoding utilities.

```java
// 6-bit Encoding (GS1/ATA)
AtaEncodingUtils.encode6Bit("BOEING")           // → "000010001111..."
AtaEncodingUtils.decode6Bit(bits)               // → "BOEING"

// USER Memory Decode
AtaEncodingUtils.decodeUserPayloadHexToText(hex) // Header'ı atla, payload decode
AtaEncodingUtils.parseAtaUserText(text)          // "*MFR X*PNR Y*" → Map

// CRC-16/CCITT
AtaEncodingUtils.calculateCrc16Ccitt(hexData)   // ATA Spec Appendix A

// Tag Type Mapping
AtaEncodingUtils.mapAtaTagType("DRT")           // → 0x0001

// Binary/Hex Dönüşüm
AtaEncodingUtils.bitsToHex(bits)
AtaEncodingUtils.hexToBinary(hex)
AtaEncodingUtils.binaryToHex(binary)
```

**6-bit Karakter Tablosu:**
- A-Z: 000001-011010
- 0-9: 110000-111001
- Space: 100000
- Özel: *, -, /, :, vb.

---

## 🔌 Flutter Entegrasyonu

### RfidC72Plugin.java
Flutter MethodChannel bridge.

**Desteklenen Method Çağrıları:**
```dart
// Dart tarafından çağrılabilir metodlar:
await channel.invokeMethod('connect');
await channel.invokeMethod('readSingleTagMeta');
await channel.invokeMethod('readUserMemoryForEpcFull', {'epc': epcHex});
await channel.invokeMethod('writeAtaUserMemoryWithPayload', {
  'manufacturer': 'BOEING',
  'partNumber': '123-456',
  ...
});
```

### Event Channels:
| Channel | Açıklama |
|---------|----------|
| `ConnectedStatus` | Bağlantı durumu stream |
| `TagsStatus` | Okunan taglar stream |
| `LocationStatus` | Konum sinyal gücü stream |

---

## 📋 UHFHelper.java (Facade)

Tüm işlemleri tek noktadan yöneten facade sınıfı. Geriye dönük uyumluluk sağlar.

```java
// Tüm işlemler buradan erişilebilir
UHFHelper.getInstance().connect();
UHFHelper.getInstance().readSingleTagMeta();
UHFHelper.getInstance().writeAtaUserMemoryWithPayload(...);
```

---

## 🔄 Tipik Kullanım Akışları

### 1. Tag Okuma
```java
// Bağlan
UHFManager.getInstance().connect();

// Tek tag oku
String meta = InventoryManager.getInstance().readSingleTagMeta();

// USER memory oku (EPC filtreli)
String userHex = MemoryReader.getInstance().readUserMemoryForEpcFull(epcHex);
```

### 2. Tag Yazma
```java
// Chip hazırla
MemoryWriter.getInstance().prepareAtaChip("DRT", 12, 32, 0, false, false, false, "00000000");

// EPC yaz
MemoryWriter.getInstance().programConstruct2Epc(partNumber, serialNumber, " TG424", "00000000", 14);

// USER memory yaz
MemoryWriter.getInstance().writeAtaUserMemoryWithPayload(
    "BOEING", "GASKET", "123-456", "ABC123", "20240101", "20290101"
);
```

### 3. Tag Bulma
```java
// Konum takibi başlat
LocationManager.getInstance().startLocation(context, epcHex, 1, 32);

// ... sinyal değerleri LocationSink'e gelir ...

// Durdur
LocationManager.getInstance().stopLocation();
```

---

## 📝 Notlar

- Tüm manager sınıfları **Singleton** pattern kullanır
- Memory okuma işlemleri **synchronized** metodlardır
- Chunked reading 32 word'lük parçalar kullanır
- Retry mekanizması 3 deneme ve 50-80ms delay içerir
- ATA Spec 2000 v2020.1 standartlarına uygundur

