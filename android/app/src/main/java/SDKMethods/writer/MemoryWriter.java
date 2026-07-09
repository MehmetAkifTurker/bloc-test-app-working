package SDKMethods.writer;

import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;

import java.util.Locale;

import SDKMethods.ata.AtaEncodingUtils;
import SDKMethods.core.UHFManager;
import SDKMethods.inventory.InventoryManager;

/**
 * Memory Writer - Handles all USER/EPC memory write operations
 */
public class MemoryWriter {
    private static final String TAG = "MemoryWriter";

    private static MemoryWriter instance;

    private String currentRecordType = "DRT";
    private int currentEpcWords = 12;
    private int currentUserWords = 32;
    private int currentPermalockWords = 0;
    // ATA Spec A-4-2: USER ToC "ATA Classification" field shall be 0x01 (flyable parts).
    // NOTE: this is NOT the EPC Filter Value (that lives in the EPC bank, separately).
    private static final int ATA_CLASSIFICATION = 0x01;
    // ATA Spec Table 17 (Version Control): ToC Major=4 (0b0100), Minor=2 (0b010).
    private static final int TOC_MAJOR_VERSION = 0x4;
    private static final int TOC_MINOR_VERSION = 0x2;
    // ATA Spec Table 17 + Figure 56: a Data Record header's low byte is
    // DR Version(3 bits)=1 | BD Version(5 bits)=3  ->  (1<<5)|3 = 0x23.
    // (This byte is NOT record flags; the 6/8-bit encoding flag lives in the
    // Record Descriptor, not the Data Record header.)
    private static final int DR_BD_VERSION = (0x1 << 5) | 0x03; // 0x23
    // ATA Spec A-4-3: Size of RDs field code — 0x02 = full ToC with 16-bit
    // record addresses (2-word RDs). This is NOT the number of records (that
    // lives in the ToC Trailer). We always use 16-bit record addresses.
    private static final int RD_SIZE_CODE_16BIT = 0x02;
    // UID Construct used when programming the EPC (1 = SER only, 2 = PartNumber + SER).
    // Set by programConstruct1Epc / programConstruct2Epc; written into the Birth Record UIC field
    // so the USER memory always reflects how the EPC was actually built.
    private int currentUidConstruct = 2;

    // Optional extra ATA TEIs (beyond the common fields) to append to the Birth
    // Record payload on the next write. Set by writeAtaUserMemoryWithPayload.
    // Keeps the common UI simple while allowing any spec TEI -> "universal" writing.
    private java.util.Map<String, String> currentExtraFields = null;

    // Calculated permalock size from last write operation
    // This is the RECOMMENDED permalock size based on actual data written
    private int lastCalculatedPermalockWords = 0;

    private MemoryWriter() {
    }

    public static synchronized MemoryWriter getInstance() {
        if (instance == null) {
            instance = new MemoryWriter();
        }
        return instance;
    }

    // ==================== RADIO SAFETY ====================

    /**
     * Quiesce every other radio user before a write. Continuous inventory
     * (and its background USER-fetch batches) or a locate polling loop
     * running concurrently with writeData crashes the native SDK lib — and
     * dying mid-write can leave a half-programmed tag. Scanning is NOT
     * auto-resumed afterwards: a write means the operator is on the write
     * screen; the scan screen restarts inventory itself.
     *
     * Callers must invoke this while holding the MemoryReader monitor (see
     * RfidC72Plugin.runWrite) so in-flight reads finish first.
     */
    public void quiesceRadioForWrite() {
        try {
            SDKMethods.location.LocationManager lm =
                    SDKMethods.location.LocationManager.getInstance();
            if (lm.isLocating()) {
                Log.w(TAG, "write: locate loop active — stopping it");
                lm.stopLocation();
            }
        } catch (Exception ignore) {
        }
        try {
            if (InventoryManager.getInstance().isStarted()) {
                Log.w(TAG, "write: continuous inventory active — stopping it");
                InventoryManager.getInstance().stop();
                Thread.sleep(80);
            }
        } catch (Exception ignore) {
        }
    }

    /** Log the module's error code after a failed write op (diagnostics). */
    private void logWriteErr(String what) {
        try {
            RFIDWithUHFUART r = UHFManager.getInstance().getReader();
            if (r != null) Log.w(TAG, what + " failed, errCode=" + r.getErrCode());
        } catch (Throwable ignore) {
        }
    }

    /**
     * Write USER-bank words with one automatic retry. A transient RF glitch
     * shouldn't abort a multi-chunk write and strand a half-programmed tag;
     * the second attempt lands ~60ms later on different channel conditions.
     */
    private boolean writeUserWords(RFIDWithUHFUART reader, int ptr, int cnt,
            String hex, String label) {
        for (int attempt = 0; attempt < 2; attempt++) {
            try {
                if (reader.writeData("00000000", RFIDWithUHFUART.Bank_USER, ptr, cnt, hex)) {
                    return true;
                }
            } catch (Exception e) {
                Log.w(TAG, label + " write exception: " + e.getMessage());
            }
            logWriteErr(label + " @word " + ptr + " (" + cnt + "w) attempt " + (attempt + 1));
            try {
                Thread.sleep(60);
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                return false;
            }
        }
        return false;
    }

    // ==================== WRITE VERIFICATION ====================
    // The SDK's write booleans are not trustworthy on this hardware (same
    // class of bug as setPower returning SUCCESS while not applied), so every
    // write is verified by reading back. A verified write is the only write
    // that counts.

    /** Re-inventory the tag and check it now carries the EPC we wrote. */
    private boolean verifyEpcWrite(RFIDWithUHFUART reader, String writtenEpcHex) {
        String expected = writtenEpcHex.toUpperCase(Locale.ROOT);
        for (int attempt = 0; attempt < 3; attempt++) {
            try {
                UHFTAGInfo info = reader.inventorySingleTag();
                if (info != null && info.getEPC() != null) {
                    String got = info.getEPC().toUpperCase(Locale.ROOT);
                    if (got.startsWith(expected) || expected.startsWith(got)) {
                        Log.i(TAG, "✅ EPC verify OK (" + got.length() / 4 + "w)");
                        return true;
                    }
                    Log.w(TAG, "EPC verify mismatch: wrote " + expected + " read " + got);
                }
                Thread.sleep(60);
            } catch (Exception ignore) {
            }
        }
        Log.e(TAG, "❌ EPC verify FAILED after 3 attempts");
        return false;
    }

    /** Full-image verify (Birth/DRT/MRT write the whole image from word 0). */
    private boolean verifyUserWrite(RFIDWithUHFUART reader, String expectedHex, int totalWords) {
        return verifyUserWrite(reader, expectedHex, totalWords, 0);
    }

    /**
     * Read back totalWords of USER memory starting at startWord and compare
     * with what we wrote. startWord != 0 lets in-place record updates
     * (Lifecycle at lifecycleAddr, CDR at cdrAddr) verify just the record
     * they rewrote, not the whole image.
     */
    private boolean verifyUserWrite(RFIDWithUHFUART reader, String expectedHex,
            int totalWords, int startWord) {
        try {
            String expected = expectedHex.toUpperCase(Locale.ROOT);
            StringBuilder readBack = new StringBuilder();
            int read = 0;
            while (read < totalWords) {
                int n = Math.min(32, totalWords - read);
                String chunk = null;
                for (int r = 0; r < 2 && (chunk == null || chunk.isEmpty()); r++) {
                    chunk = reader.readData("00000000", RFIDWithUHFUART.Bank_USER,
                            startWord + read, n);
                    if (chunk == null || chunk.isEmpty()) Thread.sleep(40);
                }
                if (chunk == null || chunk.isEmpty()) {
                    Log.e(TAG, "❌ USER verify: read-back failed @word " + (startWord + read));
                    return false;
                }
                readBack.append(chunk);
                read += n;
            }
            String got = readBack.toString().toUpperCase(Locale.ROOT);
            int cmpLen = Math.min(got.length(), expected.length());
            if (got.regionMatches(0, expected, 0, cmpLen) && cmpLen == expected.length()) {
                Log.i(TAG, "✅ USER verify OK (" + totalWords + "w @word " + startWord + ")");
                return true;
            }
            // Diagnostics: first differing word (relative to startWord)
            int diffWord = -1;
            for (int i = 0; i < cmpLen; i += 4) {
                int end = Math.min(i + 4, cmpLen);
                if (!got.regionMatches(0 + i, expected, i, end - i)) {
                    diffWord = startWord + i / 4;
                    break;
                }
            }
            Log.e(TAG, "❌ USER verify MISMATCH @word " + diffWord
                    + " (readBack " + got.length() / 4 + "w vs expected "
                    + expected.length() / 4 + "w)");
            return false;
        } catch (Exception e) {
            Log.e(TAG, "USER verify error: " + e.getMessage());
            return false;
        }
    }

    /**
     * Query block-permalock state (ReadLock=0) and confirm the requested
     * blocks now read as locked. Permalock is irreversible — reporting
     * success without this check would be a lie the operator can't undo.
     */
    private boolean verifyPermalock(RFIDWithUHFUART reader, String pwd,
            String filterEpc, int startBlock, int blockCount, byte[] expectedMask) {
        try {
            byte[] got = new byte[Math.max(expectedMask.length, 2)];
            boolean ok;
            if (filterEpc != null && !filterEpc.isEmpty()) {
                int epcBits = filterEpc.length() * 4;
                ok = reader.uhfBlockPermalock(pwd,
                        RFIDWithUHFUART.Bank_EPC, 32, epcBits, filterEpc,
                        0, RFIDWithUHFUART.Bank_USER, startBlock, blockCount, got);
            } else {
                ok = reader.uhfBlockPermalock(pwd,
                        0, 0, 0, "",
                        0, RFIDWithUHFUART.Bank_USER, startBlock, blockCount, got);
            }
            if (!ok) {
                Log.w(TAG, "permalock verify: status read failed");
                return false;
            }
            for (int i = 0; i < expectedMask.length; i++) {
                if ((got[i] & expectedMask[i]) != expectedMask[i]) {
                    Log.e(TAG, "❌ PERMALOCK verify: blocks not locked (mask byte "
                            + i + ": got " + String.format("%02X", got[i])
                            + " want " + String.format("%02X", expectedMask[i]) + ")");
                    return false;
                }
            }
            Log.i(TAG, "✅ PERMALOCK verify OK");
            return true;
        } catch (Exception e) {
            Log.w(TAG, "permalock verify error: " + e.getMessage());
            return false;
        }
    }

    /**
     * ATA Spec 2000 Birth Record serial TEI, selected by the UID Construct
     * (Birth Record §1.1 item 4):
     *   UIC=2 (Construct 2: serial unique within the Part Number) -> SEQ (needs PNO)
     *   UIC=1 (Construct 1: serial unique within the CAGE code)   -> SER
     */
    private String serialTei() {
        return currentUidConstruct == 2 ? "SEQ" : "SER";
    }

