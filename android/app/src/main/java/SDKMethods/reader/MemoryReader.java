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
    private static final int CHUNK_SIZE = 32; // 32 words optimal for C66 device
    private static final int MAX_RETRIES = 2; // Reduced from 3 for faster response

    private static MemoryReader instance;

    private MemoryReader() {
    }

    public static synchronized MemoryReader getInstance() {
        if (instance == null) {
            instance = new MemoryReader();
        }
        return instance;
    }

    // ==================== BASIC READ ====================

    public synchronized String readUserMemory() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return "";

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
        int epcLen = epcHex != null ? epcHex.length() : 0;
        Log.i(TAG, "📖 EPC-READ[" + epcLen + "]: "
                + (epcHex != null && epcHex.length() >= 12 ? epcHex.substring(0, 12) + "..." : epcHex));

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcHex == null || epcHex.isEmpty())
            return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            int epcBits = epcHex.length() * 4;
            // EPC-filtered read (filter on EPC bank at bit 32, after the PC word).
            String result = readUserMemoryChunked(reader,
                    RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex, 40, 20, 15);
            if (result.length() >= 16) {
                Log.i(TAG, "✅ EPC-READ success (" + (result.length() / 4) + " words)");
                return result;
            }
            Log.w(TAG, "First chunk failed");
            return "";

        } catch (Exception e) {
            Log.e(TAG, "EPC-READ error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    /**
     * Batch variant of {@link #readUserMemoryForEpcFull}: pauses the inventory
     * ONCE, reads USER for every EPC in the list back-to-back, then resumes.
     * Amortizes the stop/start overhead that dominates per-tag fetch time when
     * many tags are pending. Aborts remaining EPCs if the scan is stopped
     * mid-batch (and then does not restart the inventory).
     *
     * @return EPC -> USER hex ("" for EPCs whose read failed); EPCs after an
     *         abort are absent.
     */
    public synchronized java.util.Map<String, String> readUserMemoryForEpcsBatch(
            java.util.List<String> epcs) {
        java.util.Map<String, String> out = new java.util.HashMap<>();
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcs == null || epcs.isEmpty())
            return out;

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            for (String epcHex : epcs) {
                if (epcHex == null || epcHex.isEmpty())
                    continue;
                if (wasRunning && !InventoryManager.getInstance().isStarted())
                    break; // user pressed Stop mid-batch
                try {
                    int epcBits = epcHex.length() * 4;
                    String result = readUserMemoryChunked(reader,
                            RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex, 40, 20, 15);
                    out.put(epcHex, result != null ? result : "");
                    Thread.sleep(15); // brief gap between tags within the batch
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    out.put(epcHex, "");
                }
            }
            return out;

        } catch (Exception e) {
            Log.e(TAG, "EPC batch read error: " + e.getMessage());
            return out;
        } finally {
            UHFManager.getInstance().clearFilter();
            // Only resume if the scan is still supposed to be running.
            restoreInventory(wasRunning && InventoryManager.getInstance().isStarted());
        }
    }

    // ==================== TID FILTERED READ ====================

    // SDK LIMITATION: Maximum TID filter is 32 characters (128 bits)
    // 40 chars (160 bits) causes readData() err :65535 and unreliable results
    // We use 32 chars first, then 24 if that fails
    private static final int MAX_TID_FILTER_CHARS = 32; // SDK limit!
    private static final int[] TID_FILTER_LENGTHS = { 32, 24 }; // 128b, 96b

    public synchronized String readUserMemoryForTid(String tidHex) {
        if (tidHex == null || tidHex.isEmpty())
            return "";

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            // IMPORTANT: Truncate TID to SDK maximum BEFORE trying
            // Using 40+ chars causes SDK errors and unreliable results
            String effectiveTid = tidHex;
            if (tidHex.length() > MAX_TID_FILTER_CHARS) {
                effectiveTid = tidHex.substring(0, MAX_TID_FILTER_CHARS);
                Log.i(TAG, "TID truncated from " + tidHex.length() + "c to " + MAX_TID_FILTER_CHARS + "c (SDK limit)");
            }

            // Try progressively shorter TID lengths until one works
            for (int maxLen : TID_FILTER_LENGTHS) {
                if (effectiveTid.length() < maxLen)
                    continue; // Skip if TID not long enough

                String filterTid = effectiveTid.substring(0, maxLen);
                String result = tryTidReadWithLength(reader, filterTid);

                if (result != null && result.length() >= 16) {
                    return result; // Success!
                }

                // If failed, try shorter length
                Log.d(TAG, "TID-READ with " + maxLen + " chars failed, trying shorter...");
            }

            // Last resort: try with whatever TID we have (even if shorter)
            if (effectiveTid.length() >= 20 && effectiveTid.length() < 24) {
                String result = tryTidReadWithLength(reader, effectiveTid);
                if (result != null && result.length() >= 16) {
                    return result;
                }
            }

            Log.w(TAG, "TID-READ failed with all TID lengths");
            return "";

        } catch (Exception e) {
            Log.e(TAG, "TID-READ error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    /**
     * Read USER memory using TID filter - STRICT mode (NO fallback!)
     * 
     * This method is specifically for TID collision scenarios where we have
     * read an extended TID (32c) and want to read user memory with THAT TID ONLY.
     * 
     * CRITICAL: Does NOT fallback to shorter TID lengths!
     * If the given TID fails, returns empty string (caller should use EPC-READ)
     * 
     * @param tidHex TID to use as filter (must be 28-32 chars for collision
     *               resolution)
     * @return User memory hex or empty string if failed (NO fallback!)
     */
    public synchronized String readUserMemoryForTidStrict(String tidHex) {
        if (tidHex == null || tidHex.isEmpty())
            return "";

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(80);
            }
            UHFManager.getInstance().clearFilter();

            // Truncate to SDK max if needed
            String effectiveTid = tidHex;
            if (tidHex.length() > MAX_TID_FILTER_CHARS) {
                effectiveTid = tidHex.substring(0, MAX_TID_FILTER_CHARS);
                Log.i(TAG, "📌 STRICT TID truncated: " + tidHex.length() + "c → " + MAX_TID_FILTER_CHARS + "c");
            }

            Log.i(TAG, "📌 STRICT TID-READ[" + effectiveTid.length() + "c]: NO FALLBACK!");

            // Single attempt with EXACT TID length - NO fallback!
            String result = tryTidReadWithLength(reader, effectiveTid);

            if (result != null && result.length() >= 16) {
                Log.i(TAG, "✅ STRICT TID-READ success (" + (result.length() / 4) + "w)");
                return result;
            }

            Log.w(TAG, "⚠️ STRICT TID-READ failed - NO fallback (collision safety)");
            return "";

        } catch (Exception e) {
            Log.e(TAG, "STRICT TID-READ error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    /**
     * Attempt to read USER memory using specific TID filter length
     * 
     * @return User memory hex or null if failed
     */
    private String tryTidReadWithLength(RFIDWithUHFUART reader, String filterTid) {
        int tidBits = filterTid.length() * 4;
        Log.i(TAG, "📖 TID-READ[" + filterTid.length() + "c/" + tidBits + "b]: " +
                filterTid.substring(0, Math.min(24, filterTid.length())) +
                (filterTid.length() > 24 ? "..." : ""));

        try {
            // TID-filtered read (filter on TID bank from bit 0).
            String result = readUserMemoryChunked(reader,
                    RFIDWithUHFUART.Bank_TID, 0, tidBits, filterTid, 50, 25, 10);
            if (result.length() >= 16) {
                Log.i(TAG, "✅ TID-READ[" + filterTid.length() + "c] success (" + (result.length() / 4) + " words)");
                return result;
            }
            return null; // Failed with this TID length

        } catch (Exception e) {
            Log.d(TAG, "TID-READ[" + filterTid.length() + "c] error: " + e.getMessage());
            return null;
        }
    }

    // ==================== FULL TID READ (EPC-FILTERED) ====================

    /**
     * Read TID using EPC as filter - starts with 7 words (28 chars)
     * This is faster than reading 10 words and sufficient for most tags
     * 
     * @param epcHex The EPC to use as filter
     * @return TID hex (28 chars) or empty string on failure
     */
    public synchronized String readFullTidForEpc(String epcHex) {
        if (epcHex == null || epcHex.isEmpty())
            return "";

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(50);
            }
            UHFManager.getInstance().clearFilter();

            int epcBits = epcHex.length() * 4;

            // Read 7 words of TID (28 chars) - faster than 10 words
            // This is usually enough to uniquely identify tags
            String tidHex = null;
            for (int retry = 0; retry < MAX_RETRIES; retry++) {
                tidHex = reader.readData("00000000",
                        RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex,
                        RFIDWithUHFUART.Bank_TID, 0, 7);

                if (tidHex != null && tidHex.length() >= 24)
                    break;
                if (retry < MAX_RETRIES - 1)
                    Thread.sleep(30);
            }

            if (tidHex != null && tidHex.length() >= 24) {
                Log.i(TAG, "✅ TID[" + tidHex.length() + "c]: " + tidHex);
                return tidHex;
            }

            Log.w(TAG, "Failed to read TID for EPC: " + epcHex.substring(0, Math.min(12, epcHex.length())) + "...");
            return "";

        } catch (Exception e) {
            Log.e(TAG, "TID read error: " + e.getMessage());
            return "";
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    /**
     * Read extended TID (8 words = 32 chars) using EPC as filter
     * Use this when 28-char TID shows collision (same TID for different EPCs)
     * 
     * @param epcHex The EPC to use as filter
     * @return Extended TID hex (32 chars) or empty string on failure
     */
    public synchronized String readExtendedTidForEpc(String epcHex) {
        if (epcHex == null || epcHex.isEmpty())
            return "";

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return "";

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(50);
            }
            UHFManager.getInstance().clearFilter();

            int epcBits = epcHex.length() * 4;

            // Read 8 words of TID (32 chars) - for collision resolution
            String tidHex = null;
            for (int retry = 0; retry < MAX_RETRIES; retry++) {
                tidHex = reader.readData("00000000",
                        RFIDWithUHFUART.Bank_EPC, 32, epcBits, epcHex,
                        RFIDWithUHFUART.Bank_TID, 0, 8);

                if (tidHex != null && tidHex.length() >= 28)
                    break;
                if (retry < MAX_RETRIES - 1)
                    Thread.sleep(30);
            }

            if (tidHex != null && tidHex.length() >= 28) {
                Log.i(TAG, "✅ EXT-TID[" + tidHex.length() + "c]: " + tidHex);
                return tidHex;
            }

            Log.w(TAG, "Failed to read extended TID for EPC: " + epcHex.substring(0, Math.min(12, epcHex.length()))
                    + "...");
            return "";

        } catch (Exception e) {
            Log.e(TAG, "Extended TID read error: " + e.getMessage());
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
            if (userHex == null || userHex.isEmpty())
                return "{}";

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
        if (reader == null || epcHex == null || epcHex.isEmpty())
            return "";

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
        if (reader == null)
            return "{\"error\":\"mReader is null\"}";

        try {
            UHFManager.getInstance().clearFilter();

            UHFTAGInfo info = reader.inventorySingleTag();
            if (info == null)
                return "{\"error\":\"No tag detected\"}";

            String epcHex = info.getEPC();
            String tid = info.getTid();
            String rssi = info.getRssi();

            String directTid = "";
            try {
                directTid = reader.readData("00000000", RFIDWithUHFUART.Bank_TID, 0, 6);
            } catch (Exception ignored) {
            }

            String userMemory = "";
            try {
                userMemory = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 32);
            } catch (Exception ignored) {
            }

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

    /**
     * Read the full ATA USER memory of the single tag matched by the given filter
     * (EPC or TID bank). Shared by the EPC- and TID-filtered read paths.
     *
     * Reads the first chunk to learn the ATA memory size (parseTargetWords), then
     * reads the remaining words in CHUNK_SIZE pieces. The final piece is sized to the
     * exact remainder so it never over-reads past the tag's memory (a Gen2 overrun
     * would truncate the read). Per-call sleep values keep each path's tuned timing.
     *
     * @return USER memory hex (>=16 chars) or "" on failure.
     */
    private String readUserMemoryChunked(RFIDWithUHFUART reader,
            int filterBank, int filterStart, int filterBits, String filterData,
            int firstRetrySleepMs, int retrySleepMs, int loopSleepMs) throws InterruptedException {

        StringBuilder fullHex = new StringBuilder();

        // First chunk (also learns the ATA memory size from the ToC header).
        String firstChunk = readUserChunk(reader, filterBank, filterStart, filterBits, filterData,
                0, CHUNK_SIZE, true, firstRetrySleepMs);
        if (firstChunk == null || firstChunk.length() < 16) {
            return "";
        }
        fullHex.append(firstChunk);

        int targetWords = parseTargetWords(firstChunk);
        Log.i(TAG, "ToC says " + targetWords + " words");

        int offset = CHUNK_SIZE;
        while (offset < targetWords) {
            int wordsToRead = Math.min(CHUNK_SIZE, targetWords - offset);
            String chunkHex = readUserChunk(reader, filterBank, filterStart, filterBits, filterData,
                    offset, wordsToRead, false, retrySleepMs);
            if (chunkHex == null || chunkHex.isEmpty()) {
                Log.d(TAG, "Chunk at offset " + offset + " failed");
                break;
            }
            fullHex.append(chunkHex);
            Thread.sleep(loopSleepMs);
            offset += wordsToRead;
        }

        String result = fullHex.toString();
        return result.length() >= 16 ? result : "";
    }

    /**
     * Read one USER-memory chunk (wordCount words at offset) with MAX_RETRIES retries,
     * targeting the tag matched by the given filter.
     *
     * @param isFirst first chunk requires >=16 chars (a valid ToC header); later chunks
     *                only need to be non-empty.
     * @return chunk hex, or null if all retries failed.
     */
    private String readUserChunk(RFIDWithUHFUART reader,
            int filterBank, int filterStart, int filterBits, String filterData,
            int offset, int wordCount, boolean isFirst, int retrySleepMs) throws InterruptedException {
        for (int retry = 0; retry < MAX_RETRIES; retry++) {
            try {
                String chunk = reader.readData("00000000",
                        filterBank, filterStart, filterBits, filterData,
                        RFIDWithUHFUART.Bank_USER, offset, wordCount);
                if (chunk != null && (isFirst ? chunk.length() >= 16 : !chunk.isEmpty())) {
                    return chunk;
                }
            } catch (Exception e) {
                Log.w(TAG, "Chunk retry " + retry + " failed: " + e.getMessage());
            }
            if (retry < MAX_RETRIES - 1)
                Thread.sleep(retrySleepMs);
        }
        return null;
    }

    /**
     * Parse Size of ATA Memory from ToC Header (ATA Spec Figure 53)
     * Word 2: Flags[15:8] | Size of ToC Header[7:4] | Size of RDs[3:0]
     * Word 3: Size of ATA Memory (16 or 32 bit)
     */
    public static int parseTargetWords(String firstChunk) {
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
        } catch (Exception ignored) {
        }
        return maxWords;
    }

    private int clampUserWords(int words) {
        if (words < MIN_USER_WORDS)
            return MIN_USER_WORDS;
        return Math.min(words, MAX_USER_WORDS);
    }

    private synchronized String readUserMemoryForEpc(String epcHex) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null || epcHex == null || epcHex.isEmpty())
            return "";

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
                } catch (Exception ignored) {
                }
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
            } catch (Exception ignored) {
            }
        }
    }

    // ==================== LOCK STATUS READ ====================

    /**
     * Read USER memory block permalock status.
     * Uses uhfBlockPermalock with ReadLock=0 to query lock status.
     * 
     * @param epcHex     EPC of the tag to check
     * @param blockCount Number of 16-word blocks to check (1-8 typical)
     * @return Map with lock status info, or null on error
     *         - "lockedBlocks": comma-separated list of locked block numbers
     *         - "lockMask": hex string of lock mask
     *         - "birthLocked": true if Block 0 (words 0-15) is locked
     *         - "block0": true/false for each block
     */
    public synchronized Map<String, Object> readBlockLockStatus(String epcHex, int blockCount) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "Reader not available");
            return null;
        }

        boolean wasRunning = InventoryManager.getInstance().isStarted();
        try {
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(100);
            }

            // Normalize EPC
            String epc = epcHex.toUpperCase().replaceAll("[^0-9A-F]", "");
            int epcBits = epc.length() * 4;

            Log.d(TAG, "🔒 Reading lock status for EPC: " +
                    (epc.length() > 16 ? epc.substring(0, 16) + "..." : epc));

            // Set filter to target specific tag (if EPC provided)
            if (!epc.isEmpty()) {
                UHFManager.getInstance().setEpcFilter(epc);
                Thread.sleep(50);
            }

            // Prepare mask buffer for result (2 bytes = 16 blocks max)
            byte[] maskResult = new byte[2];
            boolean success = false;

            // Retry multiple times - lock status read can be flaky
            for (int attempt = 0; attempt < 3; attempt++) {
                // uhfBlockPermalock with ReadLock=0 reads lock status
                // uPtr=0, uRange=blockCount checks blocks 0 to blockCount-1
                if (!epc.isEmpty()) {
                    // With EPC filter
                    success = reader.uhfBlockPermalock(
                            "00000000", // accessPwd
                            RFIDWithUHFUART.Bank_EPC, // filterBank
                            32, // filterPtr (after PC+CRC)
                            epcBits, // filterCnt
                            epc, // filterData
                            0, // ReadLock: 0 = READ lock status
                            RFIDWithUHFUART.Bank_USER, // uBank: USER memory
                            0, // uPtr: start at block 0
                            Math.min(blockCount, 8), // uRange: number of blocks to check
                            maskResult // uMaskbuf: result buffer
                    );
                } else {
                    // Without filter - read any tag in range
                    success = reader.uhfBlockPermalock(
                            "00000000", // accessPwd
                            RFIDWithUHFUART.Bank_EPC, // filterBank
                            0, // filterPtr
                            0, // filterCnt = 0 means no filter
                            "", // filterData
                            0, // ReadLock: 0 = READ lock status
                            RFIDWithUHFUART.Bank_USER, // uBank: USER memory
                            0, // uPtr: start at block 0
                            Math.min(blockCount, 8), // uRange: number of blocks to check
                            maskResult // uMaskbuf: result buffer
                    );
                }

                if (success) {
                    Log.d(TAG, "🔒 Lock read success on attempt " + (attempt + 1));
                    break;
                }

                Thread.sleep(100);
            }

            if (!success) {
                Log.w(TAG, "⚠️ Block permalock query failed - trying test write method...");

                // Alternative: Try a test write to detect if tag is locked
                // Read current value at word 0, try to write same value back
                // If write fails, tag is likely permalocked
                String currentValue = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 1);
                if (currentValue != null && currentValue.length() >= 4) {
                    // Try to write the same value back (non-destructive test)
                    boolean canWrite = reader.writeData("00000000", RFIDWithUHFUART.Bank_USER, 0, 1, currentValue);

                    if (!canWrite) {
                        Log.d(TAG, "🔒 Test write failed - Block 0 is LOCKED");
                        java.util.Map<String, Object> lockedResult = new java.util.HashMap<>();
                        lockedResult.put("lockMask", "TEST");
                        lockedResult.put("lockedBlocks", "0");
                        lockedResult.put("birthLocked", true);
                        lockedResult.put("block0", true);
                        lockedResult.put("testWriteMethod", true);
                        return lockedResult;
                    } else {
                        Log.d(TAG, "🔓 Test write succeeded - Block 0 is UNLOCKED");
                        java.util.Map<String, Object> unlockedResult = new java.util.HashMap<>();
                        unlockedResult.put("lockMask", "0000");
                        unlockedResult.put("lockedBlocks", "");
                        unlockedResult.put("birthLocked", false);
                        unlockedResult.put("block0", false);
                        unlockedResult.put("testWriteMethod", true);
                        return unlockedResult;
                    }
                }

                // If test write also failed, return unknown
                java.util.Map<String, Object> unknownResult = new java.util.HashMap<>();
                unknownResult.put("lockMask", "UNKNOWN");
                unknownResult.put("lockedBlocks", "");
                unknownResult.put("birthLocked", false);
                unknownResult.put("unknown", true);
                return unknownResult;
            }

            // Parse result
            int lockMask = ((maskResult[0] & 0xFF) << 8) | (maskResult[1] & 0xFF);
            StringBuilder lockedBlocks = new StringBuilder();
            boolean birthLocked = false;

            java.util.Map<String, Object> result = new java.util.HashMap<>();

            for (int i = 0; i < blockCount && i < 16; i++) {
                boolean isLocked = ((lockMask >> (15 - i)) & 1) == 1;
                result.put("block" + i, isLocked);

                if (isLocked) {
                    if (lockedBlocks.length() > 0)
                        lockedBlocks.append(",");
                    lockedBlocks.append(i);
                    if (i == 0)
                        birthLocked = true;
                }
            }

            result.put("lockMask", String.format("%04X", lockMask));
            result.put("lockedBlocks", lockedBlocks.toString());
            result.put("birthLocked", birthLocked);

            Log.d(TAG, "🔒 Lock status: mask=0x" + String.format("%04X", lockMask) +
                    ", locked=[" + lockedBlocks + "], birthLocked=" + birthLocked);

            return result;

        } catch (Exception e) {
            Log.e(TAG, "Error reading lock status: " + e.getMessage(), e);
            return null;
        } finally {
            UHFManager.getInstance().clearFilter();
            restoreInventory(wasRunning);
        }
    }

    /**
     * Read ATA Spec 2000 Lock Flags from USER memory Word 2.
     * Word 2 bits [15:8] contain lock flags per ATA Spec.
     * 
     * @param userHex Full USER memory hex string
     * @return Map with parsed lock flags, or null if invalid
     *         - "lockFlags": raw byte value
     *         - "tocLocked": bit 0 - ToC Header locked
     *         - "rdLocked": bit 1 - Record Descriptors locked
     *         - "birthLocked": bit 2 - Birth Record locked (per ATA Spec)
     */
    public static Map<String, Object> parseAtaLockFlags(String userHex) {
        if (userHex == null || userHex.length() < 12)
            return null;

        try {
            // Word 2 is at hex offset 8-12 (chars 8-11)
            int word2 = Integer.parseInt(userHex.substring(8, 12), 16);
            int lockFlags = (word2 >> 8) & 0xFF;

            java.util.Map<String, Object> result = new java.util.HashMap<>();
            result.put("lockFlags", lockFlags);
            result.put("lockFlagsHex", String.format("0x%02X", lockFlags));

            // ATA Spec 2000 Lock Flags interpretation (implementation-defined)
            // Common convention: bit 0 = ToC, bit 1 = RDs, bit 2 = Birth
            result.put("tocLocked", (lockFlags & 0x01) != 0);
            result.put("rdLocked", (lockFlags & 0x02) != 0);
            result.put("birthLocked", (lockFlags & 0x04) != 0);

            Log.d(TAG, "🔒 ATA Lock Flags: 0x" + String.format("%02X", lockFlags) +
                    " (ToC=" + ((lockFlags & 0x01) != 0) +
                    ", RD=" + ((lockFlags & 0x02) != 0) +
                    ", Birth=" + ((lockFlags & 0x04) != 0) + ")");

            return result;
        } catch (Exception e) {
            Log.e(TAG, "Error parsing ATA lock flags: " + e.getMessage());
            return null;
        }
    }
}
