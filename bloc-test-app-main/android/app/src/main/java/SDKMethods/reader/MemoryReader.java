package SDKMethods.reader;

import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;

import org.json.JSONObject;

import java.util.Map;

import SDKMethods.ata.AtaEncodingUtils;
import SDKMethods.core.UHFManager;
import SDKMethods.inventory.InventoryManager;

/**
 * Memory Reader - Handles all USER memory read operations
 */
public class MemoryReader {
    private static final String TAG = "MemoryReader";
    
    // ATA Spec 2000: DRT max 2 Kbyte = 1024 words, MRT 8k+ = 4096+ words
    private static final int MAX_USER_WORDS = 1024;
    private static final int MIN_USER_WORDS = 4;
    private static final int CHUNK_SIZE = 32;
    private static final int MAX_RETRIES = 3;

    private static MemoryReader instance;

    private MemoryReader() {}

    public static synchronized MemoryReader getInstance() {
        if (instance == null) {
            instance = new MemoryReader();
        }
        return instance;
    }

    // ==================== BASIC READ ====================

    public synchronized String readUserMemory() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(100);
            }

            String userHex = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
            
            if (userHex != null && userHex.length() >= 16) {
                Log.i(TAG, "Read USER memory: " + userHex.substring(0, Math.min(32, userHex.length())) + "...");
                return userHex;
            }
            return "";

        } catch (Exception e) {
            Log.e(TAG, "Error reading USER memory: " + e.getMessage());
            return "";
        } finally {
            restoreInventory(wasRunning);
        }
    }

    // ==================== EPC FILTERED READ ====================

    public synchronized String readUserMemoryForEpcFull(String epcHex) {
        Log.i(TAG, "📖 EPC-READ: " + (epcHex != null && epcHex.length() >= 8 ? epcHex.substring(0, 8) + "..." : epcHex));
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcHex == null || epcHex.isEmpty()) return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            int epcBits = epcHex.length() * 4;
            StringBuilder fullHex = new StringBuilder();
            
            // First chunk with retry
            String firstChunk = readChunkWithRetry(reader, epcHex, epcBits, 0, true);
            if (firstChunk == null || firstChunk.length() < 16) {
                Log.w(TAG, "First chunk failed");
                return "";
            }
            
            fullHex.append(firstChunk);
            int targetWords = parseTargetWords(firstChunk);
            Log.i(TAG, "ToC says " + targetWords + " words");
            
            // Read remaining chunks
            int offset = CHUNK_SIZE;
            while (offset < targetWords) {
                int wordsToRead = Math.min(CHUNK_SIZE, targetWords - offset);
                String chunkHex = readChunkWithRetry(reader, epcHex, epcBits, offset, false);
                
                if (chunkHex == null || chunkHex.isEmpty()) {
                    Log.d(TAG, "Chunk at offset " + offset + " failed");
                    break;
                }
                
                fullHex.append(chunkHex);
                Thread.sleep(40);
                offset += CHUNK_SIZE;
            }

            String result = fullHex.toString();
            if (result.length() >= 16) {
                Log.i(TAG, "✅ EPC-READ success (" + (result.length() / 4) + " words)");
                return result;
            }
            return "";
            
        } catch (Exception e) {
            Log.e(TAG, "EPC-READ error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    // ==================== TID FILTERED READ ====================

    public synchronized String readUserMemoryForTid(String tidHex) {
        Log.i(TAG, "📖 TID-READ: " + (tidHex != null && tidHex.length() >= 8 ? tidHex.substring(0, 8) + "..." : tidHex));
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || tidHex == null || tidHex.isEmpty()) return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            int tidBits = tidHex.length() * 4;
            StringBuilder fullHex = new StringBuilder();
            
            // First chunk with retry
            String firstChunk = null;
            for (int retry = 0; retry < MAX_RETRIES; retry++) {
                firstChunk = reader.readData("00000000",
                    RFIDWithUHFUART.Bank_TID, 0, tidBits, tidHex,
                    RFIDWithUHFUART.Bank_USER, 0, CHUNK_SIZE);
                
                if (firstChunk != null && firstChunk.length() >= 16) break;
                if (retry < MAX_RETRIES - 1) Thread.sleep(80);
            }
            
            if (firstChunk == null || firstChunk.length() < 16) return "";
            
            fullHex.append(firstChunk);
            int targetWords = parseTargetWords(firstChunk);
            
            // Read remaining chunks
            int offset = CHUNK_SIZE;
            while (offset < targetWords) {
                int wordsToRead = Math.min(CHUNK_SIZE, targetWords - offset);
                String chunkHex = null;
                
                for (int retry = 0; retry < MAX_RETRIES; retry++) {
                    chunkHex = reader.readData("00000000",
                            RFIDWithUHFUART.Bank_TID, 0, tidBits, tidHex,
                            RFIDWithUHFUART.Bank_USER, offset, wordsToRead);
                    
                    if (chunkHex != null && !chunkHex.isEmpty()) break;
                    if (retry < MAX_RETRIES - 1) Thread.sleep(50);
                }
                
                if (chunkHex == null || chunkHex.isEmpty()) break;
                
                fullHex.append(chunkHex);
                Thread.sleep(40);
                offset += CHUNK_SIZE;
            }

            String result = fullHex.toString();
            if (result.length() >= 16) {
                Log.i(TAG, "✅ TID-READ success (" + (result.length() / 4) + " words)");
                return result;
            }
            return "";
            
        } catch (Exception e) {
            Log.e(TAG, "TID-READ error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    // ==================== USER FIELDS ====================

    public String readUserFieldsForEpc(String epcHex) {
        try {
            String userHex = readUserMemoryForEpc(epcHex);
            if (userHex == null || userHex.isEmpty()) return "{}";

            String text = AtaEncodingUtils.decodeUserPayloadHexToText(userHex);
            Map<String, String> fields = AtaEncodingUtils.parseAtaUserText(text);

            JSONObject obj = new JSONObject();
            obj.put("rawHex", userHex);
            obj.put("rawText", text);
            obj.put("MFR", fields.getOrDefault("MFR", ""));
            obj.put("PDT", fields.getOrDefault("PDT", ""));
            obj.put("PNR", fields.getOrDefault("PNR", ""));
            obj.put("SER", fields.getOrDefault("SER", ""));
            obj.put("DMF", fields.getOrDefault("DMF", ""));
            obj.put("EXP", fields.getOrDefault("EXP", ""));
            obj.put("UIC", fields.getOrDefault("UIC", ""));
            return obj.toString();
        } catch (Exception e) {
            Log.e(TAG, "readUserFieldsForEpc error", e);
            return "{}";
        }
    }

    public synchronized String readUserMemoryForEpcWithFilter(String epcHex) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcHex == null || epcHex.isEmpty()) return "";
        
        try {
            String userHex = reader.readData(epcHex, RFIDWithUHFUART.Bank_USER, 0, 128);
            if (userHex != null && userHex.length() >= 8) {
                Log.d(TAG, "✅ USER read: " + (userHex.length() / 4) + " words");
                return userHex;
            }
            return "";
        } catch (Exception e) {
            Log.e(TAG, "readUserMemoryForEpcWithFilter failed: " + e.getMessage());
            return "";
        }
    }

    // ==================== DIAGNOSTIC ====================

    public synchronized String diagnosticReadSingleTag() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return "{\"error\":\"mReader is null\"}";

        try {
            UHFManager.getInstance().clearFilter();

            UHFTAGInfo info = reader.inventorySingleTag();
            if (info == null) return "{\"error\":\"No tag detected\"}";

            String epcHex = info.getEPC();
            String tid = info.getTid();
            String rssi = info.getRssi();

            String directTid = "";
            try {
                directTid = reader.readData("00000000", RFIDWithUHFUART.Bank_TID, 0, 6);
            } catch (Exception ignored) {}

            String userMemory = "";
            try {
                userMemory = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
            } catch (Exception ignored) {}

            boolean hasUserMemory = userMemory != null && userMemory.length() >= 16 &&
                    !userMemory.startsWith("0000000000000000");

            return "{\"epc\":\"" + epcHex + "\",\"tid\":\"" + (tid != null ? tid : "") +
                    "\",\"directTid\":\"" + directTid + "\",\"rssi\":\"" + rssi +
                    "\",\"userMemory\":\"" + userMemory + "\",\"hasUserMemory\":" + hasUserMemory + "}";

        } catch (Exception e) {
            Log.e(TAG, "DIAGNOSTIC error: " + e.getMessage());
            return "{\"error\":\"" + e.getMessage() + "\"}";
        }
    }

    // ==================== PRIVATE HELPERS ====================

    private String readChunkWithRetry(RFIDWithUHFUART reader, String epcHex, int epcBits, int offset, boolean isFirst) {
        for (int retry = 0; retry < MAX_RETRIES; retry++) {
            try {
                String chunk = reader.readData("00000000",
                    RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex,
                    RFIDWithUHFUART.Bank_USER, offset, CHUNK_SIZE);
                
                if (chunk != null && (isFirst ? chunk.length() >= 16 : !chunk.isEmpty())) {
                    return chunk;
                }
                if (retry < MAX_RETRIES - 1) Thread.sleep(isFirst ? 80 : 50);
            } catch (Exception e) {
                Log.w(TAG, "Chunk retry " + retry + " failed: " + e.getMessage());
            }
        }
        return null;
    }

    /**
     * Parse Size of ATA Memory from ToC Header (ATA Spec Figure 53)
     * Word 2: Flags[15:8] | Size of ToC Header[7:4] | Size of RDs[3:0]
     * Word 3: Size of ATA Memory (16 or 32 bit)
     */
    private int parseTargetWords(String firstChunk) {
        int maxWords = MAX_USER_WORDS; // ATA Spec DRT max 1024
        try {
            if (firstChunk.length() >= 16) {
                int w2 = Integer.parseInt(firstChunk.substring(8, 12), 16);
                // Flag bit 2 (position 10 in word) = 16/32-bit pointers
                boolean pointer32Bit = (w2 & 0x0400) != 0;
                
                int targetWords;
                if (pointer32Bit && firstChunk.length() >= 20) {
                    int w3 = Integer.parseInt(firstChunk.substring(12, 16), 16);
                    int w4 = Integer.parseInt(firstChunk.substring(16, 20), 16);
                    targetWords = ((w3 & 0xFFFF) << 16) | (w4 & 0xFFFF);
                } else {
                    int w3 = Integer.parseInt(firstChunk.substring(12, 16), 16);
                    targetWords = w3 & 0xFFFF;
                }
                
                if (targetWords > 0 && targetWords <= maxWords) {
                    return targetWords;
                }
            }
        } catch (Exception ignored) {}
        return maxWords;
    }

    private int clampUserWords(int words) {
        if (words < MIN_USER_WORDS) return MIN_USER_WORDS;
        return Math.min(words, MAX_USER_WORDS);
    }

    private synchronized String readUserMemoryForEpc(String epcHex) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcHex == null || epcHex.isEmpty()) return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(100);
            }

            UHFManager.getInstance().clearFilter();

            for (int attempt = 0; attempt < 15; attempt++) {
                try {
                    UHFTAGInfo tagInfo = reader.inventorySingleTag();
                    if (tagInfo != null && epcHex.equalsIgnoreCase(tagInfo.getEPC())) {
                        String userHex = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
                        if (userHex != null && userHex.length() >= 16) {
                            return userHex;
                        }
                    }
                    Thread.sleep(80);
                } catch (Exception ignored) {}
            }
            return "";

        } catch (Exception e) {
            Log.e(TAG, "Error in readUserMemoryForEpc: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    private void restoreInventory(boolean wasRunning) {
        if (wasRunning) {
            try {
                RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
                if (reader != null) {
                    reader.startInventoryTag();
                }
            } catch (Exception ignored) {}
        }
    }
}

