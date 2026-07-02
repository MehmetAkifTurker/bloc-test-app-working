package SDKMethods.ata;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/**
 * ATA Spec 2000 Encoding/Decoding Utilities
 * 
 * Contains 6-bit ASCII encoding/decoding, CRC-16 calculation,
 * binary/hex conversion utilities per ATA Spec 2000.
 */
public class AtaEncodingUtils {

    // ============== 6-BIT ASCII MAPPING (ATA Spec 2000 Appendix B) ==============
    
    public static final Map<Character, String> CHAR_TO_6BIT;
    public static final Map<String, Character> SIXBIT_TO_CHAR;
    
    static {
        CHAR_TO_6BIT = new HashMap<>();
        // Space and punctuation (ASCII 32-63 -> 6-bit 100000-111111)
        CHAR_TO_6BIT.put(' ', "100000");
        CHAR_TO_6BIT.put('!', "100001");
        CHAR_TO_6BIT.put('"', "100010"); // ASCII 34 - double quote
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
        
        // Digits (ASCII 48-57 -> 6-bit 110000-111001)
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
        
        // Punctuation (ASCII 58-63 -> 6-bit 111010-111111)
        CHAR_TO_6BIT.put(':', "111010");
        CHAR_TO_6BIT.put(';', "111011");
        CHAR_TO_6BIT.put('<', "111100");
        CHAR_TO_6BIT.put('=', "111101");
        CHAR_TO_6BIT.put('>', "111110");
        CHAR_TO_6BIT.put('?', "111111");

        // Special character @ (ASCII 64 -> 6-bit 000000)
        CHAR_TO_6BIT.put('@', "000000");  // ATA Spec 2000 Appendix B

        // Uppercase letters (ASCII 64-90 -> 6-bit 000000-011010)
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
        
        // Special characters (ASCII 91-95 -> 6-bit 011011-011111)
        CHAR_TO_6BIT.put('[', "011011");
        CHAR_TO_6BIT.put('\\', "011100");
        CHAR_TO_6BIT.put(']', "011101");
        CHAR_TO_6BIT.put('^', "011110");
        CHAR_TO_6BIT.put('_', "011111");
        
        // Build reverse map
        SIXBIT_TO_CHAR = new HashMap<>();
        for (Map.Entry<Character, String> e : CHAR_TO_6BIT.entrySet()) {
            SIXBIT_TO_CHAR.put(e.getValue(), e.getKey());
        }
    }

    // ============== ENCODING ==============
    