    // ==================== CHIP CONFIGURATION ====================

    public boolean prepareAtaChip(String recordType, int epcWords, int userWords,
            int permalockWords, boolean enablePermalock, boolean lockEpc,
            boolean lockUser, String accessPwdHex) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "prepareAtaChip: mReader is null");
            return false;
        }

        currentRecordType = (recordType == null ? "DRT" : recordType);
        currentEpcWords = Math.max(8, epcWords);
        currentUserWords = Math.max(0, userWords);
        currentPermalockWords = Math.max(0, permalockWords);
        lastCalculatedPermalockWords = 0; // Reset until write calculates it

        return true;
    }

    /**
     * Get the calculated permalock size from the last write operation.
     * This is the RECOMMENDED size based on actual data written:
     * - For DRT: ToC(4) + RDs(4) + Birth Record, rounded up to 16-word block
     * boundary
     * - For SRT-B: Entire tag (all data is Birth Record)
     * - For SRT-U: 0 (utility tags should not be permalocked)
     * - For MRT: ToC(4) + RDs(4) + Birth Record, rounded up to 16-word block
     * boundary
     * 
     * IMPORTANT: Block Permalock works on 16-word blocks!
     * For DRT/MRT, we cap at 16 words (Block 0 only) to keep Lifecycle/CDR
     * writable.
     * 
     * @return Recommended permalock words (0 if not yet calculated or utility tag)
     */
    public int getLastCalculatedPermalockWords() {
        return lastCalculatedPermalockWords;
    }

    // ==================== ACCESS PASSWORD ====================

    /**
     * Set Access Password for tag locking
     * CRITICAL: Password must be set before locking can work!
     * 
     * @param oldPassword Current password (default: "00000000")
     * @param newPassword New password (4 bytes hex, e.g., "00000001")
     * @return true if successful
     */
    public boolean setAccessPassword(String oldPassword, String newPassword) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "setAccessPassword: mReader is null");
            return false;
        }

        try {
            Log.i(TAG, "🔑 Setting Access Password: " + oldPassword + " → " + newPassword);

            // Stop inventory
            boolean wasRunning = InventoryManager.getInstance().isStarted();
            if (wasRunning) {
                reader.stopInventory();
                Thread.sleep(100);
            }

            // Write to RESERVED bank (Bank 0), Word 2 (Access Password address)
            boolean success = reader.writeData(
                    oldPassword, // Old password
                    RFIDWithUHFUART.Bank_RESERVED, // Bank 0 (RESERVED)
                    2, // Word 2 (Access Password address)
                    2, // 2 words (4 bytes)
                    newPassword // New password
            );

            if (success) {
                Log.i(TAG, "✅ Access Password set successfully");

                // Verify by trying to read with new password
                try {
                    Thread.sleep(100);
                    String verify = reader.readData(newPassword, RFIDWithUHFUART.Bank_EPC, 0, 1);
                    if (verify != null && !verify.isEmpty()) {
                        Log.i(TAG, "✓ Password verified - tag responds with new password");
                    }
                } catch (Exception e) {
                    Log.w(TAG, "Could not verify password: " + e.getMessage());
                }
            } else {
                Log.e(TAG, "❌ Failed to set Access Password");
            }

            // Restore inventory
            if (wasRunning) {
                try {
                    Thread.sleep(100);
                    reader.startInventoryTag();
                } catch (Exception e) {
                    Log.w(TAG, "Failed to restart inventory: " + e.getMessage());
                }
            }

            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error setting Access Password: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== MEMORY LOCKING (ATA Spec 2000) ====================

    /**
     * Lock USER memory using SDK lockMem function
     * Per ATA Spec 2000: Birth Record should be permalocked after writing
     * 
     * @param accessPwdHex Access password (8 hex chars, default "00000000")
     * @param lockMode     Lock mode:
     *                     LockMode_LOCK (reversible with password)
     *                     LockMode_PLOCK (permanent, irreversible!)
     * @return true if successful
     */
    public boolean lockUserMemory(String accessPwdHex, boolean permanentLock) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "lockUserMemory: mReader is null");
            return false;
        }

        try {
            // Generate lock code for USER memory
            // LockBank_USER = 4
            // LockMode_LOCK = 1 (reversible), LockMode_PLOCK = 2 (permanent!)
            java.util.ArrayList<Integer> lockBanks = new java.util.ArrayList<>();
            lockBanks.add(RFIDWithUHFUART.LockBank_USER);

            int lockMode = permanentLock ? RFIDWithUHFUART.LockMode_PLOCK : RFIDWithUHFUART.LockMode_LOCK;
            String lockCode = reader.generateLockCode(lockBanks, lockMode);

            if (lockCode == null || lockCode.isEmpty()) {
                Log.e(TAG, "❌ Failed to generate lock code");
                return false;
            }

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            boolean success = reader.lockMem(pwd, lockCode);

            Log.i(TAG, success ? "✅ USER memory locked (permanent=" + permanentLock + ")"
                    : "❌ Failed to lock USER memory");
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error locking USER memory: " + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Lock EPC memory
     */
    public boolean lockEpcMemory(String accessPwdHex, boolean permanentLock) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            java.util.ArrayList<Integer> lockBanks = new java.util.ArrayList<>();
            lockBanks.add(RFIDWithUHFUART.LockBank_EPC);

            int lockMode = permanentLock ? RFIDWithUHFUART.LockMode_PLOCK : RFIDWithUHFUART.LockMode_LOCK;
            String lockCode = reader.generateLockCode(lockBanks, lockMode);

            if (lockCode == null) {
                Log.e(TAG, "❌ Failed to generate EPC lock code");
                return false;
            }

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            boolean success = reader.lockMem(pwd, lockCode);

            Log.i(TAG, success ? "✅ EPC memory locked" : "❌ Failed to lock EPC memory");
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error locking EPC memory: " + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Permalock specific words in USER memory using Block Permalock
     * This is permanent and cannot be undone!
     * Used for ATA Spec Birth Record locking.
     * 
     * @param accessPwdHex Access password
     * @param startWord    Start word address in USER memory
     * @param wordCount    Number of words to permalock
     * @return true if successful
     */
    public boolean permalockUserBlocks(String accessPwdHex, int startWord, int wordCount) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "permalockUserBlocks: mReader is null");
            return false;
        }

        try {
            Log.i(TAG, "🔒 PERMALOCK: Words " + startWord + " to " + (startWord + wordCount - 1));

            // Block Permalock operates on 16-word blocks
            // We need to calculate which blocks to lock
            int startBlock = startWord / 16;
            int endWord = startWord + wordCount - 1;
            int endBlock = endWord / 16;
            int blockCount = endBlock - startBlock + 1;

            Log.d(TAG, "  Start block: " + startBlock);
            Log.d(TAG, "  End block: " + endBlock);
            Log.d(TAG, "  Block count: " + blockCount);

            // Create mask for blocks to lock (1 bit per block).
            // SDK (IUHF.uhfBlockPermalock): "high level is at front" => MSB-first.
            // Block N => bit (7 - N%8) of byte N/8. Block 0 => 0x80, not 0x01.
            byte[] mask = new byte[(blockCount + 7) / 8];
            for (int i = 0; i < blockCount; i++) {
                int byteIdx = i / 8;
                int bitIdx = i % 8;
                mask[byteIdx] |= (byte) (1 << (7 - bitIdx));
            }

            // Log mask for debugging
            StringBuilder maskHex = new StringBuilder();
            for (byte b : mask) {
                maskHex.append(String.format("%02X", b));
            }
            Log.d(TAG, "  Mask: 0x" + maskHex + " (binary: " + Integer.toBinaryString(mask[0] & 0xFF) + ")");

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;

            Log.d(TAG, "📝 uhfBlockPermalock params:");
            Log.d(TAG, "  Password: " + pwd);
            Log.d(TAG, "  FilterBank: 0, FilterStart: 0, FilterLen: 0, FilterData: ''");
            Log.d(TAG, "  ReadLock: 1 (LOCK mode - per SDK doc: 0=read, 1=lock)");
            Log.d(TAG, "  BlockPtr: " + startBlock);
            Log.d(TAG, "  BlockRange: " + blockCount);
            Log.d(TAG, "  MaskLen: " + blockCount);
            Log.d(TAG, "  Mask: " + maskHex);

            // Try to get current tag EPC for filtering
            String currentEpc = "";
            try {
                UHFTAGInfo tag = reader.inventorySingleTag();
                if (tag != null && tag.getEPC() != null) {
                    currentEpc = tag.getEPC();
                    Log.d(TAG, "📍 Current tag EPC: " + currentEpc.substring(0, Math.min(16, currentEpc.length()))
                            + "...");
                }
            } catch (Exception e) {
                Log.w(TAG, "Could not read current tag for filter: " + e.getMessage());
            }

            // uhfBlockPermalock parameters (per SDK documentation):
            // accessPwd, FilterBank, FilterStartaddr, FilterLen, FilterData,
            // ReadLock (0=read status, 1=LOCK!), uBank, uPtr, uRange, uMaskbuf
            // CRITICAL: ReadLock must be 1 to actually perform the lock!

            boolean success;
            if (currentEpc != null && !currentEpc.isEmpty()) {
                // Try WITH EPC filter (some tags require this)
                int epcBits = currentEpc.length() * 4;
                Log.d(TAG, "  Trying WITH EPC filter (" + epcBits + " bits)...");
                // uhfBlockPermalock params: accessPwd, FilterBank, FilterStartaddr, FilterLen,
                // FilterData, ReadLock (1=LOCK!), uBank (USER=3), uPtr, uRange, uMaskbuf
                success = reader.uhfBlockPermalock(
                        pwd,
                        RFIDWithUHFUART.Bank_EPC, 32, epcBits, currentEpc, // EPC filter
                        1, // ReadLock: 1 = LOCK mode (per SDK: 0=read, 1=lock)
                        RFIDWithUHFUART.Bank_USER, // uBank: USER memory bank (3)
                        startBlock, // uPtr: block pointer
                        blockCount, // uRange: number of blocks
                        mask // uMaskbuf: mask for which blocks to lock
                );

                if (!success) {
                    Log.w(TAG, "  Permalock with filter failed, trying without filter...");
                    success = reader.uhfBlockPermalock(
                            pwd,
                            0, 0, 0, "", // No filter
                            1, // ReadLock: 1 = LOCK mode (per SDK: 0=read, 1=lock)
                            RFIDWithUHFUART.Bank_USER, // uBank: USER memory bank (3)
                            startBlock, // uPtr: block pointer
                            blockCount, // uRange: number of blocks
                            mask // uMaskbuf
                    );
                }
            } else {
                // Try WITHOUT filter
                Log.d(TAG, "  Trying WITHOUT filter...");
                success = reader.uhfBlockPermalock(
                        pwd,
                        0, 0, 0, "", // No filter
                        1, // ReadLock: 1 = LOCK mode (per SDK: 0=read, 1=lock)
                        RFIDWithUHFUART.Bank_USER, // uBank: USER memory bank (3)
                        startBlock, // uPtr: block pointer
                        blockCount, // uRange: number of blocks
                        mask // uMaskbuf
                );
            }

            if (success) {
                // Permalock is irreversible — confirm the blocks actually
                // read back as locked before reporting success.
                success = verifyPermalock(reader, pwd, currentEpc, startBlock, blockCount, mask);
            }
            if (success) {
                Log.i(TAG, "✅ PERMALOCK: Successfully locked " + blockCount + " blocks (verified)");
            } else {
                logWriteErr("uhfBlockPermalock (" + blockCount + " blocks)");
                Log.e(TAG, "❌ PERMALOCK: Failed to lock (or verify) blocks");
            }

            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error in permalockUserBlocks: " + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Apply the permalock computed by the most recent USER write, starting at word 0
     * (ToC header). Used to honor the in-app "Permalock" toggle right after writing.
     *
     * Coverage per record type (set during the write):
     *  - SRT-B / DRT / MRT: ToC + RDs + Birth Record (block-aligned; Lifecycle stays writable)
     *  - SRT-U: 0 words -> nothing locked (utility tags stay rewritable per ATA Spec)
     *
     * WARNING: permalock is PERMANENT and IRREVERSIBLE.
     *
     * @return true if locked (or nothing to lock); false if the lock failed.
     */
    public boolean applyCalculatedPermalock(String accessPwdHex) {
        int words = lastCalculatedPermalockWords;
        if (words <= 0) {
            Log.i(TAG, "applyCalculatedPermalock: nothing to lock (SRT-U or not calculated)");
            return true; // not an error: utility tags are intentionally left open
        }
        Log.i(TAG, "applyCalculatedPermalock: locking " + words + " words from word 0");
        return permalockUserBlocks(accessPwdHex, 0, words);
    }

    // ==================== EPC WRITE ====================

    public boolean writeTagADIConstruct2(String partNumber, String serialNumber) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "mReader is null; cannot write!");
            return false;
        }

        try {
            String headerBits = "00111011";
            String filterBits = "001110";
            String manager = " TG424";

            StringBuilder epcBin = new StringBuilder();
            epcBin.append(headerBits).append(filterBits);
            epcBin.append(AtaEncodingUtils.encode6Bit(manager));
            epcBin.append(AtaEncodingUtils.encode6Bit(partNumber)).append("000000");
            epcBin.append(AtaEncodingUtils.encode6Bit(serialNumber)).append("000000");

            int padBits = (8 - (epcBin.length() % 8)) % 8;
            for (int i = 0; i < padBits; i++)
                epcBin.append('0');

            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBin.length(); i += 4) {
                String chunk = epcBin.substring(i, i + 4);
                epcHex.append(Integer.toHexString(Integer.parseInt(chunk, 2)).toUpperCase(Locale.ROOT));
            }

            int epcWordCount = epcBin.length() / 16;
            int pcWord = (epcWordCount << 11) | 0x3000;
            String pcWordHex = String.format("%04X", pcWord);

            String writeData = pcWordHex + epcHex.toString();

            boolean success = reader.writeData("00000000", 1, 1, epcWordCount + 1, writeData);
            Log.i(TAG, "WriteTagADIConstruct2: success=" + success);

            if (success) {
                UHFManager.getInstance().playSound();
            } else {
                UHFManager.getInstance().playErrorSound();
            }
            return success;
        } catch (Exception e) {
            Log.e(TAG, "Error writing Construct 2: " + e.getMessage(), e);
            return false;
        }
    }

    /**
     * Program EPC using Construct 1 format (Serial Number only, no Part Number)
     * ATA Spec 2000 Figure 23: Header + Filter + Manager + NUL + Serial + NUL
     * Used for Single Record Utility tags where only CAGE + UCN is needed
     * 
     * @param serialNumber Serial/UCN (up to 30 alphanumeric chars)
     * @param manager6     CAGE code with leading space (e.g., " ABCDE")
     * @param accessPwdHex Access password (8 hex chars) or null for default
     * @param filterValue  EPC filter value (0-63)
     */
    public boolean programConstruct1Epc(String serialNumber,
            String manager6, String accessPwdHex, int filterValue) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            String headerBits = "00111011"; // 0x3B - ATA Spec header
            int fv = (filterValue < 0 || filterValue > 63) ? 0 : filterValue;

            // Filter Value is encoded into the EPC only (filterBits below).
            // ATA Classification in the USER ToC is a separate field (always 0x01 per spec).
            currentUidConstruct = 1; // Construct 1: SER only (no Part Number in EPC)
            String filterBits = String.format("%6s", Integer.toBinaryString(fv)).replace(' ', '0');

            StringBuilder epcBits = new StringBuilder();
            // Construct 1: Header + Filter + Manager + Delimiter(NUL) + Serial +
            // Terminator(NUL)
            // NO Part Number in Construct 1!

            String managerEncoded = AtaEncodingUtils.encode6Bit(manager6);
            String serialEncoded = AtaEncodingUtils.encode6Bit(serialNumber);

            Log.d(TAG, "🔍 Construct1 Encoding:");
            Log.d(TAG, "  Header: " + headerBits + " (" + headerBits.length() + " bits)");
            Log.d(TAG, "  Filter: " + filterBits + " (" + filterBits.length() + " bits)");
            Log.d(TAG, "  Manager '" + manager6 + "' → " + managerEncoded + " (" + managerEncoded.length() + " bits)");
            Log.d(TAG, "  Serial '" + serialNumber + "' → " + serialEncoded + " (" + serialEncoded.length() + " bits)");

            epcBits.append(headerBits).append(filterBits)
                    .append(managerEncoded)
                    .append("000000") // Delimiter (NUL) - no part number before this
                    .append(serialEncoded)
                    .append("000000"); // Terminator (NUL)

            Log.d(TAG, "  Total bits before padding: " + epcBits.length());

            // Pad to 16-bit word boundary
            int pad16 = (16 - (epcBits.length() % 16)) % 16;
            for (int i = 0; i < pad16; i++)
                epcBits.append('0');

            Log.d(TAG, "  Padding: " + pad16 + " bits");
            Log.d(TAG, "  Total bits after padding: " + epcBits.length());
            Log.d(TAG, "  Total words: " + (epcBits.length() / 16));

            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBits.length(); i += 4) {
                epcHex.append(Integer.toHexString(
                        Integer.parseInt(epcBits.substring(i, i + 4), 2)).toUpperCase(Locale.ROOT));
            }
            while ((epcHex.length() & 0x3) != 0)
                epcHex.append('0');

            Log.i(TAG, "Construct1 EPC: " + epcHex.toString() + " (Serial: " + serialNumber + ", CAGE: "
                    + manager6.trim() + ")");
            Log.d(TAG, "  Final EPC: " + epcHex.length() + " chars (" + (epcHex.length() / 4) + " words)");

            // Stop inventory for write operation
            boolean wasInventorying = InventoryManager.getInstance().isStarted();
            if (wasInventorying) {
                Log.d(TAG, "Stopping inventory for write...");
                reader.stopInventory();
                Thread.sleep(100);
            }

            // Clear any filters
            try {
                reader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
                Thread.sleep(50);
            } catch (Exception e) {
                Log.w(TAG, "Failed to clear filter: " + e.getMessage());
            }

            // Read current tag to check EPC capacity
            try {
                UHFTAGInfo currentTag = reader.inventorySingleTag();
                if (currentTag != null) {
                    String currentEpc = currentTag.getEPC();
                    if (currentEpc != null) {
                        int currentEpcWords = currentEpc.length() / 4;
                        int newEpcWords = epcHex.length() / 4;

                        Log.d(TAG, "📊 EPC Capacity Check:");
                        Log.d(TAG, "  Current EPC: " + currentEpc.substring(0, Math.min(16, currentEpc.length()))
                                + "... (" + currentEpcWords + " words)");
                        Log.d(TAG, "  New EPC:     " + epcHex.substring(0, Math.min(16, epcHex.length())) + "... ("
                                + newEpcWords + " words)");

                        if (newEpcWords > currentEpcWords) {
                            Log.w(TAG, "⚠️ WARNING: New EPC (" + newEpcWords + " words) is LARGER than current EPC ("
                                    + currentEpcWords + " words)!");
                            Log.w(TAG, "   Tag may not support larger EPC! Write may fail!");
                            Log.w(TAG, "   Solution: Shorten serial number (e.g., SN00001 → SN001)");
                        } else {
                            Log.d(TAG, "✓ New EPC fits in tag's EPC memory");
                        }
                    }
                }
            } catch (Exception e) {
                Log.d(TAG, "Could not read current tag for capacity check: " + e.getMessage());
            }

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;

            // Check current power level
            try {
                int power = reader.getPower();
                Log.d(TAG, "📡 Current RF Power: " + power + " dBm");
                if (power < 20) {
                    Log.w(TAG, "⚠️ WARNING: Power too low for write! Current: " + power
                            + " dBm, Minimum: 20 dBm, Recommended: 25-30 dBm");
                }
            } catch (Exception e) {
                Log.d(TAG, "Could not read power level: " + e.getMessage());
            }

            Log.d(TAG, "📝 Writing EPC...");
            Log.d(TAG, "  EPC Data: " + epcHex);
            Log.d(TAG, "  Password: " + pwd);
            Log.d(TAG, "  EPC Length: " + epcHex.length() + " chars (" + (epcHex.length() / 4) + " words)");

            boolean success = reader.writeDataToEpc(pwd, epcHex.toString());

            if (success) {
                Log.i(TAG, "✅ Construct1 EPC written, verifying...");
                // Gate on read-back: an unverified EPC write does not count
                // (the old code only logged a warning on mismatch).
                success = verifyEpcWrite(reader, epcHex.toString());
            } else {
                logWriteErr("programConstruct1Epc writeDataToEpc");
                Log.e(TAG, "❌ Construct1 EPC write failed");
                Log.e(TAG, "  Possible reasons:");
                Log.e(TAG, "    1. Tag out of range (move closer)");
                Log.e(TAG, "    2. Power too low (use 25-30 dBm)");
                Log.e(TAG, "    3. Tag is write-protected/locked");
                Log.e(TAG, "    4. Wrong access password");
                Log.e(TAG, "    5. Tag doesn't support writeDataToEpc");
            }

            // Restore inventory if it was running
            if (wasInventorying) {
                try {
                    Thread.sleep(100);
                    reader.startInventoryTag();
                } catch (Exception e) {
                    Log.w(TAG, "Failed to restart inventory: " + e.getMessage());
                }
            }

            return success;
        } catch (Exception e) {
            Log.e(TAG, "programConstruct1Epc error", e);
            return false;
        }
    }

    /**
     * Program EPC using Construct 2 format (Part Number + Serial Number)
     * ATA Spec 2000 Figure 24: Header + Filter + Manager + PartNumber + NUL +
     * Serial + NUL
     */
    public boolean programConstruct2Epc(String partNumber, String serialNumber,
            String manager6, String accessPwdHex, int filterValue) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            String headerBits = "00111011";
            int fv = (filterValue < 0 || filterValue > 63) ? 0 : filterValue;

            // Filter Value is encoded into the EPC only (filterBits below).
            // ATA Classification in the USER ToC is a separate field (always 0x01 per spec).
            currentUidConstruct = 2; // Construct 2: Part Number + SER in EPC
            String filterBits = String.format("%6s", Integer.toBinaryString(fv)).replace(' ', '0');

            StringBuilder epcBits = new StringBuilder();
            // Construct 2: Header + Filter + Manager + PartNumber + Delimiter(NUL) + Serial
            // + Terminator(NUL)
            epcBits.append(headerBits).append(filterBits)
                    .append(AtaEncodingUtils.encode6Bit(manager6))
                    .append(AtaEncodingUtils.encode6Bit(partNumber)).append("000000")
                    .append(AtaEncodingUtils.encode6Bit(serialNumber)).append("000000");

            int pad16 = (16 - (epcBits.length() % 16)) % 16;
            for (int i = 0; i < pad16; i++)
                epcBits.append('0');

            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBits.length(); i += 4) {
                epcHex.append(Integer.toHexString(
                        Integer.parseInt(epcBits.substring(i, i + 4), 2)).toUpperCase(Locale.ROOT));
            }
            while ((epcHex.length() & 0x3) != 0)
                epcHex.append('0');

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            boolean ok = reader.writeDataToEpc(pwd, epcHex.toString());
            if (!ok) {
                logWriteErr("programConstruct2Epc writeDataToEpc");
                try {
                    Thread.sleep(60);
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    return false;
                }
                ok = reader.writeDataToEpc(pwd, epcHex.toString());
                if (!ok) {
                    logWriteErr("programConstruct2Epc writeDataToEpc (retry)");
                    return false;
                }
            }
            // Only a read-back-verified EPC counts as written.
            return verifyEpcWrite(reader, epcHex.toString());
        } catch (Exception e) {
            Log.e(TAG, "programConstruct2Epc error", e);
            return false;
        }
    }

    // ==================== USER MEMORY WRITE ====================

    public boolean writeAtaUserMemoryWithPayload(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {
        return writeAtaUserMemoryWithPayload(manufacturer, productName, partNumber,
                serialNumber, manufactureDate, expireDate, null);
    }

    public boolean writeAtaUserMemoryWithPayload(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate,
            java.util.Map<String, String> extraFields) {

        if (UHFManager.getInstance().getReader() == null) {
            Log.e(TAG, "mReader is null; cannot write User Memory!");
            return false;
        }

        currentExtraFields = extraFields; // consumed while building the Birth payload

        String rt = currentRecordType != null ? currentRecordType.toUpperCase(Locale.ROOT) : "DRT";

        if (rt.equals("MRT") || rt.contains("MULTI")) {
            return writeMultiRecordTag(manufacturer, productName, partNumber,
                    serialNumber, manufactureDate, expireDate);
        } else if (rt.equals("DRT") || rt.contains("DUAL")) {
            return writeDualRecordTag(manufacturer, productName, partNumber,
                    serialNumber, manufactureDate, expireDate);
        } else {
            return writeSingleBirthRecordTag(manufacturer, productName, partNumber,
                    serialNumber, manufactureDate, expireDate);
        }
    }

    /**
     * Append optional extra ATA TEIs (from currentExtraFields) to a Birth payload
     * already in "KEY VALUE*KEY VALUE" form. Each TEI is length-validated against the
     * ATA Spec; empty or invalid entries are skipped. This is what makes writing
     * universal (any spec TEI) without changing the common UI fields.
     */
    private String appendExtraTeis(String payloadText) {
        if (currentExtraFields == null || currentExtraFields.isEmpty()) return payloadText;
        StringBuilder sb = new StringBuilder(payloadText);
        for (java.util.Map.Entry<String, String> e : currentExtraFields.entrySet()) {
            String tei = e.getKey() == null ? "" : e.getKey().trim().toUpperCase(Locale.ROOT);
            String val = e.getValue() == null ? "" : e.getValue().trim();
            if (tei.isEmpty() || val.isEmpty()) continue;
            String err = AtaEncodingUtils.validateTeiLength(tei, val);
            if (err != null) {
                Log.w(TAG, "Skipping extra TEI " + tei + ": " + err);
                continue;
            }
            String upper = val.toUpperCase(Locale.ROOT);
            // All chars must be 6-bit encodable, else encode6Bit would throw.
            boolean encodable = true;
            for (int i = 0; i < upper.length(); i++) {
                if (!AtaEncodingUtils.CHAR_TO_6BIT.containsKey(upper.charAt(i))) {
                    encodable = false;
                    break;
                }
            }
            if (!encodable) {
                Log.w(TAG, "Skipping extra TEI " + tei + ": non-6-bit chars in value");
                continue;
            }
            if (sb.length() > 0 && sb.charAt(sb.length() - 1) != '*') sb.append('*');
            sb.append(tei).append(' ').append(upper);
        }
        return sb.toString();
    }

    private boolean writeSingleBirthRecordTag(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            // Build payload (ATA Spec 2000 Table 3 - Single Birth-Record).
            // Order: MFR → SER/SEQ → PNR → PNO → UIC → PDT → DMF → EXP
            // PNR (Current Part Number) is MANDATORY (Table 3 No.3); PNO
            // (Original) is required by Construct 2 (SEQ). At initial encoding
            // current == original, so both carry the same UI value.
            StringBuilder payloadBuilder = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                payloadBuilder.append("*MFR ")
                        .append(manufacturer.length() > 5 ? manufacturer.substring(0, 5) : manufacturer);
            if (serialNumber != null && !serialNumber.isEmpty())
                payloadBuilder.append("*").append(serialTei()).append(" ")
                        .append(serialNumber.length() > 30 ? serialNumber.substring(0, 30) : serialNumber);
            if (partNumber != null && !partNumber.isEmpty()) {
                String pn = partNumber.length() > 32 ? partNumber.substring(0, 32) : partNumber;
                payloadBuilder.append("*PNR ").append(pn); // Current PN (mandatory)
                if (currentUidConstruct == 2)
                    payloadBuilder.append("*PNO ").append(pn); // Original PN (Construct 2)
            }
            payloadBuilder.append("*UIC ").append(currentUidConstruct);
            if (productName != null && !productName.isEmpty())
                payloadBuilder.append("*PDT ")
                        .append(productName.length() > 32 ? productName.substring(0, 32) : productName);
            if (manufactureDate != null && !manufactureDate.isEmpty())
                payloadBuilder.append("*DMF ")
                        .append(manufactureDate.length() > 8 ? manufactureDate.substring(0, 8) : manufactureDate);
            if (expireDate != null && !expireDate.isEmpty())
                payloadBuilder.append("*EXP ")
                        .append(expireDate.length() > 8 ? expireDate.substring(0, 8) : expireDate);

            String ataPayloadText = payloadBuilder.length() > 0 && payloadBuilder.charAt(0) == '*'
                    ? payloadBuilder.substring(1)
                    : payloadBuilder.toString();
            ataPayloadText = appendExtraTeis(ataPayloadText); // optional extra ATA TEIs
            Log.i(TAG, "📝 SRT Birth TEIs: " + ataPayloadText); // audit trail of written fields

            // Encode payload
            StringBuilder payload6bit = new StringBuilder();
            for (char c : ataPayloadText.toCharArray()) {
                String sixBits = AtaEncodingUtils.CHAR_TO_6BIT.get(Character.toUpperCase(c));
                payload6bit.append(sixBits != null ? sixBits : "000000");
            }
            payload6bit.append("000000"); // End delimiter

            int padBits = (16 - (payload6bit.length() % 16)) % 16;
            for (int i = 0; i < padBits; i++)
                payload6bit.append('0');
            int payloadWords = payload6bit.length() / 16;

            // Build header (ATA Spec 2000 Section 3)
            int dsfid = 0x1E00;
            int tagType = AtaEncodingUtils.mapAtaTagType(currentRecordType);
            int dataWords = 4 + payloadWords + 1; // Actual data size

            // Word 1: [15:13]=MinorVer, [12:9]=MajorVer, [8:5]=TagType, [4:0]=Class
            // TagType per ATA Spec 2000: SRT-B=0x2, SRT-U=0xA
            String w0 = String.format("%04X", dsfid);
            int word1 = ((TOC_MINOR_VERSION & 0x7) << 13) | ((TOC_MAJOR_VERSION & 0xF) << 9)
                    | ((tagType & 0xF) << 5) | (ATA_CLASSIFICATION & 0x1F);
            String w1 = String.format("%04X", word1);
            // RDCount=0 for SRT (no Record Descriptors)
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (0 & 0xF);
            String w2 = String.format("%04X", word2);
            // ATA Spec A-4-2: Word 3 = "Size of ATA Memory" = size of the ATA container,
            // where the CRC occupies the LAST word. Using the actual container size (not the
            // chip capacity) keeps the CRC at the spec-required position on ANY chip size.
            int ataMemWords = dataWords;
            String w3 = String.format("%04X", ataMemWords);
            Log.d(TAG, "📝 SRT: ATA Memory (container): " + ataMemWords + " words; chip capacity: "
                    + currentUserWords);

            // Encode payload to hex
            StringBuilder payloadHex = new StringBuilder();
            String bits = payload6bit.toString();
            for (int i = 0; i < bits.length(); i += 4) {
                String chunk = bits.substring(i, Math.min(i + 4, bits.length()));
                payloadHex.append(Integer.toHexString(Integer.parseInt(chunk, 2)).toUpperCase(Locale.ROOT));
            }

            // Calculate CRC
            String dataBeforeCrc = w0 + w1 + w2 + w3 + payloadHex.toString();
            int crc = AtaEncodingUtils.calculateCrc16Ccitt(dataBeforeCrc);
            String crcHex = String.format("%04X", crc);

            String userMemHex = dataBeforeCrc + crcHex;
            Log.i(TAG, "Writing Single Birth-Record: " + dataWords + " words, USER memory: " + currentUserWords
                    + " words");

            // Calculate recommended permalock size for SRT
            // SRT has no Lifecycle/CDR, so we can lock everything
            // For SRT-B: lock entire tag
            // For SRT-U: typically don't lock (utility tags)
            String rtUpper = currentRecordType.toUpperCase(Locale.ROOT);
            if (rtUpper.contains("SRT-U") || rtUpper.contains("UTILITY")) {
                // Utility tags should not be permalocked
                lastCalculatedPermalockWords = 0;
                Log.d(TAG, "📝 SRT-U (Utility): No permalock recommended");
            } else {
                // SRT-B: Lock entire tag (round up to 16-word block boundary)
                int permalockBlocks = (dataWords + 15) / 16;
                lastCalculatedPermalockWords = permalockBlocks * 16;
                Log.d(TAG, "📝 SRT-B: Calculated permalock: " + lastCalculatedPermalockWords + " words (" +
                        permalockBlocks + " blocks) for " + dataWords + " data words");
            }

            // Chip'in USER memory kapasitesini kontrol et
            if (currentUserWords > 0 && dataWords > currentUserWords) {
                Log.e(TAG, "❌ Size exceeds USER memory! Need: " + dataWords + ", Available: " + currentUserWords);
                return false;
            }

            boolean success = writeUserWords(reader, 0, dataWords, userMemHex, "SRT");
            if (success) success = verifyUserWrite(reader, userMemHex, dataWords);
            Log.i(TAG, "Write result: " + (success ? "SUCCESS (verified)" : "FAILED"));

            return success;
        } catch (Exception e) {
            Log.e(TAG, "Error writing Single Birth-Record: " + e.getMessage(), e);
            return false;
        }
    }

    private boolean writeDualRecordTag(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            Log.i(TAG, "📝 DUAL-RECORD: Starting write");

            // Build Birth Record payload (ATA Spec 2000 Table 5).
            // Order: MFR → SER/SEQ → PNR → PNO → UIC → PDT → DMF → EXP
            // PNR (Current Part Number) is MANDATORY (Table 5 No.3); PNO
            // (Original Part Number, No.25) is required by Construct 2 (SEQ,
            // see requirement 4). At initial encoding current == original, so
            // both carry the same UI "Part Number" value.
            StringBuilder birthPayload = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                birthPayload.append("MFR ")
                        .append(manufacturer.length() > 5 ? manufacturer.substring(0, 5) : manufacturer).append("*");
            if (serialNumber != null && !serialNumber.isEmpty())
                birthPayload.append(serialTei()).append(" ")
                        .append(serialNumber.length() > 30 ? serialNumber.substring(0, 30) : serialNumber).append("*");
            if (partNumber != null && !partNumber.isEmpty()) {
                String pn = partNumber.length() > 32 ? partNumber.substring(0, 32) : partNumber;
                birthPayload.append("PNR ").append(pn).append("*"); // Current PN (mandatory)
                if (currentUidConstruct == 2)
                    birthPayload.append("PNO ").append(pn).append("*"); // Original PN (Construct 2)
            }
            birthPayload.append("UIC ").append(currentUidConstruct).append("*");
            if (productName != null && !productName.isEmpty())
                birthPayload.append("PDT ")
                        .append(productName.length() > 32 ? productName.substring(0, 32) : productName).append("*");
            if (manufactureDate != null && !manufactureDate.isEmpty())
                birthPayload.append("DMF ")
                        .append(manufactureDate.length() > 8 ? manufactureDate.substring(0, 8) : manufactureDate)
                        .append("*");
            if (expireDate != null && !expireDate.isEmpty())
                birthPayload.append("EXP ").append(expireDate.length() > 8 ? expireDate.substring(0, 8) : expireDate)
                        .append("*");

            String birthText = birthPayload.length() > 0 && birthPayload.charAt(0) == '*'
                    ? birthPayload.substring(1)
                    : birthPayload.toString();
            birthText = appendExtraTeis(birthText); // optional extra ATA TEIs
            Log.i(TAG, "📝 DRT Birth TEIs: " + birthText); // audit trail of written fields

            String birthBits = AtaEncodingUtils.padToMultiple(
                    AtaEncodingUtils.encode6Bit(birthText) + "000000", 16);
            String birthPayloadHex = AtaEncodingUtils.bitsToHex(birthBits);
            int birthPayloadWords = birthBits.length() / 16;

            // ATA Spec: ToC Header (4) + RDs (4) + Birth = 8 + Birth.
            // Block Permalock locks whole 16-word blocks. Pad the Birth Record so the
            // Lifecycle Record starts exactly on a 16-word block boundary; then
            // permalocking every block up to Birth-end can NEVER overlap the
            // (rewritable) Lifecycle Record. Birth = 2 (header) + payload + 1 (CRC).
            final int birthAddr = 4 + 4; // ToC header + 2 record descriptors
            int lifecycleStartUnpadded = birthAddr + (2 + birthPayloadWords + 1);
            int alignPad = (16 - (lifecycleStartUnpadded % 16)) % 16;
            if (alignPad > 0) {
                birthPayloadHex += AtaEncodingUtils.zeros(alignPad * 4);
                birthPayloadWords += alignPad;
                Log.d(TAG, "📝 Birth padded " + alignPad + " words so Lifecycle is block-aligned at word "
                        + (birthAddr + 2 + birthPayloadWords + 1));
            }

            int birthRecordSize = 2 + birthPayloadWords + 1;
            // Record Header Word 1: Bits[15:8]=RecordType(0x00=Birth),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String birthHeader = String.format("%04X%04X", birthRecordSize, (0x00 << 8) | DR_BD_VERSION);
            String birthDataNoCrc = birthHeader + birthPayloadHex;
            String birthRecordHex = birthDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(birthDataNoCrc));

            // Calculate Lifecycle Record size dynamically based on available USER memory
            // ATA Spec: Lifecycle should have enough space for PNR(32), PML(100), EXP(8),
            // TDN(32), OVD(8) etc.
            // Minimum: 8 words (~26 chars), Recommended: 32+ words (~100+ chars)
            int headerWords = 4;
            int rdWords = 4;
            int birthAddress = headerWords + rdWords;

            // Verify Lifecycle will start at word 16+ (outside Block 0 permalock)
            int expectedLifecycleStart = birthAddress + birthRecordSize;
            Log.d(TAG, "📝 DRT Layout: Birth ends at word " + (expectedLifecycleStart - 1) +
                    ", Lifecycle starts at word " + expectedLifecycleStart +
                    (expectedLifecycleStart >= 16 ? " ✓ (outside Block 0)" : " ⚠️ (in Block 0!)"));
            int trailerWords = 2;

            // Calculate available space for Lifecycle after Birth record
            int usedWords = headerWords + rdWords + birthRecordSize + trailerWords;
            int availableForLifecycle = currentUserWords - usedWords - 3; // -3 for Lifecycle header(2) + CRC(1)

            // Lifecycle payload: use all available space, min 8 words, max based on chip
            // capacity
            int lifecyclePayloadWords = Math.max(8, Math.min(availableForLifecycle, 64)); // Max 64 words (~200 chars)
            int lifecycleRecordSize = 2 + lifecyclePayloadWords + 1;

            Log.d(TAG, "📝 Lifecycle: " + lifecyclePayloadWords + " payload words (~" + (lifecyclePayloadWords * 16 / 6)
                    + " chars capacity)");

            // Record Header Word 1: Bits[15:8]=RecordType(0x04=Lifecycle),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String lifecycleHeader = String.format("%04X%04X", lifecycleRecordSize, (0x04 << 8) | DR_BD_VERSION);

            StringBuilder lifecyclePayloadHex = new StringBuilder();
            for (int i = 0; i < lifecyclePayloadWords * 4; i++)
                lifecyclePayloadHex.append("0");

            String lifecycleDataNoCrc = lifecycleHeader + lifecyclePayloadHex.toString();
            String lifecycleRecordHex = lifecycleDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(lifecycleDataNoCrc));

            // Calculate addresses
            int lifecycleAddress = birthAddress + birthRecordSize;
            int totalWords = lifecycleAddress + lifecycleRecordSize + trailerWords;

            // Build ToC Header (ATA Spec 2000 Section 3)
            // Word 0: DSFID (0x1E = ATA Spec 2000 compliant)
            // Word 1: [15:13]=MinorVer, [12:9]=MajorVer, [8:5]=TagType, [4:0]=Class
            // TagType per ATA Spec 2000: DRT=0x1
            // Word 2: [15:8]=Flags, [7:4]=Size of ToC Header, [3:0]=Size of RDs code
            // (0x02 = 16-bit record addresses; number of records lives in the Trailer)
            String w0 = String.format("%04X", 0x1E00);
            int tagType = AtaEncodingUtils.mapAtaTagType("DRT"); // 0x1 per ATA Spec
            int word1 = ((TOC_MINOR_VERSION & 0x7) << 13) | ((TOC_MAJOR_VERSION & 0xF) << 9)
                    | ((tagType & 0xF) << 5) | (ATA_CLASSIFICATION & 0x1F);
            String w1 = String.format("%04X", word1);
            Log.d(TAG, "📝 DRT ToC: TagType=" + tagType + " (0x" + Integer.toHexString(tagType) +
                    "), Class=" + ATA_CLASSIFICATION);
            // Size of RDs = 0x02 (16-bit record addresses, 2-word RDs)
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (RD_SIZE_CODE_16BIT & 0xF);
            String w2 = String.format("%04X", word2);
            // ATA Spec A-4-3: Word 3 = "Size of ATA Memory" = size of the ATA container,
            // ending at the ToC Trailer's CRC word. Use the actual container size so the
            // Trailer lands at the end of ATA memory regardless of the chip's capacity.
            int ataMemWords = totalWords;
            String w3 = String.format("%04X", ataMemWords);
            Log.d(TAG, "📝 ATA Memory (container): " + ataMemWords + " words; chip capacity: " + currentUserWords);

            // Build Record Descriptors (ATA Spec: Type[15:8] | Flags[7:0])
            // Flags: Bit 0 = 8-bit encoding, Bit 1 = Corrected birth
            // Birth: 6-bit encoding (flag=0), Lifecycle: 6-bit encoding (flag=0)
            int birthRdFlags = 0x00; // 6-bit encoding, not corrected
            int lifecycleRdFlags = 0x00; // 6-bit encoding
            String rd1 = String.format("%04X%04X", lifecycleAddress, (0x04 << 8) | lifecycleRdFlags);
            String rd2 = String.format("%04X%04X", birthAddress, (0x00 << 8) | birthRdFlags);

            // Build Trailer
            String trailerWord1 = String.format("%04X", 2);
            String tocData = w0 + w1 + w2 + w3 + rd1 + rd2 + trailerWord1;
            String trailerWord2 = String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(tocData));

            // Assemble USER memory
            StringBuilder userMemHex = new StringBuilder();
            userMemHex.append(w0).append(w1).append(w2).append(w3);
            userMemHex.append(rd1).append(rd2);
            userMemHex.append(birthRecordHex);
            userMemHex.append(lifecycleRecordHex);
            userMemHex.append(trailerWord1).append(trailerWord2);

            Log.i(TAG, "📝 Total: " + totalWords + " words, USER memory: " + currentUserWords + " words");

            // Calculate recommended permalock size for DRT
            // We want to lock: ToC(4) + RDs(4) + Birth Record
            // But NOT Lifecycle Record (needs to stay writable)
            int protectedWords = headerWords + rdWords + birthRecordSize;
            // Round up to 16-word block boundary (Block Permalock operates on 16-word
            // blocks)
            // Birth was padded so Lifecycle is block-aligned, hence protectedWords is
            // already a multiple of 16 and the lock stops exactly where Lifecycle begins.
            int permalockBlocks = (protectedWords + 15) / 16;
            int calculatedPermalockWords = permalockBlocks * 16;
            lastCalculatedPermalockWords = calculatedPermalockWords;
            Log.d(TAG,
                    "📝 Calculated permalock: " + calculatedPermalockWords + " words (" + permalockBlocks + " blocks)");
            Log.d(TAG, "   Protected area: ToC(4) + RDs(4) + Birth(" + birthRecordSize + ") = " + protectedWords
                    + " words");

            // Önce chip'in USER memory kapasitesini kontrol et
            if (currentUserWords > 0 && totalWords > currentUserWords) {
                Log.e(TAG, "❌ Size exceeds USER memory! Need: " + totalWords + ", Available: " + currentUserWords);
                return false;
            }

            // ATA Spec: DRT max 2 Kbyte = 1024 words
            if (totalWords > 1024) {
                Log.e(TAG, "❌ Size too large: " + totalWords + " words (ATA Spec DRT max 1024)");
                return false;
            }

            // Minimum DRT boyutu kontrolü (ToC Header + 2 RDs + Birth + Lifecycle +
            // Trailer)
            if (totalWords < 20) {
                Log.e(TAG, "❌ Size too small for DRT: " + totalWords + " words (min ~20 required)");
                return false;
            }

            // Write in chunks if needed
            String fullHex = userMemHex.toString();
            final int maxChunkWords = 32;
            boolean success = true;

            if (totalWords > maxChunkWords) {
                int wordsWritten = 0;
                while (wordsWritten < totalWords && success) {
                    int chunkSize = Math.min(maxChunkWords, totalWords - wordsWritten);
                    int hexOffset = wordsWritten * 4;
                    int hexLength = chunkSize * 4;

                    String chunkHex = fullHex.substring(hexOffset, Math.min(hexOffset + hexLength, fullHex.length()));
                    success = writeUserWords(reader, wordsWritten, chunkSize, chunkHex, "DRT chunk");

                    if (!success)
                        break;
                    wordsWritten += chunkSize;
                    try {
                        Thread.sleep(50);
                    } catch (Exception ignored) {
                    }
                }
            } else {
                success = writeUserWords(reader, 0, totalWords, fullHex, "DRT");
            }

            if (success) success = verifyUserWrite(reader, fullHex, totalWords);
            Log.i(TAG, success ? "✅ DUAL-RECORD: Write successful (verified)!"
                    : "❌ DUAL-RECORD: Write failed!");
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error writing Dual-Record: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== MULTI-RECORD TAG (MRT) ====================

    /**
     * Write Multi-Record Tag per ATA Spec 2000 Section 4
     * Structure: ToC Header + RDs + Birth Record + Current Data Record + (optional)
     * Scratchpad + Trailer
     */
    private boolean writeMultiRecordTag(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            Log.i(TAG, "📝 MULTI-RECORD: Starting write");

            // Build Birth Record payload (per Table 8 - preferred order with length
            // validation)
            // Order: MFR → SER → PNO → UIC → PDT → DMF
            StringBuilder birthPayload = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                birthPayload.append("MFR ")
                        .append(manufacturer.length() > 5 ? manufacturer.substring(0, 5) : manufacturer).append("*");
            if (serialNumber != null && !serialNumber.isEmpty())
                birthPayload.append(serialTei()).append(" ")
                        .append(serialNumber.length() > 30 ? serialNumber.substring(0, 30) : serialNumber).append("*");
            if (partNumber != null && !partNumber.isEmpty())
                birthPayload.append("PNO ").append(partNumber.length() > 32 ? partNumber.substring(0, 32) : partNumber)
                        .append("*");
            birthPayload.append("UIC ").append(currentUidConstruct).append("*");
            if (productName != null && !productName.isEmpty())
                birthPayload.append("PDT ")
                        .append(productName.length() > 32 ? productName.substring(0, 32) : productName).append("*");
            if (manufactureDate != null && !manufactureDate.isEmpty())
                birthPayload.append("DMF ")
                        .append(manufactureDate.length() > 8 ? manufactureDate.substring(0, 8) : manufactureDate)
                        .append("*");

            String birthText = birthPayload.toString();
            String birthBits = AtaEncodingUtils.padToMultiple(
                    AtaEncodingUtils.encode6Bit(birthText) + "000000", 16);
            String birthPayloadHex = AtaEncodingUtils.bitsToHex(birthBits);
            int birthPayloadWords = birthBits.length() / 16;

            // ATA Spec: ToC Header (4) + RDs (4) + Birth = 8 + Birth
            // Block Permalock locks 16-word blocks. To keep CDR writable:
            // - Birth Record must end at word 15 or later (so CDR starts at word 16+)
            // - birthAddress = 8, so birthRecordSize needs to be >= 8 words
            int minBirthPayloadWords = 5; // 2 + 5 + 1 = 8 words minimum
            if (birthPayloadWords < minBirthPayloadWords) {
                int padWords = minBirthPayloadWords - birthPayloadWords;
                birthPayloadHex += AtaEncodingUtils.zeros(padWords * 4);
                birthPayloadWords = minBirthPayloadWords;
                Log.d(TAG, "📝 MRT Birth Record padded to " + birthPayloadWords + " payload words (CDR alignment)");
            }

            int birthRecordSize = 2 + birthPayloadWords + 1; // Header + Payload + CRC

            // Build Current Data Record (CDR) payload (per Table 9 - with length
            // validation)
            StringBuilder cdrPayload = new StringBuilder();
            if (partNumber != null && !partNumber.isEmpty())
                cdrPayload.append("PNR ").append(partNumber.length() > 32 ? partNumber.substring(0, 32) : partNumber)
                        .append("*");
            if (expireDate != null && !expireDate.isEmpty())
                cdrPayload.append("EXP ").append(expireDate.length() > 8 ? expireDate.substring(0, 8) : expireDate)
                        .append("*");
            cdrPayload.append("CND SRV*"); // Condition: Serviceable

            String cdrText = cdrPayload.toString();
            String cdrBits = AtaEncodingUtils.padToMultiple(
                    AtaEncodingUtils.encode6Bit(cdrText) + "000000", 16);
            String cdrPayloadHex = AtaEncodingUtils.bitsToHex(cdrBits);
            int cdrPayloadWords = cdrBits.length() / 16;
            int cdrRecordSize = 2 + cdrPayloadWords + 1;

            // Calculate addresses
            int headerWords = 4;
            int rdWords = 2 * 2; // 2 Record Descriptors × 2 words each
            int birthAddress = headerWords + rdWords;
            int cdrAddress = birthAddress + birthRecordSize;
            int trailerWords = 2;
            int totalWords = cdrAddress + cdrRecordSize + trailerWords;

            // Verify CDR will start at word 16+ (outside Block 0 permalock)
            Log.d(TAG, "📝 MRT Layout: Birth ends at word " + (cdrAddress - 1) +
                    ", CDR starts at word " + cdrAddress +
                    (cdrAddress >= 16 ? " ✓ (outside Block 0)" : " ⚠️ (in Block 0!)"));

            // Build ToC Header (per ATA Spec Figure 53)
            String w0 = String.format("%04X", 0x1E00); // DSFID
            // Word 1: [ToC Minor:3][ToC Major:4][ATA Tag Type:4][ATA Class:5]
            // TagType per ATA Spec 2000: MRT=0x0
            int tagType = AtaEncodingUtils.mapAtaTagType("MRT"); // 0x0 per ATA Spec
            int word1 = ((TOC_MINOR_VERSION & 0x7) << 13) | ((TOC_MAJOR_VERSION & 0xF) << 9)
                    | ((tagType & 0xF) << 5) | (ATA_CLASSIFICATION & 0x1F);
            String w1 = String.format("%04X", word1);
            Log.d(TAG, "📝 MRT ToC: Class=" + ATA_CLASSIFICATION + " (ATA Spec: fixed 0x01)");
            // Word 2: [Flags:8][Size of ToC Header:4][Size of RDs code:4]
            // (0x02 = 16-bit record addresses; record count lives in the Trailer)
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (RD_SIZE_CODE_16BIT & 0xF);
            String w2 = String.format("%04X", word2);
            // ATA Spec A-4-3: Word 3 = "Size of ATA Memory" = size of the ATA container,
            // whose LAST word is the ToC Trailer CRC and penultimate word is the record
            // count (spec: trailer stored at the end of ATA memory). Must be the container
            // size (totalWords), NOT the chip capacity — otherwise the reader looks for the
            // trailer at chipCapacity-2/-1 and reads unwritten memory. Matches DRT/SRT.
            int ataMemWords = totalWords;
            String w3 = String.format("%04X", ataMemWords);
            Log.d(TAG, "📝 MRT: ATA Memory (container): " + ataMemWords + " words; chip capacity: "
                    + currentUserWords);

            // Build Record Descriptors (CDR first, then Birth - per ATA Spec ordering)
            // RD Flags: Bit 0 = 8-bit encoding, Bit 1 = Corrected birth
            String rd1 = String.format("%04X%04X", cdrAddress, (0x01 << 8) | 0x00); // Type 0x01 = CDR
            String rd2 = String.format("%04X%04X", birthAddress, (0x00 << 8) | 0x00); // Type 0x00 = Birth

            // Build Birth Record with header and CRC
            // Record Header Word 1: Bits[15:8]=RecordType(0x00=Birth),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String birthHeader = String.format("%04X%04X", birthRecordSize, (0x00 << 8) | DR_BD_VERSION);
            String birthDataNoCrc = birthHeader + birthPayloadHex;
            String birthRecordHex = birthDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(birthDataNoCrc));

            // Build CDR with header and CRC
            // Record Header Word 1: Bits[15:8]=RecordType(0x01=CDR),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String cdrHeader = String.format("%04X%04X", cdrRecordSize, (0x01 << 8) | DR_BD_VERSION);
            String cdrDataNoCrc = cdrHeader + cdrPayloadHex;
            String cdrRecordHex = cdrDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(cdrDataNoCrc));

            // Build Trailer
            String trailerWord1 = String.format("%04X", 2); // Number of records
            String tocData = w0 + w1 + w2 + w3 + rd1 + rd2 + trailerWord1;
            String trailerWord2 = String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(tocData));

            // Assemble USER memory
            StringBuilder userMemHex = new StringBuilder();
            userMemHex.append(w0).append(w1).append(w2).append(w3);
            userMemHex.append(rd1).append(rd2);
            userMemHex.append(birthRecordHex);
            userMemHex.append(cdrRecordHex);
            userMemHex.append(trailerWord1).append(trailerWord2);

            Log.i(TAG, "📝 MRT Total: " + totalWords + " words, USER memory: " + currentUserWords + " words");

            // Calculate recommended permalock size for MRT
            // We want to lock: ToC(4) + RDs(4) + Birth Record
            // But NOT CDR (Current Data Record - needs to stay writable)
            int protectedWords = headerWords + rdWords + birthRecordSize;
            // Round up to 16-word block boundary (Block Permalock operates on 16-word
            // blocks)
            int permalockBlocks = (protectedWords + 15) / 16;
            int calculatedPermalockWords = permalockBlocks * 16;

            // For MRT, cap at Block 0 (16 words) to keep CDR writable
            if (calculatedPermalockWords > 16 && cdrAddress < calculatedPermalockWords) {
                Log.w(TAG,
                        "⚠️ Birth Record extends into Block 1 (ends at word " + (birthAddress + birthRecordSize - 1) +
                                "), capping permalock at 16 words to keep CDR writable");
                calculatedPermalockWords = 16;
            }
            lastCalculatedPermalockWords = calculatedPermalockWords;
            Log.d(TAG, "📝 MRT: Calculated permalock: " + calculatedPermalockWords + " words (" + permalockBlocks
                    + " blocks)");
            Log.d(TAG, "   Protected area: ToC(4) + RDs(4) + Birth(" + birthRecordSize + ") = " + protectedWords
                    + " words");

            // Validate size
            if (currentUserWords > 0 && totalWords > currentUserWords) {
                Log.e(TAG, "❌ Size exceeds USER memory! Need: " + totalWords + ", Available: " + currentUserWords);
                return false;
            }

            // ATA Spec: MRT requires 8k bytes+ = 4096+ words ideally
            if (totalWords < 40) {
                Log.w(TAG, "⚠️ MRT size is small: " + totalWords + " words (ATA Spec recommends 4096+)");
            }

            // Write in chunks
            String fullHex = userMemHex.toString();
            final int maxChunkWords = 32;
            boolean success = true;

            if (totalWords > maxChunkWords) {
                int wordsWritten = 0;
                while (wordsWritten < totalWords && success) {
                    int chunkSize = Math.min(maxChunkWords, totalWords - wordsWritten);
                    int hexOffset = wordsWritten * 4;
                    int hexLength = chunkSize * 4;

                    String chunkHex = fullHex.substring(hexOffset, Math.min(hexOffset + hexLength, fullHex.length()));
                    success = writeUserWords(reader, wordsWritten, chunkSize, chunkHex, "MRT chunk");

                    if (!success)
                        break;
                    wordsWritten += chunkSize;
                    try {
                        Thread.sleep(50);
                    } catch (Exception ignored) {
                    }
                }
            } else {
                success = writeUserWords(reader, 0, totalWords, fullHex, "MRT");
            }

            if (success) success = verifyUserWrite(reader, fullHex, totalWords);
            Log.i(TAG, success ? "✅ MULTI-RECORD: Write successful (verified)!"
                    : "❌ MULTI-RECORD: Write failed!");
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error writing Multi-Record: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== SCRATCHPAD WRITE (MRT) ====================

    /**
     * Write to User Scratchpad Record (MRT only) per ATA Spec Section 4.3
     * Scratchpad uses 8-bit ASCII encoding
     * 
     * @param epcHex        Target tag EPC
     * @param actionCompany CAGE code (5 chars)
     * @param actionDate    Date YYYYMMDD
     * @param remarks       Free text (up to 344 chars)
     */
    public boolean writeScratchpadEntry(String epcHex, String actionCompany,
            String actionDate, String remarks) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            Log.i(TAG, "📝 SCRATCHPAD: Writing entry for EPC: " + epcHex);

            // Validate inputs per ATA Spec Table 10
            if (actionCompany == null || actionCompany.length() != 5) {
                Log.e(TAG, "❌ ACO must be exactly 5 characters");
                return false;
            }
            if (actionDate == null || actionDate.length() != 8) {
                Log.e(TAG, "❌ ACD must be YYYYMMDD (8 characters)");
                return false;
            }
            if (remarks != null && remarks.length() > 344) {
                Log.e(TAG, "❌ REM must be max 344 characters");
                return false;
            }

            // Build Scratchpad entry: ACO__*ACD________*REM______* (8-bit ASCII)
            StringBuilder scratchEntry = new StringBuilder();
            scratchEntry.append("ACO ").append(actionCompany).append("*");
            scratchEntry.append("ACD ").append(actionDate).append("*");
            if (remarks != null && !remarks.isEmpty()) {
                scratchEntry.append("REM ").append(remarks).append("*");
            }

            // Encode as 8-bit ASCII hex
            String scratchHex = AtaEncodingUtils.encode8BitAscii(scratchEntry.toString());

            Log.i(TAG, "📝 SCRATCHPAD: Entry size = " + (scratchHex.length() / 2) + " bytes");

            // [PENDING] Read existing USER memory to find Scratchpad record location
            // Implementation needs to:
            // 1. Read ToC to find Scratchpad RD
            // 2. Read existing Scratchpad record
            // 3. Append or replace entries as needed

            Log.w(TAG, "⚠️ SCRATCHPAD: Full implementation pending - needs RD lookup");
            return false;

        } catch (Exception e) {
            Log.e(TAG, "Error writing Scratchpad: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== CURRENT DATA RECORD UPDATE (MRT) ====================

    /**
     * Update Current Data Record (CDR) for MRT tags per ATA Spec Section 4.2
     */
    public boolean updateCurrentDataRecord(String epcHex, String currentPartNumber,
            String partModLevel, String expirationDate, String conditionCode) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            Log.i(TAG, "📝 CDR-UPDATE: Starting for EPC: " + epcHex);

            String existingUserHex = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 128);
            if (existingUserHex == null || existingUserHex.length() < 16) {
                Log.e(TAG, "❌ Failed to read existing USER memory");
                return false;
            }

            if (!existingUserHex.substring(0, 4).equals("1E00")) {
                Log.e(TAG, "❌ Not an ATA tag (DSFID != 0x1E00)");
                return false;
            }

            // ATA Spec 2000: MRT = TagType 0x0
            int w1 = Integer.parseInt(existingUserHex.substring(4, 8), 16);
            int tagType = (w1 >> 5) & 0xF;
            if (tagType != 0x0) {
                Log.e(TAG, "❌ Not a Multi-Record tag (TagType=" + tagType + ", expected 0x0)");
                Log.e(TAG, "   ATA Spec 2000 TagTypes: MRT=0x0, DRT=0x1, SRT-B=0x2, SRT-U=0xA");
                return false;
            }
            Log.d(TAG, "📝 MRT verified: TagType=0x0");

            // Find CDR address from RD #1
            int cdrAddr = Integer.parseInt(existingUserHex.substring(16, 20), 16);
            int cdrType = (Integer.parseInt(existingUserHex.substring(20, 24), 16) >> 8) & 0xFF;

            if (cdrType != 0x01) {
                Log.e(TAG, "❌ RD #1 is not CDR (type=" + cdrType + ")");
                return false;
            }

            int cdrRecordOffset = cdrAddr * 4;
            int cdrRecordSize = Integer.parseInt(
                    existingUserHex.substring(cdrRecordOffset, cdrRecordOffset + 4), 16);

            // Physical-capacity guard (see updateLifecycleRecord): reject if the
            // CDR would run past the tag's real USER capacity.
            int cdrEndWord = cdrAddr + cdrRecordSize;
            int cdrCapacityWords = SDKMethods.reader.MemoryReader.getInstance()
                    .probeUserCapacityWords(epcHex == null ? "" : epcHex);
            if (cdrCapacityWords > 0 && cdrEndWord > cdrCapacityWords) {
                Log.e(TAG, "❌ CDR ends at word " + cdrEndWord
                        + " but tag USER capacity is only " + cdrCapacityWords + " words");
                return false;
            }

            // Build new CDR payload (per Table 9 - with length validation)
            StringBuilder cdrPayload = new StringBuilder();
            if (currentPartNumber != null && !currentPartNumber.isEmpty())
                cdrPayload.append("PNR ").append(
                        currentPartNumber.length() > 32 ? currentPartNumber.substring(0, 32) : currentPartNumber)
                        .append("*");
            if (partModLevel != null && !partModLevel.isEmpty())
                cdrPayload.append("PML ")
                        .append(partModLevel.length() > 100 ? partModLevel.substring(0, 100) : partModLevel)
                        .append("*");
            if (expirationDate != null && !expirationDate.isEmpty())
                cdrPayload.append("EXP ")
                        .append(expirationDate.length() > 8 ? expirationDate.substring(0, 8) : expirationDate)
                        .append("*");
            if (conditionCode != null && !conditionCode.isEmpty())
                cdrPayload.append("CND ")
                        .append(conditionCode.length() > 3 ? conditionCode.substring(0, 3) : conditionCode).append("*");

            String cdrText = cdrPayload.toString();
            String cdrBits = AtaEncodingUtils.encode6Bit(cdrText) + "000000";

            int payloadWords = cdrRecordSize - 3;
            int requiredBits = payloadWords * 16;
            if (cdrBits.length() > requiredBits) {
                Log.e(TAG, "❌ CDR Payload too large!");
                return false;
            }
            cdrBits += AtaEncodingUtils.zeros(requiredBits - cdrBits.length());

            String cdrPayloadHex = AtaEncodingUtils.bitsToHex(cdrBits);

            // Record Header Word 1: Bits[15:8]=RecordType(0x01=CDR),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String cdrHeader = String.format("%04X%04X", cdrRecordSize, (0x01 << 8) | DR_BD_VERSION);
            String cdrDataNoCrc = cdrHeader + cdrPayloadHex;
            String newCdrRecordHex = cdrDataNoCrc +
                    String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(cdrDataNoCrc));

            boolean success = writeUserWords(reader, cdrAddr, cdrRecordSize, newCdrRecordHex, "CDR");
            // Read-back verify the rewritten CDR (same guard as Birth/DRT/MRT).
            if (success) {
                success = verifyUserWrite(reader, newCdrRecordHex, cdrRecordSize, cdrAddr);
            }
            Log.i(TAG, success ? "✅ CDR-UPDATE: Success (verified)!" : "❌ CDR-UPDATE: Failed!");

            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error updating CDR: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== LIFECYCLE UPDATE ====================

    public boolean updateLifecycleRecord(String epcHex, String currentPartNumber,
            String partModLevel, String expirationDate, String certificateNumber,
            String lastOverhaulDate, String hydrostaticTestDate, String conditionCode) {

        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null)
            return false;

        try {
            Log.i(TAG, "📝 LIFECYCLE-UPDATE: Starting for EPC: " + epcHex);

            String existingUserHex = reader.readData("00000000", RFIDWithUHFUART.Bank_USER, 0, 128);
            if (existingUserHex == null || existingUserHex.length() < 16) {
                Log.e(TAG, "❌ Failed to read existing USER memory");
                return false;
            }

            if (!existingUserHex.substring(0, 4).equals("1E00")) {
                Log.e(TAG, "❌ Not an ATA tag (DSFID != 0x1E00)");
                return false;
            }

            // Word 1: [15:13]=MinorVer, [12:9]=MajorVer, [8:5]=TagType, [4:0]=Class
            int w1 = Integer.parseInt(existingUserHex.substring(4, 8), 16);
            int tagType = (w1 >> 5) & 0xF;

            // Word 2: [15:8]=LockFlags, [7:4]=AddrMode, [3:0]=RDCount
            int w2 = Integer.parseInt(existingUserHex.substring(8, 12), 16);
            int rdCount = w2 & 0xF;

            Log.d(TAG, "📝 Tag info: Word1=0x" + existingUserHex.substring(4, 8) +
                    ", TagType=" + tagType + " (0x" + Integer.toHexString(tagType) +
                    "), RDCount=" + rdCount);

            // ATA Spec 2000: DRT = TagType 0x1 with 2 RDs (Birth + Lifecycle)
            // TagType values per spec: MRT=0x0, DRT=0x1, SRT-B=0x2, SRT-U=0xA
            if (tagType != 0x1) {
                // Check if it's an old-style tag (TagType=0 with 2 RDs)
                if (tagType == 0x0 && rdCount >= 2) {
                    Log.w(TAG, "⚠️ Old-style DRT detected (TagType=0 with RDCount=" + rdCount + ")");
                    Log.w(TAG, "   Tag was written before ATA Spec TagType fix. Consider rewriting.");
                    // Allow old-style tags to be updated
                } else {
                    Log.e(TAG, "❌ Not a Dual-Record tag (TagType=" + tagType + ", expected 0x1)");
                    Log.e(TAG, "   ATA Spec 2000 TagTypes: MRT=0x0, DRT=0x1, SRT-B=0x2, SRT-U=0xA");
                    Log.e(TAG, "   Word1 hex: " + existingUserHex.substring(4, 8));
                    return false;
                }
            }

            if (rdCount < 2) {
                Log.e(TAG, "❌ DRT requires 2 Record Descriptors (Birth + Lifecycle), found " + rdCount);
                return false;
            }

            Log.d(TAG, "📝 DRT verified: TagType=0x1, RDCount=" + rdCount);

            // Find Lifecycle Record Descriptor
            // RDs start at word 4, each RD is 2 words (address + flags)
            // RD order per ATA Spec: we need to find the one with Type=0x04 (Lifecycle)
            int lifecycleAddr = -1;
            int lifecycleRdIndex = -1;

            for (int rdIdx = 0; rdIdx < rdCount; rdIdx++) {
                int rdOffset = 16 + (rdIdx * 8); // Word 4 + rdIdx * 2 words, each word = 4 hex chars
                if (rdOffset + 8 > existingUserHex.length())
                    break;

                int rdAddress = Integer.parseInt(existingUserHex.substring(rdOffset, rdOffset + 4), 16);
                int rdFlags = Integer.parseInt(existingUserHex.substring(rdOffset + 4, rdOffset + 8), 16);
                int rdType = (rdFlags >> 8) & 0xFF;

                Log.d(TAG, "📝 RD[" + rdIdx + "]: addr=" + rdAddress + ", type=0x" + Integer.toHexString(rdType));

                if (rdType == 0x04) { // Lifecycle Record
                    lifecycleAddr = rdAddress;
                    lifecycleRdIndex = rdIdx;
                    break;
                }
            }

            if (lifecycleAddr < 0) {
                Log.e(TAG, "❌ No Lifecycle Record found in RDs");
                return false;
            }

            Log.d(TAG, "📝 Found Lifecycle at RD[" + lifecycleRdIndex + "], address=" + lifecycleAddr);

            int lifecycleRecordOffset = lifecycleAddr * 4;

            // Bounds check
            if (lifecycleRecordOffset + 4 > existingUserHex.length()) {
                Log.e(TAG, "❌ Lifecycle offset out of bounds: " + lifecycleRecordOffset + " > "
                        + existingUserHex.length());
                return false;
            }

            int lifecycleRecordSize = Integer.parseInt(
                    existingUserHex.substring(lifecycleRecordOffset, lifecycleRecordOffset + 4), 16);

            Log.d(TAG, "📝 Lifecycle addr=" + lifecycleAddr + ", size=" + lifecycleRecordSize + " words");

            // Physical-capacity guard: confirm the tag actually holds the words
            // we're about to rewrite. The record was allocated at first write,
            // but probe the real chip capacity (same as the Tag Writer) so a
            // smaller/swapped tag is rejected cleanly instead of a silent
            // partial write past the end of memory.
            int lifecycleEndWord = lifecycleAddr + lifecycleRecordSize;
            int capacityWords = SDKMethods.reader.MemoryReader.getInstance()
                    .probeUserCapacityWords(epcHex == null ? "" : epcHex);
            if (capacityWords > 0 && lifecycleEndWord > capacityWords) {
                Log.e(TAG, "❌ Lifecycle record ends at word " + lifecycleEndWord
                        + " but tag USER capacity is only " + capacityWords + " words");
                return false;
            }

            // Build new Lifecycle payload (with length validation per ATA Spec Table 6)
            StringBuilder lifecyclePayload = new StringBuilder();
            if (currentPartNumber != null && !currentPartNumber.isEmpty())
                lifecyclePayload.append("PNR ").append(
                        currentPartNumber.length() > 32 ? currentPartNumber.substring(0, 32) : currentPartNumber)
                        .append("*");
            if (partModLevel != null && !partModLevel.isEmpty())
                lifecyclePayload.append("PML ")
                        .append(partModLevel.length() > 100 ? partModLevel.substring(0, 100) : partModLevel)
                        .append("*");
            if (expirationDate != null && !expirationDate.isEmpty())
                lifecyclePayload.append("EXP ")
                        .append(expirationDate.length() > 8 ? expirationDate.substring(0, 8) : expirationDate)
                        .append("*");
            if (certificateNumber != null && !certificateNumber.isEmpty())
                lifecyclePayload.append("TDN ").append(
                        certificateNumber.length() > 32 ? certificateNumber.substring(0, 32) : certificateNumber)
                        .append("*");
            if (lastOverhaulDate != null && !lastOverhaulDate.isEmpty())
                lifecyclePayload.append("OVD ")
                        .append(lastOverhaulDate.length() > 8 ? lastOverhaulDate.substring(0, 8) : lastOverhaulDate)
                        .append("*");
            if (hydrostaticTestDate != null && !hydrostaticTestDate.isEmpty())
                lifecyclePayload.append("DOH ").append(
                        hydrostaticTestDate.length() > 8 ? hydrostaticTestDate.substring(0, 8) : hydrostaticTestDate)
                        .append("*");
            if (conditionCode != null && !conditionCode.isEmpty())
                lifecyclePayload.append("CND ")
                        .append(conditionCode.length() > 3 ? conditionCode.substring(0, 3) : conditionCode)
                        .append("*");

            String lifecycleText = lifecyclePayload.length() > 0 && lifecyclePayload.charAt(0) == '*'
                    ? lifecyclePayload.substring(1)
                    : lifecyclePayload.toString();

            String lifecycleBits = AtaEncodingUtils.encode6Bit(lifecycleText) + "000000";

            int payloadWords = lifecycleRecordSize - 3;
            int requiredBits = payloadWords * 16;
            if (lifecycleBits.length() > requiredBits) {
                Log.e(TAG, "❌ Payload too large!");
                return false;
            }
            lifecycleBits += AtaEncodingUtils.zeros(requiredBits - lifecycleBits.length());

            String lifecyclePayloadHex = AtaEncodingUtils.bitsToHex(lifecycleBits);

            // Record Header Word 1: Bits[15:8]=RecordType(0x04=Lifecycle),
            // Bits[7:5]=DR Version(1), Bits[4:0]=BD Version(3) => 0x23 (ATA Table 17)
            String lifecycleHeader = String.format("%04X%04X", lifecycleRecordSize, (0x04 << 8) | DR_BD_VERSION);
            String lifecycleDataNoCrc = lifecycleHeader + lifecyclePayloadHex;
            String newLifecycleRecordHex = lifecycleDataNoCrc +
                    String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(lifecycleDataNoCrc));

            Log.d(TAG, "📝 Writing " + lifecycleRecordSize + " words at address " + lifecycleAddr);

            // Write in chunks if record is large (SDK may have write limits)
            boolean success;
            final int maxChunkWords = 32;

            if (lifecycleRecordSize > maxChunkWords) {
                success = true;
                int wordsWritten = 0;
                while (wordsWritten < lifecycleRecordSize && success) {
                    int chunkSize = Math.min(maxChunkWords, lifecycleRecordSize - wordsWritten);
                    int hexOffset = wordsWritten * 4;
                    int hexLength = chunkSize * 4;

                    String chunkHex = newLifecycleRecordHex.substring(hexOffset,
                            Math.min(hexOffset + hexLength, newLifecycleRecordHex.length()));

                    success = writeUserWords(reader, lifecycleAddr + wordsWritten, chunkSize,
                            chunkHex, "LIFECYCLE chunk");
                    Log.d(TAG, "📝 Chunk write: addr=" + (lifecycleAddr + wordsWritten) +
                            ", size=" + chunkSize + ", result=" + success);

                    if (!success)
                        break;
                    wordsWritten += chunkSize;
                    try {
                        Thread.sleep(30);
                    } catch (Exception ignored) {
                    }
                }
            } else {
                success = writeUserWords(reader, lifecycleAddr, lifecycleRecordSize,
                        newLifecycleRecordHex, "LIFECYCLE");
            }

            // Read-back verify the rewritten Lifecycle record (SDK write booleans
            // aren't trustworthy on this hardware — same guard as Birth/DRT/MRT).
            if (success) {
                success = verifyUserWrite(reader, newLifecycleRecordHex,
                        lifecycleRecordSize, lifecycleAddr);
            }
            Log.i(TAG, success ? "✅ LIFECYCLE-UPDATE: Success (verified)!"
                    : "❌ LIFECYCLE-UPDATE: Failed!");

            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error updating Lifecycle: " + e.getMessage(), e);
            return false;
        }
    }
}
