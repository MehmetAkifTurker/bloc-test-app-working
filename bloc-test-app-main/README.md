# RFID Manager

## Ne İşe Yarar?

RFID etiketlerini okuma, yazma ve yönetme uygulamasıdır. Uçak parçalarına takılan RFID tagleri:

- **Okur** ve içindeki verileri çözümler
- **Yazar** ve yeni tag programlar
- **Günceller** (yaşam döngüsü kayıtları)
- **Bulur** (sinyal gücüyle konumlandırır)

## Ne İçin Kullanılır?

Havacılık sektöründe uçak parçalarının takibi için kullanılır:

- **Parça Kimliği:** Her parçanın seri numarası, üretici bilgisi
- **Yaşam Döngüsü:** Bakım tarihleri, sertifikalar, son kullanma
- **Envanter:** Depo ve uçak üzerindeki parçaların taranması
- **Doğrulama:** Parça orijinalliğinin kontrolü

## Hangi Standart?

**ATA Spec 2000 Chapter 9** - Havacılık endüstrisinin RFID standardı:

- 6-bit ASCII kodlama
- Birth Record (doğum kaydı) + Lifecycle Record (yaşam döngüsü)
- TEI alanları: PNR, PML, EXP, CER, DOH

## Özellikler

- **Tag Okuma:** Çoklu tag tarama, EPC+TID+USER memory
- **Tag Yazma:** Single/Dual/Multi-Record programlama
- **Yaşam Döngüsü:** Dual-Record taglerde lifecycle güncelleme
- **Tag Bulma:** Sinyal gücü ile tag konumlama
- **Excel Export:** Tag listesini dışa aktarma

## Kurulum

```bash
flutter pub get
flutter run
```

## Proje Yapısı

```
lib/
├── models/              # Veri modelleri
├── java_comm/           # Native köprü
└── ui/screens/          # Ekranlar

android/.../SDKMethods/
├── core/                # UHFManager, Listener, EPC, TagKey
├── inventory/           # InventoryManager (tarama)
├── reader/              # MemoryReader (okuma)
├── writer/              # MemoryWriter (yazma)
├── location/            # LocationManager (bulma)
└── ata/                 # AtaEncodingUtils (kodlama)
```

## Gereksinimler

- Flutter 3.0+
- C66 RFID Reader
- Android

---

**Version:** 1.0.0 | **Platform:** Android