    /**
     * Encode text to 6-bit binary string
     * @param text Text to encode (uppercase letters, digits, punctuation)
     * @return Binary string (6 bits per character)
     */
    public static String encode6Bit(String text) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            String bits = CHAR_TO_6BIT.get(c);
            if (bits == null) {
                throw new IllegalArgumentException("Character '" + c + "' not in 6-bit dictionary");
            }
            sb.append(bits);
        }
        return sb.toString();
    }
    
    /**
     * Encode text to 8-bit ASCII hex string (for Scratchpad records per ATA Spec)
     * @param text Text to encode
     * @return Hex string (2 hex chars per character)
     */
    public static String encode8BitAscii(String text) {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            sb.append(String.format("%02X", (int) c));
        }
        return sb.toString();
    }
    
    /**
     * Get 6-bit code for a character, returns NUL (000000) if not found
     */
    public static String get6BitCode(char c) {
        String bits = CHAR_TO_6BIT.get(Character.toUpperCase(c));
        return bits != null ? bits : "000000";
    }

    // ============== DECODING ==============
    
    /**
     * Decode 6-bit binary string to text
     * @param bits Binary string
     * @return Decoded text
     */
    public static String decode6Bit(String bits) {
        StringBuilder out = new StringBuilder();
        for (int i = 0; i + 6 <= bits.length(); i += 6) {
            String sextet = bits.substring(i, i + 6);
            if ("000000".equals(sextet)) break; // NUL = end delimiter
            Character ch = SIXBIT_TO_CHAR.get(sextet);
            out.append(ch != null ? ch : '?');
        }
        return out.toString();
    }
    
    /**
     * Decode USER memory payload hex to text
     * @param userHex Full USER memory hex (including 4-word header)
     * @return Decoded payload text
     */
    public static String decodeUserPayloadHexToText(String userHex) {
        if (userHex == null || userHex.length() < 16) return "";
        
        // Skip 4-word header (16 hex chars)
        String payloadHex = userHex.substring(16);
        
        // Hex to binary
        StringBuilder bits = new StringBuilder(payloadHex.length() * 4);
        for (int i = 0; i < payloadHex.length(); i++) {
            int v = Integer.parseInt(payloadHex.substring(i, i + 1), 16);
            bits.append(String.format("%4s", Integer.toBinaryString(v)).replace(' ', '0'));
        }
        
        return decode6Bit(bits.toString());
    }
    
    /**
     * Parse ATA user text format "*MFR XXX*PNR YYY*SER ZZZ*" into fields
     */
    public static Map<String, String> parseAtaUserText(String text) {
        Map<String, String> res = new HashMap<>();
        if (text == null || text.isEmpty()) return res;
        
        String[] parts = text.split("\\*");
        for (String part : parts) {
            part = part.trim();
            if (part.isEmpty()) continue;
            int sp = part.indexOf(' ');
            if (sp <= 0) continue;
            String key = part.substring(0, sp).trim();
            String val = part.substring(sp + 1).trim();
            res.put(key, val);
        }
        return res;
    }

    // ============== CRC ==============
    
    /**
     * Calculate CRC-16/CCITT over hex string data (ATA Spec 2000 Appendix A)
     * Polynomial: x^16 + x^12 + x^5 + 1 (0x1021)
     * Initial value: 0xFFFF
     */
    public static int calculateCrc16Ccitt(String hexData) {
        int crc = 0xFFFF;
        
        for (int i = 0; i < hexData.length(); i += 2) {
            if (i + 2 > hexData.length()) break;
            
            int byteVal = Integer.parseInt(hexData.substring(i, i + 2), 16);
            crc ^= (byteVal << 8);
            
            for (int bit = 0; bit < 8; bit++) {
                if ((crc & 0x8000) != 0) {
                    crc = (crc << 1) ^ 0x1021;
                } else {
                    crc = crc << 1;
                }
            }
        }
        
        return crc & 0xFFFF;
    }

    // ============== TAG TYPE MAPPING ==============
    
    /**
     * Map record type string to ATA Tag Type field (per ATA Spec Figure 53)
     * @param recordType "DRT", "SRT-B", "SRT-U", "MRT"
     * @return 4-bit tag type value
     */
    public static int mapAtaTagType(String recordType) {
        if (recordType == null) return 0x0002; // default: Single Birth-Record
        
        String rt = recordType.toUpperCase(Locale.ROOT);
        if (rt.contains("MULTI") || rt.equals("MRT")) return 0x0000; // Multi-Record
        if (rt.contains("DUAL") || rt.equals("DRT")) return 0x0001; // Dual-Record
        if (rt.contains("UTILITY") || rt.equals("SRT-U")) return 0x000A; // Single Utility
        
        return 0x0002; // Single Birth-Record (default)
    }
    
    // ============== TEI VALIDATION (ATA Spec 2000 Tables 3-13) ==============
    
    /** TEI field length limits per ATA Spec 2000 */
    public static final int TEI_MFR_LEN = 5;      // CAGE Code: exactly 5 chars
    public static final int TEI_CAG_LEN = 5;      // CAGE Code: exactly 5 chars
    public static final int TEI_SPL_LEN = 5;      // Supplier Code: exactly 5 chars
    public static final int TEI_SER_MIN = 1;      // Serial Number: 1-30 chars
    public static final int TEI_SER_MAX = 30;
    public static final int TEI_SEQ_MIN = 1;      // Sequential Number: 1-30 chars
    public static final int TEI_SEQ_MAX = 30;
    public static final int TEI_PNR_MIN = 1;      // Part Number: 1-32 chars
    public static final int TEI_PNR_MAX = 32;
    public static final int TEI_PNO_MIN = 1;      // Original Part Number: 1-32 chars
    public static final int TEI_PNO_MAX = 32;
    public static final int TEI_PDT_MIN = 1;      // Part Description: 1-32 chars
    public static final int TEI_PDT_MAX = 32;
    public static final int TEI_DMF_LEN = 8;      // Manufacture Date: YYYYMMDD
    public static final int TEI_EXP_LEN = 8;      // Expiration Date: YYYYMMDD
    public static final int TEI_OVD_LEN = 8;      // Overhaul Date: YYYYMMDD
    public static final int TEI_DOH_LEN = 8;      // Hydrostatic Test Date: YYYYMMDD
    public static final int TEI_UIC_LEN = 1;      // UID Construct: exactly 1 char (1 or 2)
    public static final int TEI_PML_MIN = 1;      // Part Modification Level: 1-100 chars
    public static final int TEI_PML_MAX = 100;
    public static final int TEI_TDN_MIN = 1;      // Certificate Tracking Number: 1-32 chars
    public static final int TEI_TDN_MAX = 32;
    public static final int TEI_HAZ_LEN = 6;      // Hazardous Material Code: exactly 6 chars
    public static final int TEI_LLE_LEN = 1;      // Life Limited Equipment: 1 char (0 or 1)
    public static final int TEI_LOT_MIN = 1;      // Lot Number: 1-15 chars
    public static final int TEI_LOT_MAX = 15;
    public static final int TEI_LTN_MIN = 1;      // Lot Traceability Number: 1-30 chars
    public static final int TEI_LTN_MAX = 30;
    public static final int TEI_ACT_LEN = 3;      // Action Code: exactly 3 chars
    public static final int TEI_ACO_LEN = 5;      // Action Company CAGE: exactly 5 chars
    public static final int TEI_ACD_LEN = 8;      // Action Date: YYYYMMDD
    public static final int TEI_CND_LEN = 3;      // Condition Code: exactly 3 chars (SRV/UNS/UNK)

    // HATA #5 FIX: Add missing TEI field definitions per ATA Spec 2000
    public static final int TEI_ICC_MIN = 1;      // Item Control Code: 1-32 chars
    public static final int TEI_ICC_MAX = 32;
    public static final int TEI_ESD_LEN = 1;      // ESD Sensitive: exactly 1 char (0 or 1)
    public static final int TEI_UNT_MIN = 2;      // Unit of Measure: 2-3 chars
    public static final int TEI_UNT_MAX = 3;
    public static final int TEI_FAB_MIN = 1;      // Fabrication/Finish Code: 1-4 chars
    public static final int TEI_FAB_MAX = 4;
    public static final int TEI_NSN_LEN = 13;     // NATO Stock Number: exactly 13 chars (numeric)
    public static final int TEI_SWI_MIN = 1;      // Special Work Instructions: 1-30 chars
    public static final int TEI_SWI_MAX = 30;
    public static final int TEI_OMM_MIN = 1;      // OEM Maintenance Manual: 1-30 chars
    public static final int TEI_OMM_MAX = 30;
    public static final int TEI_FIN_MIN = 1;      // Financial Account Code: 1-20 chars
    public static final int TEI_FIN_MAX = 20;
    public static final int TEI_QRT_MIN = 1;      // Qualitative Rating Target: 1-4 chars
    public static final int TEI_QRT_MAX = 4;
    public static final int TEI_PSL_MIN = 1;      // Preparation Specification Level: 1-30 chars
    public static final int TEI_PSL_MAX = 30;
    public static final int TEI_ETN_MIN = 1;      // Exchange Tagged Number: 1-32 chars
    public static final int TEI_ETN_MAX = 32;
    
    /**
     * Validate TEI field length per ATA Spec 2000
     * @param tei TEI code (e.g., "MFR", "SER", "PNR")
     * @param value Field value to validate
     * @return Error message if invalid, null if valid
     */
    public static String validateTeiLength(String tei, String value) {
        if (value == null || value.isEmpty()) return null; // Optional fields can be empty

        int len = value.length();
        String teiUpper = tei.toUpperCase(Locale.ROOT);

        switch (teiUpper) {
            case "MFR":
            case "CAG":
            case "SPL":
            case "ACO":
                if (len != 5) return tei + " must be exactly 5 characters";
                // HATA #3 FIX: CAGE code must be uppercase alphanumeric
                if (!value.matches("^[0-9A-Z]{5}$")) {
                    return tei + " must be 5 uppercase alphanumeric characters (0-9, A-Z)";
                }
                break;
            case "SER":
            case "SEQ":
                if (len < TEI_SER_MIN || len > TEI_SER_MAX)
                    return tei + " must be 1-30 characters";
                break;
            case "PNR":
            case "PNO":
            case "PDT":
            case "TDN":
                if (len < TEI_PNR_MIN || len > TEI_PNR_MAX)
                    return tei + " must be 1-32 characters";
                break;
            case "DMF":
            case "EXP":
            case "OVD":
            case "DOH":
            case "ACD":
                // HATA #2 FIX: Date format YYYYMMDD with range validation
                if (len != 8) return tei + " must be YYYYMMDD (8 characters)";
                if (!value.matches("^\\d{4}(0[1-9]|1[0-2])(0[1-9]|[12]\\d|3[01])$")) {
                    return tei + " must be valid date in YYYYMMDD format (MM: 01-12, DD: 01-31)";
                }
                break;
            case "UIC":
                // HATA #4 FIX: UIC must be exactly "1" or "2"
                if (!value.matches("^[12]$")) {
                    return "UIC must be '1' or '2' (UID construct type)";
                }
                break;
            case "LLE":
                // HATA #4 FIX: LLE must be exactly "0" or "1"
                if (!value.matches("^[01]$")) {
                    return "LLE must be '0' or '1' (Life Limited Equipment)";
                }
                break;
            case "CND":
                // HATA #4 FIX: CND must be "SRV", "UNS", or "UNK"
                if (!value.matches("^(SRV|UNS|UNK)$")) {
                    return "CND must be 'SRV', 'UNS', or 'UNK' (Condition Code)";
                }
                break;
            case "PML":
                if (len < TEI_PML_MIN || len > TEI_PML_MAX)
                    return tei + " must be 1-100 characters";
                break;
            case "HAZ":
                if (len != 6) return tei + " must be exactly 6 characters";
                break;
            case "LOT":
                if (len < TEI_LOT_MIN || len > TEI_LOT_MAX)
                    return tei + " must be 1-15 characters";
                break;
            case "LTN":
                // HATA #5 FIX: Lot Traceability Number (separate from LOT)
                if (len < TEI_LTN_MIN || len > TEI_LTN_MAX)
                    return tei + " must be 1-30 characters";
                break;
            case "ACT":
                if (len != 3) return tei + " must be exactly 3 characters";
                break;

            // HATA #5 FIX: Add missing TEI field validations per ATA Spec 2000
            case "ICC":
                if (len < TEI_ICC_MIN || len > TEI_ICC_MAX)
                    return tei + " must be 1-32 characters (Item Control Code)";
                break;
            case "ESD":
                if (!value.matches("^[01]$"))
                    return "ESD must be '0' or '1' (ESD Sensitive)";
                break;
            case "UNT":
                if (len < TEI_UNT_MIN || len > TEI_UNT_MAX)
                    return tei + " must be 2-3 characters (Unit of Measure)";
                if (!value.matches("^[A-Z]{2,3}$"))
                    return tei + " must be uppercase alpha characters only";
                break;
            case "FAB":
                if (len < TEI_FAB_MIN || len > TEI_FAB_MAX)
                    return tei + " must be 1-4 characters (Fabrication Code)";
                break;
            case "NSN":
                if (len != TEI_NSN_LEN)
                    return tei + " must be exactly 13 numeric characters (NATO Stock Number)";
                if (!value.matches("^\\d{13}$"))
                    return tei + " must contain only digits";
                break;
            case "SWI":
                if (len < TEI_SWI_MIN || len > TEI_SWI_MAX)
                    return tei + " must be 1-30 characters (Special Work Instructions)";
                break;
            case "OMM":
                if (len < TEI_OMM_MIN || len > TEI_OMM_MAX)
                    return tei + " must be 1-30 characters (OEM Maintenance Manual)";
                break;
            case "FIN":
                if (len < TEI_FIN_MIN || len > TEI_FIN_MAX)
                    return tei + " must be 1-20 characters (Financial Account)";
                break;
            case "QRT":
                if (len < TEI_QRT_MIN || len > TEI_QRT_MAX)
                    return tei + " must be 1-4 characters (Qualitative Rating)";
                break;
            case "PSL":
                if (len < TEI_PSL_MIN || len > TEI_PSL_MAX)
                    return tei + " must be 1-30 characters (Preparation Spec Level)";
                break;
            case "ETN":
                if (len < TEI_ETN_MIN || len > TEI_ETN_MAX)
                    return tei + " must be 1-32 characters (Exchange Tagged Number)";
                break;
        }
        return null;
    }

    // ============== BINARY/HEX CONVERSION ==============
    
    /**
     * Convert binary string to hex
     */
    public static String binaryToHex(String binaryStr) {
        List<String> chunks = splitIntoChunks(binaryStr, 8);
        StringBuilder sb = new StringBuilder();
        for (String bin : chunks) {
            // Pad to 8 bits if needed
            while (bin.length() < 8) bin = bin + "0";
            int decimal = Integer.parseInt(bin, 2);
            sb.append(String.format("%02X", decimal));
        }
        return sb.toString();
    }
    
    /**
     * Convert bits to hex (4 bits per hex digit)
     */
    public static String bitsToHex(String bits) {
        StringBuilder hex = new StringBuilder();
        for (int i = 0; i < bits.length(); i += 4) {
            int end = Math.min(bits.length(), i + 4);
            String nibble = bits.substring(i, end);
            while (nibble.length() < 4) nibble = nibble + "0";
            hex.append(Integer.toHexString(Integer.parseInt(nibble, 2)).toUpperCase());
        }
        return hex.toString();
    }
    
    /**
     * Split string into chunks of specified size
     */
    public static List<String> splitIntoChunks(String str, int chunkSize) {
        List<String> chunks = new ArrayList<>();
        for (int i = 0; i < str.length(); i += chunkSize) {
            int end = Math.min(str.length(), i + chunkSize);
            chunks.add(str.substring(i, end));
        }
        return chunks;
    }
    
    /**
     * Convert hex string to binary string
     */
    public static String hexToBinary(String hex) {
        StringBuilder bits = new StringBuilder(hex.length() * 4);
        for (int i = 0; i < hex.length(); i++) {
            int v = Integer.parseInt(hex.substring(i, i + 1), 16);
            bits.append(String.format("%4s", Integer.toBinaryString(v)).replace(' ', '0'));
        }
        return bits.toString();
    }
    
    /**
     * Pad binary string to multiple of specified bits
     */
    public static String padToMultiple(String bits, int multiple) {
        int padBits = (multiple - (bits.length() % multiple)) % multiple;
        StringBuilder sb = new StringBuilder(bits);
        for (int i = 0; i < padBits; i++) {
            sb.append('0');
        }
        return sb.toString();
    }
}

