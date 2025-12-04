package SDKMethods.writer;

import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;

import java.util.Locale;

import SDKMethods.ata.AtaEncodingUtils;
import SDKMethods.core.UHFManager;

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

    private MemoryWriter() {}

    public static synchronized MemoryWriter getInstance() {
        if (instance == null) {
            instance = new MemoryWriter();
        }
        return instance;
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
        
        return true;
    }
    
    // ==================== MEMORY LOCKING (ATA Spec 2000) ====================
    
    /**
     * Lock USER memory using SDK lockMem function
     * Per ATA Spec 2000: Birth Record should be permalocked after writing
     * 
     * @param accessPwdHex Access password (8 hex chars, default "00000000")
     * @param lockMode Lock mode: 
     *                 LockMode_LOCK (reversible with password)
     *                 LockMode_PLOCK (permanent, irreversible!)
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
        if (reader == null) return false;
        
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
     * @param startWord Start word address in USER memory
     * @param wordCount Number of words to permalock
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
            
            // Create mask for blocks to lock (1 bit per block)
            byte[] mask = new byte[(blockCount + 7) / 8];
            for (int i = 0; i < blockCount; i++) {
                int byteIdx = i / 8;
                int bitIdx = i % 8;
                mask[byteIdx] |= (1 << bitIdx);
            }
            
            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            
            // uhfBlockPermalock parameters:
            // accessPwd, FilterBank, FilterStartaddr, FilterLen, FilterData, 
            // ReadLock (0=write, 1=read), BlockPtr, BlockRange, MaskLen, Mask
            boolean success = reader.uhfBlockPermalock(
                pwd,
                0, 0, 0, null,  // No filter
                0,              // Write mode (0=permalock, 1=read status)
                startBlock,     // Block pointer
                blockCount,     // Block range
                blockCount,     // Mask length
                mask            // Mask data
            );
            
            if (success) {
                Log.i(TAG, "✅ PERMALOCK: Successfully locked " + blockCount + " blocks");
            } else {
                Log.e(TAG, "❌ PERMALOCK: Failed to lock blocks");
            }
            
            return success;
            
        } catch (Exception e) {
            Log.e(TAG, "Error in permalockUserBlocks: " + e.getMessage(), e);
            return false;
        }
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
            for (int i = 0; i < padBits; i++) epcBin.append('0');

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

    public boolean programConstruct2Epc(String partNumber, String serialNumber,
            String manager6, String accessPwdHex, int filterValue) {
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
        try {
            String headerBits = "00111011";
            int fv = (filterValue < 0 || filterValue > 63) ? 0 : filterValue;
            String filterBits = String.format("%6s", Integer.toBinaryString(fv)).replace(' ', '0');

            StringBuilder epcBits = new StringBuilder();
            epcBits.append(headerBits).append(filterBits)
                    .append(AtaEncodingUtils.encode6Bit(manager6))
                    .append(AtaEncodingUtils.encode6Bit(partNumber)).append("000000")
                    .append(AtaEncodingUtils.encode6Bit(serialNumber)).append("000000");

            int pad16 = (16 - (epcBits.length() % 16)) % 16;
            for (int i = 0; i < pad16; i++) epcBits.append('0');

            StringBuilder epcHex = new StringBuilder();
            for (int i = 0; i < epcBits.length(); i += 4) {
                epcHex.append(Integer.toHexString(
                        Integer.parseInt(epcBits.substring(i, i + 4), 2)).toUpperCase(Locale.ROOT));
            }
            while ((epcHex.length() & 0x3) != 0) epcHex.append('0');

            String pwd = (accessPwdHex == null || accessPwdHex.isEmpty()) ? "00000000" : accessPwdHex;
            return reader.writeDataToEpc(pwd, epcHex.toString());
        } catch (Exception e) {
            Log.e(TAG, "programConstruct2Epc error", e);
            return false;
        }
    }

    // ==================== USER MEMORY WRITE ====================

    public boolean writeAtaUserMemoryWithPayload(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {
        
        if (UHFManager.getInstance().getReader() == null) {
            Log.e(TAG, "mReader is null; cannot write User Memory!");
            return false;
        }

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

    private boolean writeSingleBirthRecordTag(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
        try {
            // Build payload
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
            if (expireDate != null && !expireDate.isEmpty())
                payloadBuilder.append("*EXP ").append(expireDate);
            payloadBuilder.append("*UIC 2");

            String ataPayloadText = payloadBuilder.length() > 0 && payloadBuilder.charAt(0) == '*'
                    ? payloadBuilder.substring(1) : payloadBuilder.toString();

            // Encode payload
            StringBuilder payload6bit = new StringBuilder();
            for (char c : ataPayloadText.toCharArray()) {
                String sixBits = AtaEncodingUtils.CHAR_TO_6BIT.get(Character.toUpperCase(c));
                payload6bit.append(sixBits != null ? sixBits : "000000");
            }
            payload6bit.append("000000"); // End delimiter

            int padBits = (16 - (payload6bit.length() % 16)) % 16;
            for (int i = 0; i < padBits; i++) payload6bit.append('0');
            int payloadWords = payload6bit.length() / 16;

            // Build header
            int dsfid = 0x1E00;
            int tagType = AtaEncodingUtils.mapAtaTagType(currentRecordType);
            int userMemWords = 4 + payloadWords + 1;

            String w0 = String.format("%04X", dsfid);
            int word1 = ((2 & 0x7) << 13) | ((4 & 0xF) << 9) | ((tagType & 0xF) << 5) | (1 & 0x1F);
            String w1 = String.format("%04X", word1);
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (0 & 0xF);
            String w2 = String.format("%04X", word2);
            String w3 = String.format("%04X", userMemWords);

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
            Log.i(TAG, "Writing Single Birth-Record: " + userMemWords + " words, USER memory: " + currentUserWords + " words");

            // Chip'in USER memory kapasitesini kontrol et
            if (currentUserWords > 0 && userMemWords > currentUserWords) {
                Log.e(TAG, "❌ Size exceeds USER memory! Need: " + userMemWords + ", Available: " + currentUserWords);
                return false;
            }

            boolean success = reader.writeData("00000000", 3, 0, userMemWords, userMemHex);
            Log.i(TAG, "Write result: " + (success ? "SUCCESS" : "FAILED"));
            
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
        if (reader == null) return false;
        
        try {
            Log.i(TAG, "📝 DUAL-RECORD: Starting write");

            // Build Birth Record payload
            StringBuilder birthPayload = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                birthPayload.append("MFR ").append(manufacturer).append("*");
            if (serialNumber != null && !serialNumber.isEmpty())
                birthPayload.append("SER ").append(serialNumber).append("*");
            if (partNumber != null && !partNumber.isEmpty())
                birthPayload.append("PNR ").append(partNumber).append("*");
            birthPayload.append("UIC 1*");
            if (manufactureDate != null && !manufactureDate.isEmpty())
                birthPayload.append("DMF ").append(manufactureDate).append("*");
            if (expireDate != null && !expireDate.isEmpty())
                birthPayload.append("EXP ").append(expireDate).append("*");
            if (productName != null && !productName.isEmpty())
                birthPayload.append("PDT ").append(productName).append("*");

            String birthText = birthPayload.length() > 0 && birthPayload.charAt(0) == '*'
                    ? birthPayload.substring(1) : birthPayload.toString();

            String birthBits = AtaEncodingUtils.encode6Bit(birthText) + "000000";
            int birthPadBits = (16 - (birthBits.length() % 16)) % 16;
            for (int i = 0; i < birthPadBits; i++) birthBits += '0';
            String birthPayloadHex = AtaEncodingUtils.bitsToHex(birthBits);
            int birthPayloadWords = birthBits.length() / 16;

            int birthRecordSize = 2 + birthPayloadWords + 1;
            String birthHeader = String.format("%04X%04X", birthRecordSize, (0x00 << 8) | (1 << 5) | 3);
            String birthDataNoCrc = birthHeader + birthPayloadHex;
            String birthRecordHex = birthDataNoCrc + String.format("%04X", 
                    AtaEncodingUtils.calculateCrc16Ccitt(birthDataNoCrc));

            // Build empty Lifecycle Record
            int lifecyclePayloadWords = 8;
            int lifecycleRecordSize = 2 + lifecyclePayloadWords + 1;
            String lifecycleHeader = String.format("%04X%04X", lifecycleRecordSize, (0x04 << 8) | (1 << 5) | 3);
            
            StringBuilder lifecyclePayloadHex = new StringBuilder();
            for (int i = 0; i < lifecyclePayloadWords * 4; i++) lifecyclePayloadHex.append("0");
            
            String lifecycleDataNoCrc = lifecycleHeader + lifecyclePayloadHex.toString();
            String lifecycleRecordHex = lifecycleDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(lifecycleDataNoCrc));

            // Calculate addresses
            int headerWords = 4;
            int rdWords = 4;
            int birthAddress = headerWords + rdWords;
            int lifecycleAddress = birthAddress + birthRecordSize;
            int trailerWords = 2;
            int totalWords = lifecycleAddress + lifecycleRecordSize + trailerWords;

            // Build ToC Header
            String w0 = String.format("%04X", 0x1E00);
            int word1 = ((2 & 0x7) << 13) | ((4 & 0xF) << 9) | ((0x0001 & 0xF) << 5) | (1 & 0x1F);
            String w1 = String.format("%04X", word1);
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (2 & 0xF);
            String w2 = String.format("%04X", word2);
            String w3 = String.format("%04X", totalWords);

            // Build Record Descriptors (ATA Spec: Type[15:8] | Flags[7:0])
            // Flags: Bit 0 = 8-bit encoding, Bit 1 = Corrected birth
            // Birth: 6-bit encoding (flag=0), Lifecycle: 6-bit encoding (flag=0)
            int birthRdFlags = 0x00;   // 6-bit encoding, not corrected
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
            
            // Minimum DRT boyutu kontrolü (ToC Header + 2 RDs + Birth + Lifecycle + Trailer)
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
                    success = reader.writeData("00000000", 3, wordsWritten, chunkSize, chunkHex);
                    
                    if (!success) break;
                    wordsWritten += chunkSize;
                    try { Thread.sleep(50); } catch (Exception ignored) {}
                }
            } else {
                success = reader.writeData("00000000", 3, 0, totalWords, fullHex);
            }

            Log.i(TAG, success ? "✅ DUAL-RECORD: Write successful!" : "❌ DUAL-RECORD: Write failed!");
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error writing Dual-Record: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== MULTI-RECORD TAG (MRT) ====================

    /**
     * Write Multi-Record Tag per ATA Spec 2000 Section 4
     * Structure: ToC Header + RDs + Birth Record + Current Data Record + (optional) Scratchpad + Trailer
     */
    private boolean writeMultiRecordTag(
            String manufacturer, String productName, String partNumber,
            String serialNumber, String manufactureDate, String expireDate) {
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
        try {
            Log.i(TAG, "📝 MULTI-RECORD: Starting write");

            // Build Birth Record payload (per Table 8)
            StringBuilder birthPayload = new StringBuilder();
            if (manufacturer != null && !manufacturer.isEmpty())
                birthPayload.append("MFR ").append(manufacturer).append("*");
            if (serialNumber != null && !serialNumber.isEmpty())
                birthPayload.append("SER ").append(serialNumber).append("*");
            if (partNumber != null && !partNumber.isEmpty())
                birthPayload.append("PNO ").append(partNumber).append("*"); // Original Part Number
            birthPayload.append("UIC 1*");
            if (productName != null && !productName.isEmpty())
                birthPayload.append("PDT ").append(productName).append("*");
            if (manufactureDate != null && !manufactureDate.isEmpty())
                birthPayload.append("DMF ").append(manufactureDate).append("*");

            String birthText = birthPayload.toString();
            String birthBits = AtaEncodingUtils.encode6Bit(birthText) + "000000";
            int birthPadBits = (16 - (birthBits.length() % 16)) % 16;
            for (int i = 0; i < birthPadBits; i++) birthBits += '0';
            String birthPayloadHex = AtaEncodingUtils.bitsToHex(birthBits);
            int birthPayloadWords = birthBits.length() / 16;
            int birthRecordSize = 2 + birthPayloadWords + 1; // Header + Payload + CRC

            // Build Current Data Record (CDR) payload (per Table 9)
            StringBuilder cdrPayload = new StringBuilder();
            if (partNumber != null && !partNumber.isEmpty())
                cdrPayload.append("PNR ").append(partNumber).append("*"); // Current Part Number
            if (expireDate != null && !expireDate.isEmpty())
                cdrPayload.append("EXP ").append(expireDate).append("*");
            cdrPayload.append("CND SRV*"); // Condition: Serviceable

            String cdrText = cdrPayload.toString();
            String cdrBits = AtaEncodingUtils.encode6Bit(cdrText) + "000000";
            int cdrPadBits = (16 - (cdrBits.length() % 16)) % 16;
            for (int i = 0; i < cdrPadBits; i++) cdrBits += '0';
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

            // Build ToC Header (per ATA Spec Figure 53)
            String w0 = String.format("%04X", 0x1E00); // DSFID
            // Word 1: [ToC Minor:3][ToC Major:4][ATA Tag Type:4][ATA Class:5]
            int word1 = ((2 & 0x7) << 13) | ((4 & 0xF) << 9) | ((0x0000 & 0xF) << 5) | (1 & 0x1F);
            String w1 = String.format("%04X", word1);
            // Word 2: [Flags:8][Size of ToC Header:4][Size of RDs:4]
            int word2 = ((0x08 & 0xFF) << 8) | ((4 & 0xF) << 4) | (2 & 0xF);
            String w2 = String.format("%04X", word2);
            String w3 = String.format("%04X", totalWords);

            // Build Record Descriptors (CDR first, then Birth - per ATA Spec ordering)
            // RD Flags: Bit 0 = 8-bit encoding, Bit 1 = Corrected birth
            String rd1 = String.format("%04X%04X", cdrAddress, (0x01 << 8) | 0x00); // Type 0x01 = CDR
            String rd2 = String.format("%04X%04X", birthAddress, (0x00 << 8) | 0x00); // Type 0x00 = Birth

            // Build Birth Record with header and CRC
            String birthHeader = String.format("%04X%04X", birthRecordSize, (0x00 << 8) | (1 << 5) | 3);
            String birthDataNoCrc = birthHeader + birthPayloadHex;
            String birthRecordHex = birthDataNoCrc + String.format("%04X",
                    AtaEncodingUtils.calculateCrc16Ccitt(birthDataNoCrc));

            // Build CDR with header and CRC
            String cdrHeader = String.format("%04X%04X", cdrRecordSize, (0x01 << 8) | (1 << 5) | 3);
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
                    success = reader.writeData("00000000", 3, wordsWritten, chunkSize, chunkHex);
                    
                    if (!success) break;
                    wordsWritten += chunkSize;
                    try { Thread.sleep(50); } catch (Exception ignored) {}
                }
            } else {
                success = reader.writeData("00000000", 3, 0, totalWords, fullHex);
            }

            Log.i(TAG, success ? "✅ MULTI-RECORD: Write successful!" : "❌ MULTI-RECORD: Write failed!");
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
     * @param epcHex Target tag EPC
     * @param actionCompany CAGE code (5 chars)
     * @param actionDate Date YYYYMMDD
     * @param remarks Free text (up to 344 chars)
     */
    public boolean writeScratchpadEntry(String epcHex, String actionCompany,
            String actionDate, String remarks) {
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
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

            // TODO: Read existing USER memory to find Scratchpad record location
            // For now, this is a placeholder - actual implementation needs to:
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
        if (reader == null) return false;
        
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

            int w1 = Integer.parseInt(existingUserHex.substring(4, 8), 16);
            int tagType = (w1 >> 5) & 0xF;
            if (tagType != 0x0000) { // MRT = 0x0000
                Log.e(TAG, "❌ Not a Multi-Record tag (type=" + tagType + ")");
                return false;
            }

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

            // Build new CDR payload (per Table 9)
            StringBuilder cdrPayload = new StringBuilder();
            if (currentPartNumber != null && !currentPartNumber.isEmpty())
                cdrPayload.append("PNR ").append(currentPartNumber).append("*");
            if (partModLevel != null && !partModLevel.isEmpty())
                cdrPayload.append("PML ").append(partModLevel).append("*");
            if (expirationDate != null && !expirationDate.isEmpty())
                cdrPayload.append("EXP ").append(expirationDate).append("*");
            if (conditionCode != null && !conditionCode.isEmpty())
                cdrPayload.append("CND ").append(conditionCode).append("*");

            String cdrText = cdrPayload.toString();
            String cdrBits = AtaEncodingUtils.encode6Bit(cdrText) + "000000";

            int payloadWords = cdrRecordSize - 3;
            int requiredBits = payloadWords * 16;
            while (cdrBits.length() < requiredBits) cdrBits += '0';

            if (cdrBits.length() > requiredBits) {
                Log.e(TAG, "❌ CDR Payload too large!");
                return false;
            }

            String cdrPayloadHex = AtaEncodingUtils.bitsToHex(cdrBits);

            String cdrHeader = String.format("%04X%04X", cdrRecordSize, (0x01 << 8) | (1 << 5) | 3);
            String cdrDataNoCrc = cdrHeader + cdrPayloadHex;
            String newCdrRecordHex = cdrDataNoCrc + 
                    String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(cdrDataNoCrc));

            boolean success = reader.writeData("00000000", 3, cdrAddr, cdrRecordSize, newCdrRecordHex);
            Log.i(TAG, success ? "✅ CDR-UPDATE: Success!" : "❌ CDR-UPDATE: Failed!");
            
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error updating CDR: " + e.getMessage(), e);
            return false;
        }
    }

    // ==================== LIFECYCLE UPDATE ====================

    public boolean updateLifecycleRecord(String epcHex, String currentPartNumber,
            String partModLevel, String expirationDate, String certificateNumber,
            String lastOverhaulDate) {
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
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

            int w1 = Integer.parseInt(existingUserHex.substring(4, 8), 16);
            int tagType = (w1 >> 5) & 0xF;
            if (tagType != 0x0001) {
                Log.e(TAG, "❌ Not a Dual-Record tag");
                return false;
            }

            int lifecycleAddr = Integer.parseInt(existingUserHex.substring(16, 20), 16);
            int lifecycleType = (Integer.parseInt(existingUserHex.substring(20, 24), 16) >> 8) & 0xFF;

            if (lifecycleType != 0x04) {
                Log.e(TAG, "❌ RD #1 is not Lifecycle");
                return false;
            }

            int lifecycleRecordOffset = lifecycleAddr * 4;
            int lifecycleRecordSize = Integer.parseInt(
                    existingUserHex.substring(lifecycleRecordOffset, lifecycleRecordOffset + 4), 16);

            // Build new Lifecycle payload
            StringBuilder lifecyclePayload = new StringBuilder();
            if (currentPartNumber != null && !currentPartNumber.isEmpty())
                lifecyclePayload.append("PNR ").append(currentPartNumber).append("*");
            if (partModLevel != null && !partModLevel.isEmpty())
                lifecyclePayload.append("PML ").append(partModLevel).append("*");
            if (expirationDate != null && !expirationDate.isEmpty())
                lifecyclePayload.append("EXP ").append(expirationDate).append("*");
            if (certificateNumber != null && !certificateNumber.isEmpty())
                lifecyclePayload.append("TDN ").append(certificateNumber).append("*");
            if (lastOverhaulDate != null && !lastOverhaulDate.isEmpty())
                lifecyclePayload.append("OVD ").append(lastOverhaulDate).append("*");

            String lifecycleText = lifecyclePayload.length() > 0 && lifecyclePayload.charAt(0) == '*'
                    ? lifecyclePayload.substring(1) : lifecyclePayload.toString();

            String lifecycleBits = AtaEncodingUtils.encode6Bit(lifecycleText) + "000000";

            int payloadWords = lifecycleRecordSize - 3;
            int requiredBits = payloadWords * 16;
            while (lifecycleBits.length() < requiredBits) lifecycleBits += '0';

            if (lifecycleBits.length() > requiredBits) {
                Log.e(TAG, "❌ Payload too large!");
                return false;
            }

            String lifecyclePayloadHex = AtaEncodingUtils.bitsToHex(lifecycleBits);

            String lifecycleHeader = String.format("%04X%04X", lifecycleRecordSize, (0x04 << 8) | (1 << 5) | 3);
            String lifecycleDataNoCrc = lifecycleHeader + lifecyclePayloadHex;
            String newLifecycleRecordHex = lifecycleDataNoCrc + 
                    String.format("%04X", AtaEncodingUtils.calculateCrc16Ccitt(lifecycleDataNoCrc));

            boolean success = reader.writeData("00000000", 3, lifecycleAddr, lifecycleRecordSize, newLifecycleRecordHex);
            Log.i(TAG, success ? "✅ LIFECYCLE-UPDATE: Success!" : "❌ LIFECYCLE-UPDATE: Failed!");
            
            return success;

        } catch (Exception e) {
            Log.e(TAG, "Error updating Lifecycle: " + e.getMessage(), e);
            return false;
        }
    }
}

