package com.example.my_rfid_plugin;

import android.content.Context;
import android.media.MediaPlayer;
import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;
import io.flutter.plugin.common.EventChannel;

import com.rscja.barcode.BarcodeDecoder;
import com.rscja.barcode.BarcodeFactory;
import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;
import com.rscja.deviceapi.interfaces.IUHFLocationCallback;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;

public class UHFHelper {

    private static final String TAG = "UHFHelper";

    private static UHFHelper instance;

    private UHFHelper() {
    } // Singleton

    // Fields
    private RFIDWithUHFUART mReader;
    private BarcodeDecoder barcodeDecoder;
    private UHFListener uhfListener;
    private Handler handler;
    private boolean isStart = false;
    private boolean isConnect = false;
    private HashMap<String, EPC> tagList;
    private String scannedBarcode;
    private Context context;
    private static EventChannel.EventSink locationSink;
    static ArrayList<String> tempTags = new ArrayList<>();
    private String currentRecordType = "DRT";
    private int currentEpcWords = 12;
    private int currentUserWords = 32;
    private int currentPermalockWords = 0;

    // Singleton accessor
    public static UHFHelper getInstance() {
        if (instance == null) {
            instance = new UHFHelper();
        }
        return instance;
    }

    // Initialization
    public void init(Context context) {
        this.context = context;
        tagList = new HashMap<>();
        clearData();
        handler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                String result = (String) msg.obj;
                String[] strs = result.split("@");
                if (strs.length == 2) {
                    // SAFETY: Clean EPC from any prefixes
                    String cleanEpc = strs[0].replace("EPC:", "").trim();
                    int idx = cleanEpc.indexOf('\n');
                    if (idx >= 0)
                        cleanEpc = cleanEpc.substring(idx + 1).trim();

                    addEPCToList(cleanEpc, strs[1]);
                    Log.d(TAG, "✅ HANDLER: Clean EPC added: " + cleanEpc);
                }
            }
        };
    }

    public boolean connect() {
        try {
            mReader = RFIDWithUHFUART.getInstance();
        } catch (Exception ex) {
            Log.e(TAG, "RFIDWithUHFUART getInstance failed", ex);
            if (uhfListener != null)
                uhfListener.onConnect(false, 0);
            return false;
        }

        if (mReader == null) {
            if (uhfListener != null)
                uhfListener.onConnect(false, 0);
            return false;
        }

        isConnect = mReader.init(context);
        if (uhfListener != null)
            uhfListener.onConnect(isConnect, 0);

        if (isConnect) {
            try {
                // CORRECTED: Use InventoryModeEntity to properly configure scanning
                Log.i(TAG, "🔧 MODE-CONFIG: Configuring proper scanning mode");

                // Simple configuration without complex mode checking
                Log.i(TAG, "🔧 SIMPLE-SETUP: Configuring for TID+USER reading");

                // Set EPC+TID+USER mode (mode 2)
                boolean allModeSet = mReader.setEPCAndTIDUserMode(0, 32);
                Log.i(TAG, "🔧 SET-MODE: EPC+TID+USER mode set result: " + allModeSet);

                // Simple verification
                Thread.sleep(100);
                Log.i(TAG, "🔧 SETUP-COMPLETE: TID+USER configuration completed");

            } catch (Exception e) {
                Log.w(TAG, "🔧 CONFIG: Failed to configure scanning modes: " + e.getMessage());
            }

            try {
                mReader.setTagFocus(true);
                Log.i(TAG, "🔧 CONFIG: TagFocus enabled");
            } catch (Exception ignore) {
                Log.w(TAG, "🔧 CONFIG: TagFocus not available");
            }

            try {
                mReader.setFastID(false); // Disable FastID for better TID/USER reading
                Log.i(TAG, "🔧 CONFIG: FastID disabled for better TID/USER reading");
            } catch (Exception ignore) {
                Log.w(TAG, "🔧 CONFIG: FastID control not available");
            }
        }
        return isConnect;
    }

    public void close() {
        isStart = false;
        if (mReader != null) {
            mReader.free();
            mReader = null;
        }
        isConnect = false;
        clearData();
    }

    // Basic status
    public boolean isConnected() {
        return isConnect;
    }

    public boolean isStarted() {
        return isStart;
    }

    public boolean isEmptyTags() {
        return (tagList == null || tagList.isEmpty());
    }

    // Barcode methods
    public boolean connectBarcode() {
        if (barcodeDecoder == null) {
            barcodeDecoder = BarcodeFactory.getInstance().getBarcodeDecoder();
        }
        if (barcodeDecoder != null) {
            Log.d(TAG, "Barcode open()");
            barcodeDecoder.open(context);
            barcodeDecoder.setDecodeCallback(entity -> {
                if (entity.getResultCode() == BarcodeDecoder.DECODE_SUCCESS) {
                    scannedBarcode = entity.getBarcodeData();
                    Log.d(TAG, "Decode SUCCESS: " + scannedBarcode);
                } else {
                    scannedBarcode = "";
                    Log.d(TAG, "Decode FAIL rc=" + entity.getResultCode());
                }
            });
            return true;
        }
        Log.e(TAG, "Barcode decoder is null");
        return false;
    }

    public boolean scanBarcode() {
        if (barcodeDecoder != null) {
            barcodeDecoder.startScan();
            return true;
        }
        return false;
    }

    public boolean stopScan() {
        if (barcodeDecoder != null) {
            barcodeDecoder.stopScan();
            return true;
        }
        return false;
    }

    public boolean closeScan() {
        if (barcodeDecoder != null) {
            barcodeDecoder.close();
            barcodeDecoder = null;
        }
        return true;
    }

    public String readBarcode() {
        return (scannedBarcode != null) ? scannedBarcode : "";
    }

    public boolean playSound() {
        MediaPlayer.create(context, R.raw.barcodebeep).start();
        return true;
    }

    // Reader configuration
    public boolean setPowerLevel(String level) {
        if (mReader != null) {
            int pwr = Integer.parseInt(level);
            return mReader.setPower(pwr);
        }
        return false;
    }

    public boolean setWorkArea(String area) {
        if (mReader != null) {
            int mode = Integer.parseInt(area);
            return mReader.setFrequencyMode(mode);
        }
        return false;
    }

    public void clearData() {
        if (tagList != null) {
            tagList.clear();
        }
    }

    public String getPowerLevel() {
        if (mReader != null) {
            try {
                int power = mReader.getPower();
                return String.valueOf(power);
            } catch (Exception e) {
                return "Error getPowerLevel: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    public String getFrequencyMode() {
        if (mReader != null) {
            try {
                int freqMode = mReader.getFrequencyMode();
                return String.valueOf(freqMode);
            } catch (Exception e) {
                return "Error getFrequencyMode: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    public String getTemperature() {
        if (mReader != null) {
            try {
                int temp = mReader.getTemperature();
                return String.valueOf(temp);
            } catch (Exception e) {
                return "Error getTemperature: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    // Inventory
    public boolean start(boolean isSingleRead) {
        if (mReader == null)
            return false;
        if (!isStart) {
            if (isSingleRead) {
                UHFTAGInfo info = mReader.inventorySingleTag();
                if (info != null) {
                    addEPCToList(info.getEPC(), info.getRssi());
                    return true;
                } else {
                    return false;
                }
            } else {
                if (mReader.startInventoryTag()) {
                    isStart = true;
                    new TagThread().start();
                    return true;
                }
                return false;
            }
        }
        return true;
    }

    public boolean stop() {
        if (isStart && mReader != null) {
            isStart = false;
            return mReader.stopInventory();
        }
        isStart = false;
        clearData();
        return false;
    }

    // Single EPC read with TID support
    public synchronized String readSingleTagEPC() {
        if (mReader == null) {
            Log.e(TAG, "❌ DEBUG: mReader is null, cannot readSingleTagEPC");
            return "";
        }

        try {
            Log.d(TAG, "🔍 DEBUG: Calling inventorySingleTag()");
            UHFTAGInfo info = mReader.inventorySingleTag();

            if (info != null) {
                String epcHex = info.getEPC();
                String tid = info.getTid();
                String rssi = info.getRssi();

                Log.i(TAG, "✅ DEBUG: Read single tag:");
                Log.i(TAG, "✅   EPC: " + epcHex);
                Log.i(TAG, "✅   TID: " + tid);
                Log.i(TAG, "✅   RSSI: " + rssi);

                return epcHex;
            } else {
                Log.d(TAG, "🔍 DEBUG: inventorySingleTag() returned null");
                return "";
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ DEBUG: Exception in readSingleTagEPC: " + e.getMessage());
            return "";
        }
    }

    // OPTIMIZED: Stable tag reading with better timing
    public synchronized String readSingleTagWithTid() {
        if (mReader == null) {
            Log.e(TAG, "mReader is null, cannot readSingleTagWithTid");
            return "";
        }

        try {
            Log.d(TAG, "🔍 STABLE-READ: Attempting stable tag detection");

            UHFTAGInfo info = mReader.inventorySingleTag();

            if (info != null) {
                String epcHex = info.getEPC();
                String tid = info.getTid();
                String rssi = info.getRssi();

                Log.i(TAG, "🔍 DETECTED: EPC: " + epcHex);
                Log.i(TAG, "🔍 DETECTED: TID: '" + (tid != null ? tid : "null") + "' (length: "
                        + (tid != null ? tid.length() : 0) + ")");
                Log.i(TAG, "🔍 DETECTED: RSSI: " + rssi);

                // Try to read TID directly if empty from inventorySingleTag
                if (tid == null || tid.isEmpty() || "000000000000000000000000".equals(tid)) {
                    Log.i(TAG, "🔍 DIRECT-TID: Attempting direct TID bank read");
                    try {
                        String tidDirect = mReader.readData("00000000", RFIDWithUHFUART.Bank_TID, 0, 6);
                        Log.i(TAG, "🔍 DIRECT-TID: Result: '" + tidDirect + "'");
                        if (tidDirect != null && !tidDirect.isEmpty() &&
                                !tidDirect.equals("000000000000000000000000") &&
                                !tidDirect.equals("00000000000000000000000000000000")) {
                            tid = tidDirect;
                            Log.i(TAG, "✅ DIRECT-TID: Got valid TID: " + tid);
                        }
                    } catch (Exception e) {
                        Log.w(TAG, "❌ DIRECT-TID: Failed: " + e.getMessage());
                    }
                }

                // Read USER memory immediately while tag is detected
                String userMemory = "";
                try {
                    Log.i(TAG, "🔍 TID-FILTER: Reading USER memory using TID as filter");
                    Log.i(TAG, "🔍   Target TID: " + (tid != null ? tid : "null"));

                    if (tid != null && !tid.isEmpty() && tid.length() >= 8) {
                        // BREAKTHROUGH: Use TID as filter to read USER from specific tag!
                        int tidBits = tid.length() * 4; // Convert hex chars to bits
                        Log.i(TAG, "🔍 TID-FILTER: Filtering by TID - " + tid + " (" + tidBits + " bits)");

                        userMemory = mReader.readData("00000000",
                                RFIDWithUHFUART.Bank_TID, 0, tidBits, tid, // Filter by TID
                                RFIDWithUHFUART.Bank_USER, 0, 32); // Read USER

                        if (userMemory != null && userMemory.length() >= 16) {
                            Log.i(TAG,
                                    "✅ TID-FILTER: SUCCESS! Got USER memory for TID " + tid.substring(0, 8) + "...: " +
                                            userMemory.substring(0, Math.min(32, userMemory.length())) + "...");
                        } else {
                            Log.w(TAG, "❌ TID-FILTER: Failed, trying direct read as fallback");
                            userMemory = mReader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
                            if (userMemory != null && userMemory.length() >= 16) {
                                Log.i(TAG, "🔄 DIRECT-FALLBACK: Got USER via direct read: "
                                        + userMemory.substring(0, Math.min(32, userMemory.length())) + "...");
                            }
                        }
                    } else {
                        Log.w(TAG, "❌ TID-FILTER: Invalid TID, using direct read");
                        userMemory = mReader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
                    }
                } catch (Exception e) {
                    Log.w(TAG, "❌ TID-FILTER: Exception: " + e.getMessage());
                }

                boolean validTid = tid != null && !tid.isEmpty() &&
                        !tid.equals("000000000000000000000000") &&
                        !tid.equals("00000000000000000000000000000000");

                // Return comprehensive tag information including immediate USER memory
                return "{\"epc\":\"" + epcHex + "\",\"tid\":\"" + (tid != null ? tid : "") +
                        "\",\"rssi\":\"" + rssi + "\",\"validTid\":" + validTid +
                        ",\"userMemory\":\"" + userMemory + "\"}";
            }

            Log.d(TAG, "🔍 DETECTED: No tag found");
            return "";
        } catch (Exception e) {
            Log.e(TAG, "❌ CORRECTED: Error: " + e.getMessage());
            return "";
        }
    }

    // ----------- ASIL EPC YAZMA KODU (ATA/GS1/6bit ve PC Word ile) -----------
    public boolean writeTagADIConstruct2(String partNumber, String serialNumber) {
        try {
            if (mReader == null) {
                Log.e(TAG, "mReader is null; cannot write!");
                return false;
            }

            // Header, filter ve CAGE/manager kodu
            String headerBits = "00111011"; // 8 bit header
            String filterBits = "001110"; // 6 bit filter
            String manager = " TG424"; // 6 karakter CAGE kodu

            StringBuilder epcBin = new StringBuilder();
            epcBin.append(headerBits);
            epcBin.append(filterBits);
            epcBin.append(encode6Bit(manager));

            // Parça numarası (PN)
            epcBin.append(encode6Bit(partNumber));
            epcBin.append("000000"); // Delimiter

            // Seri numarası (SN)
            epcBin.append(encode6Bit(serialNumber));
            epcBin.append("000000"); // Delimiter

            // 16 bit'e tamamlamak için padding
            // int padBits = (16 - (epcBin.length() % 16)) % 16;
            // for (int i = 0; i < padBits; i++)
            // epcBin.append('0');
            int padBits = (8 - (epcBin.length() % 8)) % 8;
            for (int i = 0; i < padBits; i++)
                epcBin.append('0');

            // Binary -> Hex
            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBin.length(); i += 4) {
                String chunk = epcBin.substring(i, i + 4);
                epcHex.append(Integer.toHexString(Integer.parseInt(chunk, 2)).toUpperCase(Locale.ROOT));
            }

            // Word & PC Word hesaplama
            int epcBitLen = epcBin.length();
            int epcWordCount = epcBitLen / 16;
            int pcWord = (epcWordCount << 11) | 0x3000;
            String pcWordHex = String.format("%04X", pcWord);

            Log.i(TAG, "Construct2 EPC to write (with PC): PC=" + pcWordHex + " EPC=" + epcHex);

            // PC+EPC toplam data (ilk word PC, devamı EPC data)
            String writeData = pcWordHex + epcHex.toString();

            String accessPwd = "00000000";
            int bank = 1; // EPC bank
            int ptr = 1; // PC word adresi
            int wordCount = epcWordCount + 1; // PC+EPC toplam word

            boolean success = mReader.writeData(accessPwd, bank, ptr, wordCount, writeData);
            Log.e(TAG, "WriteTagADIConstruct2: success=" + success + ", errCode=" + mReader.getErrCode());

            if (success) {
                MediaPlayer.create(context, R.raw.barcodebeep).start();
            } else {
                MediaPlayer.create(context, R.raw.serror).start();
            }
            return success;
        } catch (Exception e) {
            Log.e(TAG, "Error writing Construct 2: " + e.getMessage(), e);
            return false;
        }
    }

    public boolean programConstruct2Epc(String partNumber, String serialNumber,
            String manager6, String accessPwdHex, int filterValue) {
        if (mReader == null)
            return false;
        try {
            String headerBits = "00111011"; // ADI header
            int fv = (filterValue < 0 || filterValue > 63) ? 0 : filterValue;
            String filterBits = String.format("%6s", Integer.toBinaryString(fv)).replace(' ', '0');

            StringBuilder epcBits = new StringBuilder();
            epcBits.append(headerBits).append(filterBits)
                    .append(encode6Bit(manager6))
                    .append(encode6Bit(partNumber)).append("000000")
                    .append(encode6Bit(serialNumber)).append("000000");

            // 16-bit (word) hizası – writeDataToEpc HEX uzunluğu 4'ün katı olmalı
            int pad16 = (16 - (epcBits.length() % 16)) % 16;
            for (int i = 0; i < pad16; i++)
                epcBits.append('0');

            // bin -> hex (4 bit -> 1 hex)
            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBits.length(); i += 4) {
                epcHex.append(Integer.toHexString(
                        Integer.parseInt(epcBits.substring(i, i + 4), 2)).toUpperCase(Locale.ROOT));
            }
            // emniyet: 4'ün katı değilse tamamla (pad16 zaten engeller; yine de garanti)
            while ((epcHex.length() & 0x3) != 0)
                epcHex.append('0');

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            return mReader.writeDataToEpc(pwd, epcHex.toString()); // PC auto-adapt
        } catch (Exception e) {
            Log.e(TAG, "programConstruct2Epc(filter)", e);
            return false;
        }
    }

    public boolean prepareAtaChip(String recordType,
            int epcWords,
            int userWords,
            int permalockWords,
            boolean enablePermalock,
            boolean lockEpc,
            boolean lockUser,
            String accessPwdHex) {
        if (mReader == null) {
            Log.e(TAG, "prepareAtaChip: mReader is null");
            return false;
        }
        try {
            // if inventory is running, pausing can prevent write/read clashes
            boolean wasRunning = isStart;
            if (wasRunning) {
                mReader.stopInventory();
                isStart = false;
            }

            // just cache the values; we will use them when building USER header
            currentRecordType = (recordType == null ? "DRT" : recordType);
            currentEpcWords = Math.max(8, epcWords);
            currentUserWords = Math.max(0, userWords);
            currentPermalockWords = Math.max(0, permalockWords);

            // TODO: If SDK has lock/block-permalock APIs, call them here using
            // enablePermalock/lockEpc/lockUser/accessPwdHex.

            // (optional) resume inventory if it was running
            // if (wasRunning) { mReader.startInventoryTag(); isStart = true; new
            // TagThread().start(); }

            return true;
        } catch (Exception e) {
            Log.e(TAG, "prepareAtaChip failed", e);
            return false;
        }
    }

    // -------------------- 6-bit GS1 EPC Kod Tablosu ----------------------
    private static final Map<Character, String> CHAR_TO_6BIT;
    static {
        CHAR_TO_6BIT = new HashMap<>();
        CHAR_TO_6BIT.put(' ', "100000"); // SPACE
        CHAR_TO_6BIT.put('A', "000001");
        CHAR_TO_6BIT.put('B', "000010");
        CHAR_TO_6BIT.put('C', "000011");
        CHAR_TO_6BIT.put('D', "000100");
        CHAR_TO_6BIT.put('E', "000101");
        CHAR_TO_6BIT.put('F', "000110");
        CHAR_TO_6BIT.put('G', "000111");
        CHAR_TO_6BIT.put('H', "001000");
        CHAR_TO_6BIT.put('I', "001001");
        CHAR_TO_6BIT.put('J', "001010");
        CHAR_TO_6BIT.put('K', "001011");
        CHAR_TO_6BIT.put('L', "001100");
        CHAR_TO_6BIT.put('M', "001101");
        CHAR_TO_6BIT.put('N', "001110");
        CHAR_TO_6BIT.put('O', "001111");
        CHAR_TO_6BIT.put('P', "010000");
        CHAR_TO_6BIT.put('Q', "010001");
        CHAR_TO_6BIT.put('R', "010010");
        CHAR_TO_6BIT.put('S', "010011");
        CHAR_TO_6BIT.put('T', "010100");
        CHAR_TO_6BIT.put('U', "010101");
        CHAR_TO_6BIT.put('V', "010110");
        CHAR_TO_6BIT.put('W', "010111");
        CHAR_TO_6BIT.put('X', "011000");
        CHAR_TO_6BIT.put('Y', "011001");
        CHAR_TO_6BIT.put('Z', "011010");
        CHAR_TO_6BIT.put('[', "011011");
        CHAR_TO_6BIT.put('\\', "011100");
        CHAR_TO_6BIT.put(']', "011101");
        CHAR_TO_6BIT.put('^', "011110");
        CHAR_TO_6BIT.put('_', "011111");
        CHAR_TO_6BIT.put('0', "110000");
        CHAR_TO_6BIT.put('1', "110001");
        CHAR_TO_6BIT.put('2', "110010");
        CHAR_TO_6BIT.put('3', "110011");
        CHAR_TO_6BIT.put('4', "110100");
        CHAR_TO_6BIT.put('5', "110101");
        CHAR_TO_6BIT.put('6', "110110");
        CHAR_TO_6BIT.put('7', "110111");
        CHAR_TO_6BIT.put('8', "111000");
        CHAR_TO_6BIT.put('9', "111001");
        CHAR_TO_6BIT.put('?', "111111");
        CHAR_TO_6BIT.put('!', "100001");
        CHAR_TO_6BIT.put('#', "100011");
        CHAR_TO_6BIT.put('$', "100100");
        CHAR_TO_6BIT.put('%', "100101");
        CHAR_TO_6BIT.put('&', "100110");
        CHAR_TO_6BIT.put('\'', "100111");
        CHAR_TO_6BIT.put('(', "101000");
        CHAR_TO_6BIT.put(')', "101001");
        CHAR_TO_6BIT.put('*', "101010");
        CHAR_TO_6BIT.put('+', "101011");
        CHAR_TO_6BIT.put(',', "101100");
        CHAR_TO_6BIT.put('-', "101101");
        CHAR_TO_6BIT.put('.', "101110");
        CHAR_TO_6BIT.put('/', "101111");
        CHAR_TO_6BIT.put(':', "111010");
        CHAR_TO_6BIT.put(';', "111011");
        CHAR_TO_6BIT.put('<', "111100");
        CHAR_TO_6BIT.put('=', "111101");
        CHAR_TO_6BIT.put('>', "111110");
    }

    private static final Map<String, Character> SIXBIT_TO_CHAR;
    static {
        SIXBIT_TO_CHAR = new HashMap<>();
        for (Map.Entry<Character, String> e : CHAR_TO_6BIT.entrySet()) {
            SIXBIT_TO_CHAR.put(e.getValue(), e.getKey());
        }
    }

    // USER (header+payload) HEX -> sadece payload metni (6-bit decode)
    private String decodeUserPayloadHexToText(String userHex) {
        if (userHex == null || userHex.length() < 16)
            return "";
        // w0..w3 (16 hex) header'ı at, kalan payload
        String payloadHex = userHex.substring(16);

        // hex -> bit dizisi
        StringBuilder bits = new StringBuilder(payloadHex.length() * 4);
        for (int i = 0; i < payloadHex.length(); i++) {
            int v = Integer.parseInt(payloadHex.substring(i, i + 1), 16);
            bits.append(String.format("%4s", Integer.toBinaryString(v)).replace(' ', '0'));
        }

        // 6'şar bit çöz; "000000" (end delimiter) gelince dur
        StringBuilder out = new StringBuilder();
        for (int i = 0; i + 6 <= bits.length(); i += 6) {
            String sextet = bits.substring(i, i + 6);
            if ("000000".equals(sextet))
                break;
            Character ch = SIXBIT_TO_CHAR.get(sextet);
            out.append(ch != null ? ch : '?');
        }
        return out.toString();
    }

    // "*MFR XXX*PNR YYY*SER ZZZ*DMF 20240601*PDT ..." metninden alanları ayıkla
    private Map<String, String> parseAtaUserText(String text) {
        Map<String, String> res = new HashMap<>();
        if (text == null || text.isEmpty())
            return res;

        String[] parts = text.split("\\*");
        for (String part : parts) {
            part = part.trim();
            if (part.isEmpty())
                continue;
            int sp = part.indexOf(' ');
            if (sp <= 0)
                continue;
            String key = part.substring(0, sp).trim(); // MFR/PNR/SER/DMF/PDT/UIC...
            String val = part.substring(sp + 1).trim();
            res.put(key, val);
        }
        return res;
    }

    private String encode6Bit(String text) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            String bits = CHAR_TO_6BIT.get(c);
            if (bits == null) {
                throw new IllegalArgumentException("Character '" + c + "' not supported in 6-bit dictionary.");
            }
            sb.append(bits);
        }
        return sb.toString();
    }

    // [ADD] Map UI recordType -> ATA Short ToC 'Tag Type' field
    private int mapAtaTagType(String rt) {
        if (rt == null)
            return 2; // default: Single Record Tag (SRT)
        String r = rt.toUpperCase(Locale.ROOT);
        if (r.startsWith("DRT"))
            return 3; // Dual Record Tag
        if (r.startsWith("MRT"))
            return 4; // Multiple Record Tag
        // SRT (Birth/Utility) -> 2
        return 2;
    }

    // Binary -> Hex conversion (her 4 bit için 1 hex karakter)
    private List<String> splitIntoChunks(String binaryStr, int chunkSize) {
        List<String> chunks = new ArrayList<>();
        for (int i = 0; i < binaryStr.length(); i += chunkSize) {
            int end = Math.min(binaryStr.length(), i + chunkSize);
            chunks.add(binaryStr.substring(i, end));
        }
        return chunks;
    }

    // Belirli EPC için USER alanlarını oku, decode et ve JSON döndür
    public String readUserFieldsForEpc(String epcHex) {
        try {
            String userHex = readUserMemoryForEpc(epcHex); // sende zaten var
            if (userHex == null || userHex.isEmpty())
                return "{}";

            String text = decodeUserPayloadHexToText(userHex);
            Map<String, String> fields = parseAtaUserText(text);

            JSONObject obj = new JSONObject();
            obj.put("rawHex", userHex);
            obj.put("rawText", text);
            obj.put("MFR", fields.getOrDefault("MFR", ""));
            obj.put("PDT", fields.getOrDefault("PDT", ""));
            obj.put("PNR", fields.getOrDefault("PNR", ""));
            obj.put("SER", fields.getOrDefault("SER", ""));
            obj.put("DMF", fields.getOrDefault("DMF", ""));
            obj.put("UIC", fields.getOrDefault("UIC", ""));
            return obj.toString();
        } catch (Exception e) {
            Log.e(TAG, "readUserFieldsForEpc", e);
            return "{}";
        }
    }

    // Şu an RAM'de tuttuğumuz taranmış tag listesi (EPC/RSSI/COUNT) -> JSON array
    public String getCurrentTagsJson() {
        try {
            JSONArray arr = new JSONArray();
            if (tagList != null) {
                for (EPC t : tagList.values()) {
                    JSONObject j = new JSONObject();
                    j.put("id", t.getId());
                    j.put("epc", t.getEpc());
                    j.put("rssi", t.getRssi());
                    j.put("count", t.getCount());
                    arr.put(j);
                }
            }
            return arr.toString();
        } catch (Exception e) {
            Log.e(TAG, "getCurrentTagsJson", e);
            return "[]";
        }
    }

    private String binaryToHex(List<String> binaryChunks) {
        StringBuilder sb = new StringBuilder();
        for (String bin : binaryChunks) {
            int decimal = Integer.parseInt(bin, 2);
            String hex = Integer.toHexString(decimal).toUpperCase(Locale.ROOT);
            if (hex.length() == 1) {
                sb.append('0').append(hex);
            } else {
                sb.append(hex);
            }
        }
        return sb.toString();
    }

    // Add EPC to list
    private void addEPCToList(String epc, String rssi) {
        if (!TextUtils.isEmpty(epc)) {
            EPC tag = new EPC();
            tag.setId("");
            tag.setEpc(epc);
            tag.setCount("1");
            tag.setRssi(rssi);
            if (tagList.containsKey(epc)) {
                int oldCount = Integer.parseInt(Objects.requireNonNull(tagList.get(epc)).getCount());
                tag.setCount(String.valueOf(oldCount + 1));
            }
            tagList.put(epc, tag);
            JSONArray arr = new JSONArray();
            for (EPC epcTag : tagList.values()) {
                JSONObject json = new JSONObject();
                try {
                    json.put(TagKey.ID, epcTag.getId());
                    json.put(TagKey.EPC, epcTag.getEpc());
                    json.put(TagKey.RSSI, epcTag.getRssi());
                    json.put(TagKey.COUNT, epcTag.getCount());
                    arr.put(json);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }
            if (uhfListener != null) {
                uhfListener.onRead(arr.toString());
            }
        }
    }

    // Set UHFListener
    public void setUhfListener(UHFListener uhfListener) {
        this.uhfListener = uhfListener;
    }

    // FIXED: Continuous inventory thread - clean EPC only
    class TagThread extends Thread {
        @Override
        public void run() {
            while (isStart && mReader != null) {
                UHFTAGInfo info = mReader.readTagFromBuffer();
                if (info != null) {
                    String epcHex = info.getEPC(); // Clean EPC only
                    String rssiStr = info.getRssi();
                    // FIXED: Send only "EPC@RSSI" format
                    Message msg = handler.obtainMessage();
                    msg.obj = epcHex + "@" + rssiStr;
                    handler.sendMessage(msg);
                    Log.d(TAG, "✅ CLEAN-EPC: " + epcHex + " (RSSI: " + rssiStr + ")");
                }
            }
        }
    }

    public boolean writeAtaUserMemoryWithPayload(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate) {
        if (mReader == null) {
            Log.e(TAG, "mReader is null; cannot write User Memory header!");
            return false;
        }
        try {
            // --- 1. Build ATA Spec payload string (with field names per spec) ---
            StringBuilder payloadBuilder = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                payloadBuilder.append("*MFR ").append(manufacturer);
            if (productName != null && !productName.isEmpty())
                payloadBuilder.append("*PDT ").append(productName);
            if (partNumber != null && !partNumber.isEmpty())
                payloadBuilder.append("*PNR ").append(partNumber);
            if (serialNumber != null && !serialNumber.isEmpty())
                payloadBuilder.append("*SER ").append(serialNumber);
            if (manufactureDate != null && !manufactureDate.isEmpty())
                payloadBuilder.append("*DMF ").append(manufactureDate);
            payloadBuilder.append("*UIC 2");

            // Remove leading "*" if present (optional)
            String ataPayloadText = (payloadBuilder.length() > 0 && payloadBuilder.charAt(0) == '*')
                    ? payloadBuilder.substring(1)
                    : payloadBuilder.toString();

            // --- 2. Encode to 6-bit GS1/ATA Spec ---
            StringBuilder payload6bit = new StringBuilder();
            for (char c : ataPayloadText.toCharArray()) {
                String sixBits = CHAR_TO_6BIT.get(Character.toUpperCase(c));
                if (sixBits == null) {
                    Log.w(TAG, "Unsupported char in user memory: " + c);
                    sixBits = "000000"; // Substitute NUL
                }
                payload6bit.append(sixBits);
            }
            payload6bit.append("000000"); // End delimiter

            // --- 3. Pad payload to nearest 16 bits ---
            int padBits = (16 - (payload6bit.length() % 16)) % 16;
            for (int i = 0; i < padBits; i++)
                payload6bit.append('0');
            int payloadWords = payload6bit.length() / 16;

            // --- 4. Build Short ToC header ---
            int dsfid = 0x1E00; // Fixed
            int tocMajor = 6; // Usually 6
            int tocMinor = 1; // Usually 1
            int ataClass = 1; // 1 for flyable
            int tagType = mapAtaTagType(currentRecordType); // 2 for Single Birth-Record
            int flags = 0; // All bits 0
            int tocHeaderSize = 4;
            int tocRdSize = 0;
            int userMemWords = 4 + payloadWords; // header + payload

            // Header words
            String w0 = String.format("%04X", dsfid);
            int word1 = ((tocMinor & 0x7) << 13)
                    | ((tocMajor & 0xF) << 9)
                    | ((tagType & 0xF) << 5)
                    | (ataClass & 0x1F);

            String w1 = String.format("%04X", word1);
            int word2 = ((flags & 0xFF) << 8)
                    | ((tocHeaderSize & 0xF) << 4)
                    | (tocRdSize & 0xF);
            String w2 = String.format("%04X", word2);
            String w3 = String.format("%04X", userMemWords);

            // --- 5. Encode 6-bit binary to hex (4 bits per hex digit) ---
            StringBuilder payloadHex = new StringBuilder();
            String bits = payload6bit.toString();
            for (int i = 0; i < bits.length(); i += 4) {
                String chunk = bits.substring(i, Math.min(i + 4, bits.length()));
                payloadHex.append(Integer.toHexString(Integer.parseInt(chunk, 2)).toUpperCase(Locale.ROOT));
            }

            // --- 6. Combine header and payload hex
            String userMemHex = w0 + w1 + w2 + w3 + payloadHex.toString();
            Log.i(TAG, "User Memory (Short ToC): " + userMemHex);

            // --- 7. Write to USER memory bank ---
            String accessPwd = "00000000";
            int bank = 3; // USER memory
            int ptr = 0; // Start at word 0
            int wordCount = userMemWords; // header + payload words

            boolean success = mReader.writeData(accessPwd, bank, ptr, wordCount, userMemHex);
            Log.i(TAG, "Write Short ToC User Memory result: " + (success ? "SUCCESS" : "FAILED"));

            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error writing User Memory Short ToC+payload: " + e.getMessage(), e);
            return false;
        }
    }

    // Reads USER memory of the currently strongest/closest tag
    public synchronized String readUserMemory() {
        if (mReader == null) {
            Log.e(TAG, "mReader is null; cannot read USER memory!");
            return "";
        }

        boolean resumeInventory = false;
        try {
            // Stop inventory if running to get clean read
            if (isStart) {
                resumeInventory = true;
                mReader.stopInventory();
                isStart = false;
                Thread.sleep(100); // Allow complete stop
            }

            String accessPwd = "00000000";
            Log.i(TAG, "Reading USER memory from strongest available tag");

            // Try to read USER memory directly (will read from strongest tag in range)
            String userHex = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, 32);

            if (userHex != null && userHex.length() >= 16) {
                Log.i(TAG, "SUCCESS: Read USER memory (no EPC filter): "
                        + userHex.substring(0, Math.min(32, userHex.length())) + "...");
                return userHex;
            } else {
                Log.w(TAG, "USER memory read returned empty or short data");
                return "";
            }

        } catch (Exception e) {
            Log.e(TAG, "Error reading USER memory: " + e.getMessage());
            return "";
        } finally {
            // Restart inventory if it was running
            if (resumeInventory) {
                try {
                    Thread.sleep(50);
                    mReader.startInventoryTag();
                    isStart = true;
                    new TagThread().start();
                } catch (Exception e) {
                    Log.w(TAG, "Failed to restart inventory: " + e.getMessage());
                }
            }
        }
    }

    public synchronized boolean setEpcFilterForHex(String epcHex) {
        if (mReader == null)
            return false;
        try {
            int bits = epcHex != null ? epcHex.length() * 4 : 0;
            if (bits <= 0)
                return false;
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, bits, epcHex);
        } catch (Exception e) {
            Log.e(TAG, "setEpcFilterForHex", e);
            return false;
        }
    }

    public synchronized boolean clearFilter() {
        if (mReader == null)
            return false;
        try {
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
        } catch (Exception e) {
            Log.e(TAG, "clearFilter", e);
            return false;
        }
    }

    // Enhanced method for reading ATA SPEC compliant tags
    public synchronized String readSingleTagEPCWithRetry() {
        // Revert to single-shot behavior for stability
        return readSingleTagEPC();
    }

    // Method to get multiple tags in one scan for better detection
    public List<String> scanMultipleTags(int maxTags) {
        List<String> foundTags = new ArrayList<>();
        if (mReader == null) {
            Log.e(TAG, "mReader is null, cannot scanMultipleTags");
            return foundTags;
        }

        clearFilter();

        try {
            // Start continuous inventory briefly
            if (mReader.startInventoryTag()) {
                Thread.sleep(500); // Scan for 500ms

                // Read from buffer
                for (int i = 0; i < maxTags; i++) {
                    UHFTAGInfo info = mReader.readTagFromBuffer();
                    if (info != null) {
                        String epcHex = info.getEPC();
                        if (epcHex != null && !epcHex.isEmpty() && !foundTags.contains(epcHex)) {
                            foundTags.add(epcHex);
                            Log.i(TAG, "Found tag in continuous scan: " + epcHex);
                        }
                    } else {
                        break; // No more tags in buffer
                    }
                }

                mReader.stopInventory();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in scanMultipleTags: " + e.getMessage(), e);
            try {
                mReader.stopInventory();
            } catch (Exception ignored) {
            }
        }

        Log.i(TAG, "Continuous scan found " + foundTags.size() + " tags");
        return foundTags;
    }

    public synchronized String readUserMemoryForEpc(String epcHex) {
        Log.i(TAG, "*** FIXED readUserMemoryForEpc for: " + epcHex + " ***");
        if (mReader == null) {
            Log.e(TAG, "mReader is null in readUserMemoryForEpc");
            return "";
        }

        if (epcHex == null || epcHex.isEmpty()) {
            Log.w(TAG, "Empty EPC provided");
            return "";
        }

        boolean wasRunning = isStart;
        try {
            // Stop inventory completely to avoid tag mixing
            if (wasRunning) {
                mReader.stopInventory();
                isStart = false;
                Thread.sleep(100);
            }

            String accessPwd = "00000000";
            clearFilter(); // Start clean

            Log.i(TAG, "Using single-tag verification approach to prevent mixing");

            // Try to find our specific tag multiple times
            for (int attempt = 0; attempt < 15; attempt++) {
                try {
                    UHFTAGInfo tagInfo = mReader.inventorySingleTag();
                    if (tagInfo != null) {
                        String foundEpc = tagInfo.getEPC();
                        Log.i(TAG, "Found: " + foundEpc + " | Target: " + epcHex);

                        // Only read if this is exactly our target tag
                        if (epcHex.equalsIgnoreCase(foundEpc)) {
                            Log.i(TAG, "EXACT MATCH! Reading USER memory for verified tag...");

                            // Read immediately while tag is detected
                            String userHex = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, 32);

                            if (userHex != null && userHex.length() >= 16) {
                                Log.i(TAG, "SUCCESS: Verified USER read for " + epcHex + " = "
                                        + userHex.substring(0, Math.min(32, userHex.length())));
                                return userHex;
                            } else {
                                Log.w(TAG, "USER memory was empty for matched EPC, retrying...");
                            }
                        } else {
                            Log.d(TAG, "Different tag detected, continuing search...");
                        }
                    } else {
                        Log.d(TAG, "No tag detected in attempt " + (attempt + 1));
                    }

                    // Brief pause between attempts
                    Thread.sleep(80);

                } catch (Exception e) {
                    Log.w(TAG, "Attempt " + attempt + " error: " + e.getMessage());
                    Thread.sleep(50);
                }
            }

            Log.w(TAG, "Could not find or read USER memory for target EPC: " + epcHex);
            return "";

        } catch (Exception e) {
            Log.e(TAG, "Critical error in readUserMemoryForEpc: " + e.getMessage());
            return "";
        } finally {
            // Always clean up
            try {
                clearFilter();
                if (wasRunning) {
                    mReader.startInventoryTag();
                    isStart = true;
                    new TagThread().start();
                }
            } catch (Exception e) {
                Log.w(TAG, "Cleanup failed: " + e.getMessage());
            }
        }
    }

    // STRICT EPC-USER reading (per SDK documentation)
    public synchronized String readUserMemoryForEpcStrict(String epcHex) {
        Log.i(TAG, "🔧 STRICT: Reading USER memory for EPC: " + epcHex);
        if (mReader == null || epcHex == null || epcHex.isEmpty()) {
            return "";
        }

        boolean wasRunning = isStart;
        final String accessPwd = "00000000";

        try {
            // 1) Stop inventory (required per SDK docs)
            if (wasRunning) {
                mReader.stopInventory();
                isStart = false;
                Thread.sleep(80);
                Log.i(TAG, "🔧 STRICT: Inventory stopped");
            }

            // 2) Clean start
            clearFilter();

            // 3) Set EPC filter (ptr=32 to skip PC+CRC)
            int epcBits = epcHex.length() * 4;
            if (!mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex)) {
                Log.w(TAG, "❌ STRICT: EPC filter failed for " + epcHex);
                return "";
            }
            Thread.sleep(50);
            Log.i(TAG, "🔧 STRICT: EPC filter set for " + epcHex.substring(0, 8) + "...");

            // 4) Read USER header first (w0..w3) to get total word count
            String hdr = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, 4,
                    epcHex, RFIDWithUHFUART.Bank_EPC, 32, epcBits);
            if (hdr == null || hdr.length() < 16) {
                Log.w(TAG, "❌ STRICT: USER header read failed for " + epcHex);
                return "";
            }

            // Parse w3 for total USER word count (header + payload)
            int totalWords = 4; // minimum header
            try {
                totalWords = Math.max(4, Integer.parseInt(hdr.substring(12, 16), 16));
            } catch (Exception ignore) {
                totalWords = 32; // safe default
            }
            totalWords = Math.min(totalWords, 64); // safety limit

            Log.i(TAG, "🔧 STRICT: USER header OK, reading " + totalWords + " words");

            // 5) Read complete USER area with EPC filter
            String allUserData = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, totalWords,
                    epcHex, RFIDWithUHFUART.Bank_EPC, 32, epcBits);

            if (allUserData != null && allUserData.length() >= 16) {
                Log.i(TAG, "✅ STRICT: SUCCESS for " + epcHex.substring(0, 8) + "... → " +
                        allUserData.substring(0, Math.min(32, allUserData.length())) + "...");
                return allUserData;
            } else {
                Log.w(TAG, "❌ STRICT: Empty USER data for " + epcHex);
                return "";
            }

        } catch (Exception e) {
            Log.e(TAG, "❌ STRICT: Error for " + epcHex + ": " + e.getMessage());
            return "";
        } finally {
            // Always clean up
            try {
                clearFilter();
                Log.d(TAG, "🔧 STRICT: Filter cleared");
            } catch (Exception ignore) {
            }

            if (wasRunning) {
                try {
                    mReader.startInventoryTag();
                    isStart = true;
                    new TagThread().start();
                    Log.d(TAG, "🔧 STRICT: Inventory restarted");
                } catch (Exception ignore) {
                }
            }
        }
    }

    public synchronized String readUserMemoryForEpcOld(String epcHex) {
        Log.i(TAG, "*** readUserMemoryForEpcOld CALLED for: " + epcHex + " ***");
        if (mReader == null) {
            Log.e(TAG, "mReader is null in readUserMemoryForEpcOld");
            return "";
        }
        boolean wasRunning = isStart;
        try {
            if (wasRunning) {
                mReader.stopInventory();
                isStart = false;
            }

            String accessPwd = "00000000";
            int userBank = RFIDWithUHFUART.Bank_USER;

            Log.i(TAG, "Reading USER memory for specific EPC: " + epcHex);

            // Try the direct EPC-matching readData method first
            try {
                int epcBits = epcHex.length() * 4;
                Log.i(TAG, "Attempting EPC-matched USER read for: " + epcHex + " (bits=" + epcBits + ")");

                // Use readData with EPC matching: readData(accessPwd, bank, ptr, cnt, epcHex,
                // epcBank, epcPtr, epcCnt)
                String all = mReader.readData(accessPwd, userBank, 0, 32, epcHex, RFIDWithUHFUART.Bank_EPC, 32,
                        epcBits);
                if (all != null && all.length() >= 16) {
                    Log.i(TAG, "SUCCESS: EPC-matched USER read for " + epcHex + ": " + all);
                    return all;
                } else {
                    Log.w(TAG, "EPC-matched USER read returned empty for: " + epcHex);
                }
            } catch (Exception e) {
                Log.w(TAG, "EPC-matched readData failed for " + epcHex + ": " + e.getMessage());
            }

            // If EPC-matching failed, try with EPC filter approach
            Log.i(TAG, "Fallback: Using EPC filter approach for: " + epcHex);
            try {
                if (!setEpcFilterForHex(epcHex)) {
                    Log.w(TAG, "Failed to set EPC filter for: " + epcHex);
                    return "";
                }
                Thread.sleep(100); // Allow filter to take effect
            } catch (Exception e) {
                Log.w(TAG, "Error setting EPC filter: " + e.getMessage());
                return "";
            }

            try {
                // Use EPC-matching readData method: readData(accessPwd, bank, ptr, cnt, epcHex,
                // epcBank, epcPtr, epcCnt)
                int epcBits = epcHex.length() * 4;

                // First read header to determine actual length
                String hdr = mReader.readData(accessPwd, userBank, 0, 4, epcHex, RFIDWithUHFUART.Bank_EPC, 32, epcBits);
                if (hdr == null || hdr.length() < 16) {
                    Log.w(TAG, "USER header read failed for EPC: " + epcHex);
                    return "";
                }

                int w3 = 4;
                try {
                    w3 = Integer.parseInt(hdr.substring(12, 16), 16);
                    if (w3 < 4)
                        w3 = 4;
                } catch (Exception ignore) {
                    w3 = 32; // Default safe size
                }

                // Read the full USER memory with EPC matching
                String all = mReader.readData(accessPwd, userBank, 0, w3, epcHex, RFIDWithUHFUART.Bank_EPC, 32,
                        epcBits);
                if (all != null && all.length() >= 16) {
                    Log.i(TAG, "Read USER memory for EPC " + epcHex + ": " + all);
                    return all;
                } else {
                    Log.w(TAG, "EPC-matched USER memory read returned empty for EPC: " + epcHex);
                    return "";
                }
            } finally {
                // Always clear the filter after reading
                try {
                    clearFilter();
                } catch (Exception ignore) {
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "readUserMemoryForEpc error", e);
            return "";
        } finally {
            if (wasRunning) {
                try {
                    mReader.startInventoryTag();
                    isStart = true;
                    new TagThread().start();
                } catch (Exception ignore) {
                }
            }
        }
    }

    public static void setLocationSink(EventChannel.EventSink sink) {
        locationSink = sink;
    }

    private int lastPowerLevel = 5;

    public boolean startLocation(Context context, String label, int bank, int ptr) {
        if (mReader == null) {
            Log.e(TAG, "mReader is null; cannot start location!");
            return false;
        }
        try {
            // Stop any ongoing inventory to prevent interference
            if (isStart) {
                mReader.stopInventory();
                isStart = false;
            }

            // Clear any existing filters to ensure clean start
            try {
                clearFilter();
                Thread.sleep(100); // Give time for filter to clear
            } catch (Exception e) {
                Log.w(TAG, "Failed to clear filter before location: " + e.getMessage());
            }

            lastPowerLevel = mReader.getPower();
            mReader.setPower(30);

            Log.i(TAG, "Starting location for EPC: " + label + " at bank=" + bank + " ptr=" + ptr);
            return mReader.startLocation(this.context, label, bank, ptr, new IUHFLocationCallback() {
                @Override
                public void getLocationValue(int value) {
                    Log.i(TAG, "Location signal strength: " + value);
                    if (locationSink != null)
                        locationSink.success(value);
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Error starting location: " + e.getMessage(), e);
            return false;
        }
    }

    public boolean stopLocation() {
        if (mReader == null) {
            Log.e(TAG, "mReader is null; cannot stop location!");
            return false;
        }
        try {
            mReader.setPower(lastPowerLevel);

            return mReader.stopLocation();
        } catch (Exception e) {
            Log.e(TAG, "Error stopping location: " + e.getMessage(), e);
            return false;
        }
    }

    // DIAGNOSTIC: Test individual tag reading
    public synchronized String diagnosticReadSingleTag() {
        if (mReader == null) {
            return "{\"error\":\"mReader is null\"}";
        }

        try {
            Log.i(TAG, "🔬 DIAGNOSTIC: Starting individual tag analysis");

            // Clear any filters to start fresh
            clearFilter();

            // Try to detect a tag
            UHFTAGInfo info = mReader.inventorySingleTag();
            if (info == null) {
                return "{\"error\":\"No tag detected\"}";
            }

            String epcHex = info.getEPC();
            String tid = info.getTid();
            String rssi = info.getRssi();

            Log.i(TAG, "🔬 DIAGNOSTIC: Found tag");
            Log.i(TAG, "🔬   EPC: " + epcHex);
            Log.i(TAG, "🔬   TID: '" + (tid != null ? tid : "null") + "'");
            Log.i(TAG, "🔬   RSSI: " + rssi);

            // Test 1: Read TID directly
            String directTid = "";
            try {
                directTid = mReader.readData("00000000", RFIDWithUHFUART.Bank_TID, 0, 6);
                Log.i(TAG, "🔬 DIRECT-TID: " + (directTid != null ? directTid : "null"));
            } catch (Exception e) {
                Log.w(TAG, "🔬 DIRECT-TID failed: " + e.getMessage());
            }

            // Test 2: Read USER memory directly
            String userMemory = "";
            try {
                userMemory = mReader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
                Log.i(TAG,
                        "🔬 USER-READ: " + (userMemory != null && userMemory.length() >= 16
                                ? userMemory.substring(0, Math.min(32, userMemory.length())) + "..."
                                : "EMPTY"));
            } catch (Exception e) {
                Log.w(TAG, "🔬 USER-READ failed: " + e.getMessage());
            }

            // Test 3: Check if this tag has any USER memory at all
            boolean hasUserMemory = userMemory != null && userMemory.length() >= 16 &&
                    !userMemory.equals("0000000000000000") &&
                    !userMemory.startsWith("0000000000000000");

            return "{\"epc\":\"" + epcHex + "\",\"tid\":\"" + (tid != null ? tid : "") +
                    "\",\"directTid\":\"" + directTid + "\",\"rssi\":\"" + rssi +
                    "\",\"userMemory\":\"" + userMemory + "\",\"hasUserMemory\":" + hasUserMemory + "}";

        } catch (Exception e) {
            Log.e(TAG, "🔬 DIAGNOSTIC error: " + e.getMessage());
            return "{\"error\":\"" + e.getMessage() + "\"}";
        }
    }

    public interface TagLocateListener {
        void onLocateValue(int value);
    }

    private TagLocateListener tagLocateListener;

    public void setTagLocateListener(TagLocateListener listener) {
        this.tagLocateListener = listener;
    }

}
