package SDKMethods.core;

import android.content.Context;
import android.media.MediaPlayer;
import android.util.Log;

import com.example.rfid_manager.R;
import com.rscja.barcode.BarcodeDecoder;
import com.rscja.barcode.BarcodeFactory;
import com.rscja.barcode.BarcodeUtility;
import com.rscja.deviceapi.RFIDWithUHFUART;

/**
 * Core UHF Reader Manager - Handles connection, power, and barcode
 */
public class UHFManager {
    private static final String TAG = "UHFManager";

    private static UHFManager instance;
    private RFIDWithUHFUART mReader;
    private BarcodeDecoder barcodeDecoder;
    private UHFListener uhfListener;
    private Context context;
    private boolean isConnect = false;
    private String scannedBarcode;
    private final Object barcodeLock = new Object();

    private UHFManager() {
    }

    public static synchronized UHFManager getInstance() {
        if (instance == null) {
            instance = new UHFManager();
        }
        return instance;
    }

    public void init(Context context) {
        this.context = context;
    }

    public Context getContext() {
        return context;
    }

    public RFIDWithUHFUART getReader() {
        return mReader;
    }

    public void setUhfListener(UHFListener listener) {
        this.uhfListener = listener;
    }

    public UHFListener getUhfListener() {
        return uhfListener;
    }

    // ==================== CONNECTION ====================

    public synchronized boolean connect() {
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
            configureReader();
        }
        return isConnect;
    }

    private void configureReader() {
        // Reset module state left over from OTHER apps. Since we release the
        // reader when backgrounded (so e.g. the vendor UHF demo can use it),
        // that app's select masks / inventory mode persist in the module and
        // would make our inventory return zero tags. Clear filters on every
        // bank and toggle the inventory mode before applying our config.
        try {
            mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
            mReader.setFilter(RFIDWithUHFUART.Bank_TID, 0, 0, "");
            mReader.setFilter(RFIDWithUHFUART.Bank_USER, 0, 0, "");
            Log.i(TAG, "✓ Filters cleared (EPC/TID/USER)");
        } catch (Exception e) {
            Log.w(TAG, "Filter clear failed: " + e.getMessage());
        }
        // IMPORTANT: TagFocus and FastID are Impinj-Monza-proprietary features.
        // With non-Impinj tags (as used here) enabling them makes the reader
        // completely DEAF: inventory returns zero tags while the vendor demo
        // reads the same tags fine. Verified by a staged on-device probe
        // (as-configured => null; fastID off => tags appear immediately).
        // Explicitly set both OFF (not just "don't enable") to also clear any
        // state left in the module by other apps. TID is already provided by
        // setEPCAndTIDUserMode, so FastID adds nothing for us anyway.
        try {
            mReader.setTagFocus(false);
        } catch (Exception ignore) {
        }
        try {
            mReader.setFastID(false);
            Log.i(TAG, "✓ TagFocus/FastID disabled (non-Impinj tags)");
        } catch (Exception ignore) {
        }

        try {
            // Same "reset trick" as the demo app: toggle mode off, then set ours.
            mReader.setEPCAndTIDMode();
            Thread.sleep(15);
        } catch (Exception ignore) {
        }

        try {
            // Configure EPC+TID+USER simultaneous reading.
            // SDK javadoc (IUHF.setEPCAndTIDUserMode): param1 = user_prt (START
            // ADDRESS in the USER bank), param2 = user_len (word count). ATA
            // Spec 2000 data starts at USER word 0 (DSFID 0x1E00), so start=0.
            // The old call here used (10, 64) — reading from word 10 runs past
            // the end of small (33-word) tags, which is why combined-mode
            // inventory never delivered USER and everything fell back to
            // pause-and-read fetching. 32 words covers the ToC header + first
            // records; bigger tags are topped up by the background fetcher.
            boolean allModeSet = mReader.setEPCAndTIDUserMode(0, 32);
            if (allModeSet) {
                Log.i(TAG, "✓ EPC+TID+USER(start=0,len=32) mode configured");
            } else {
                allModeSet = mReader.setEPCAndTIDUserMode(0, 12);
                if (allModeSet) {
                    Log.i(TAG, "✓ EPC+TID+USER(start=0,len=12) fallback configured");
                } else {
                    Log.w(TAG, "⚠ All combined modes failed - using default");
                }
            }
            Thread.sleep(100);
        } catch (Exception e) {
            Log.e(TAG, "Failed to configure scanning mode: " + e.getMessage());
        }

        // (TagFocus/FastID intentionally NOT enabled here — see the note above:
        // they deafen the reader for the non-Impinj tags used in this project.)

        try {
            int currentPower = mReader.getPower();
            Log.d(TAG, "Current UHF power: " + currentPower + " dBm");
        } catch (Exception e) {
            Log.w(TAG, "Failed to read power: " + e.getMessage());
        }

        try {
            // Diagnostic: log the frequency region so a band mismatch vs. the
            // vendor app is visible in logcat (tags won't respond on a wrong band).
            Log.i(TAG, "Frequency mode: " + mReader.getFrequencyMode());
        } catch (Exception e) {
            Log.w(TAG, "Failed to read frequency mode: " + e.getMessage());
        }
    }

    public synchronized void close() {
        if (mReader != null) {
            mReader.free();
            mReader = null;
        }
        isConnect = false;
    }

    public boolean isConnected() {
        return isConnect;
    }

    // ==================== POWER & FREQUENCY ====================

    public boolean setPowerLevel(String level) {
        if (mReader != null) {
            try {
                int pwr = Integer.parseInt(level);
                boolean result = mReader.setPower(pwr);
                Log.i(TAG, "📡 setPower(" + pwr + " dBm) => " + (result ? "SUCCESS" : "FAILED"));

                // Verify by reading back
                int actualPower = mReader.getPower();
                Log.d(TAG, "📡 Actual power now: " + actualPower + " dBm");

                return result;
            } catch (Exception e) {
                Log.e(TAG, "setPowerLevel error: " + e.getMessage());
                return false;
            }
        }
        Log.w(TAG, "setPowerLevel: mReader is null");
        return false;
    }

    public String getPowerLevel() {
        if (mReader != null) {
            try {
                return String.valueOf(mReader.getPower());
            } catch (Exception e) {
                return "Error: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    public boolean setWorkArea(String area) {
        if (mReader != null) {
            int mode = Integer.parseInt(area);
            return mReader.setFrequencyMode(mode);
        }
        return false;
    }

    public String getFrequencyMode() {
        if (mReader != null) {
            try {
                return String.valueOf(mReader.getFrequencyMode());
            } catch (Exception e) {
                return "Error: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    public String getTemperature() {
        if (mReader != null) {
            try {
                return String.valueOf(mReader.getTemperature());
            } catch (Exception e) {
                return "Error: " + e.getMessage();
            }
        }
        return "mReader is null";
    }

    // ==================== FILTER ====================

    // Store current ATA filter value for persistence across reads
    private int currentAtaFilterValue = -1;

    public synchronized boolean setEpcFilter(String epcHex) {
        if (mReader == null)
            return false;
        try {
            int bits = epcHex != null ? epcHex.length() * 4 : 0;
            if (bits <= 0)
                return false;
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, bits, epcHex);
        } catch (Exception e) {
            Log.e(TAG, "setEpcFilter error", e);
            return false;
        }
    }

    public synchronized boolean clearFilter() {
        if (mReader == null)
            return false;
        try {
            boolean result = mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
            // Restore ATA filter if one was set
            if (result && currentAtaFilterValue >= 0) {
                return setFilterValueMask(currentAtaFilterValue);
            }
            return result;
        } catch (Exception e) {
            Log.e(TAG, "clearFilter error", e);
            return false;
        }
    }

    /**
     * Set hardware-level ATA filter by Filter Value (0-63)
     * 
     * ATA Spec 2000 EPC Format:
     * - Bits 0-7: Header (0x3B = 00111011)
     * - Bits 8-13: Filter Value (6 bits, 0-63)
     * 
     * Filter mask for Filter Value 14:
     * Header: 0011 1011 (0x3B)
     * Filter: 00 1110 (14 in 6-bit, padded to align)
     * Combined: 0011 1011 0011 10xx = 0x3B38 (14 bits)
     */
    public synchronized boolean setFilterValueMask(int filterValue) {
        if (mReader == null)
            return false;

        if (filterValue < 0) {
            // Clear all filters (show all tags)
            Log.d(TAG, "Clearing filter (show all tags)");
            currentAtaFilterValue = -1;
            return clearAllFiltersInternal();
        }

        try {
            // Store for persistence
            currentAtaFilterValue = filterValue;

            // Build 14-bit mask: 8-bit header (0x3B) + 6-bit filter value
            // Left-aligned in EPC bank starting at bit 32 (after CRC and PC)
            int combined = (0x3B << 6) | (filterValue & 0x3F);
            String maskHex = String.format("%04X", combined << 2); // Shift left 2 bits for alignment

            // Actually we need the raw 14-bit value as hex
            // combined = 0x3B << 6 | filterValue = header * 64 + filterValue
            // For filter 14: 0x3B * 64 + 14 = 59 * 64 + 14 = 3790 = 0x0ECE
            // But we need it as 14 bits starting at bit 32

            // Simpler approach: just use the first 2 bytes of EPC
            // Byte 0 = header = 0x3B
            // Byte 1 contains filter value in upper 6 bits
            // Filter 14 = 001110 -> byte1 = 00111000 = 0x38
            int byte1 = (filterValue & 0x3F) << 2;
            maskHex = String.format("%02X%02X", 0x3B, byte1);

            Log.d(TAG, "Setting filter: FilterValue=" + filterValue + ", mask=" + maskHex + " (14 bits)");

            // Set filter on EPC bank, starting at bit 32 (after CRC+PC), 14 bits
            boolean result = mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, 14, maskHex);

            if (result) {
                Log.d(TAG, "✓ Hardware filter set for FilterValue " + filterValue);
            } else {
                // Hardware filter not supported on this device - client-side filter will be
                // used
                Log.w(TAG, "Hardware filter not supported, using client-side filter for FilterValue " + filterValue);
            }
            // Return true anyway - client-side filter will work
            return true;
        } catch (Exception e) {
            Log.e(TAG, "setFilterValueMask error", e);
            return false;
        }
    }

    /**
     * Clear all filters completely (including ATA filter)
     */
    public synchronized boolean clearAllFilters() {
        currentAtaFilterValue = -1;
        return clearAllFiltersInternal();
    }

    private synchronized boolean clearAllFiltersInternal() {
        if (mReader == null)
            return false;
        try {
            Log.d(TAG, "Clearing EPC filter");
            boolean result = mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
            if (!result) {
                // Hardware filter clear not supported - that's OK, no filter was active anyway
                Log.d(TAG, "Hardware filter clear returned false (may not be supported)");
            }
            return true; // Client-side will handle filtering
        } catch (Exception e) {
            Log.w(TAG, "clearAllFilters: " + e.getMessage());
            return true; // Return true anyway - client-side filter will work
        }
    }

    /**
     * Get current ATA filter value
     */
    public int getCurrentAtaFilterValue() {
        return currentAtaFilterValue;
    }

    // ==================== BARCODE ====================

    private boolean barcodeEnabled = false;
    private static boolean barcodeInitFailed = false;
    private static boolean barcodeInitInProgress = false;

    // Track if barcode was ever successfully opened
    private static boolean barcodeEverOpened = false;
    
    public boolean connectBarcode() {
        // Skip if already connected
        if (barcodeEnabled && barcodeDecoder != null) {
            Log.d(TAG, "connectBarcode: already connected, skipping");
            return true;
        }
        
        // Skip if already failed
        if (barcodeInitFailed) {
            Log.d(TAG, "connectBarcode: previously failed, skipping");
            return false;
        }
        
        // Skip if init in progress
        if (barcodeInitInProgress) {
            Log.d(TAG, "connectBarcode: init in progress, skipping");
            return false;
        }
        
        // If barcode was ever opened successfully, just reopen without factory call
        if (barcodeEverOpened && barcodeDecoder != null) {
            Log.d(TAG, "connectBarcode: reopening existing decoder");
            try {
                barcodeDecoder.open(context);
                // Re-register decode callback (lost after close/reopen cycle)
                barcodeDecoder.setDecodeCallback(entity -> {
                    synchronized (barcodeLock) {
                        if (entity.getResultCode() == BarcodeDecoder.DECODE_SUCCESS) {
                            scannedBarcode = entity.getBarcodeData();
                            Log.d(TAG, "Decode SUCCESS: " + scannedBarcode);
                        } else {
                            scannedBarcode = "";
                        }
                    }
                });
                barcodeEnabled = true;
                barcodeClosed = false;
                Log.d(TAG, "connectBarcode: reopened SUCCESS");
                return true;
            } catch (Exception e) {
                Log.e(TAG, "connectBarcode reopen failed: " + e.getMessage());
                // Fall through to try factory again
            }
        }
        
        barcodeInitInProgress = true;
        Log.d(TAG, "connectBarcode: initializing...");
        
        if (barcodeDecoder == null) {
            try {
                barcodeDecoder = BarcodeFactory.getInstance().getBarcodeDecoder();
                if (barcodeDecoder == null) {
                    Log.e(TAG, "BarcodeFactory returned null");
                    barcodeInitFailed = true;
                    barcodeInitInProgress = false;
                    return false;
                }
            } catch (Exception | Error e) {
                Log.e(TAG, "BarcodeFactory failed: " + e.getMessage());
                barcodeInitFailed = true;
                barcodeInitInProgress = false;
                return false;
            }
        }
        if (barcodeDecoder != null) {
            Log.d(TAG, "Barcode open()");

            if (context != null) {
                try {
                    BarcodeUtility.getInstance().openKeyboardHelper(context);
                    BarcodeUtility.getInstance().open(context, BarcodeUtility.ModuleType.BARCODE_2D);
                } catch (Exception e) {
                    // Ignore
                }
            }

            try {
                barcodeDecoder.open(context);
            } catch (Exception e) {
                Log.e(TAG, "barcodeDecoder.open failed: " + e.getMessage());
                barcodeInitFailed = true;
                barcodeInitInProgress = false;
                return false;
            }
            
            barcodeDecoder.setDecodeCallback(entity -> {
                synchronized (barcodeLock) {
                    if (entity.getResultCode() == BarcodeDecoder.DECODE_SUCCESS) {
                        scannedBarcode = entity.getBarcodeData();
                        Log.d(TAG, "Decode SUCCESS: " + scannedBarcode);
                    } else {
                        scannedBarcode = "";
                    }
                }
            });
            barcodeEnabled = true;
            barcodeClosed = false;
            barcodeEverOpened = true;
            barcodeInitInProgress = false;
            Log.d(TAG, "connectBarcode: SUCCESS");
            return true;
        }
        barcodeInitInProgress = false;
        Log.e(TAG, "Barcode decoder is null");
        return false;
    }

    public boolean scanBarcode() {
        if (barcodeDecoder != null && barcodeEnabled) {
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

    private static boolean barcodeClosed = true; // Track if already closed
    
    public boolean closeScan() {
        // Skip if already closed
        if (barcodeClosed) {
            return true;
        }
        
        Log.d(TAG, "closeScan() - disabling barcode/laser");
        barcodeEnabled = false;

        // First, stop any active scan
        if (barcodeDecoder != null) {
            try {
                barcodeDecoder.stopScan();
            } catch (Exception e) {
                Log.w(TAG, "stopScan error: " + e.getMessage());
            }
        }

        // Close keyboard helper
        if (context != null) {
            try {
                BarcodeUtility.getInstance().closeKeyboardHelper(context);
            } catch (Exception e) {
                Log.w(TAG, "closeKeyboardHelper error: " + e.getMessage());
            }

            try {
                // Close barcode module (this should turn off laser)
                BarcodeUtility.getInstance().close(context, BarcodeUtility.ModuleType.BARCODE_2D);
                Log.d(TAG, "✓ Barcode 2D module closed");
            } catch (Exception e) {
                Log.w(TAG, "close BARCODE_2D error: " + e.getMessage());
            }

            try {
                // Also try to close 1D barcode module if it exists
                BarcodeUtility.getInstance().close(context, BarcodeUtility.ModuleType.BARCODE_1D);
                Log.d(TAG, "✓ Barcode 1D module closed");
            } catch (Exception e) {
                // 1D module may not exist on all devices, ignore
            }
        }

        // Close the decoder but KEEP the reference for faster re-open
        if (barcodeDecoder != null) {
            try {
                barcodeDecoder.setDecodeCallback(null);
                barcodeDecoder.close();
                Log.d(TAG, "✓ BarcodeDecoder closed");
                // DON'T set barcodeDecoder = null - we can reuse it
            } catch (Exception e) {
                Log.e(TAG, "closeScan decoder error: " + e.getMessage());
            }
        }

        barcodeClosed = true;
        Log.d(TAG, "closeScan() complete");
        return true;
    }

    public String readBarcode() {
        synchronized (barcodeLock) {
            String result = (scannedBarcode != null) ? scannedBarcode : "";
            // Clear after read to avoid duplicate reads
            if (!result.isEmpty()) {
                scannedBarcode = "";
            }
            return result;
        }
    }

    public boolean isBarcodeEnabled() {
        return barcodeEnabled;
    }

    /**
     * Force-close the keyboard helper and barcode modules regardless of state.
     * Used when switching to RFID mode to ensure the hardware trigger
     * doesn't activate the barcode laser.
     */
    public void disableLaser() {
        if (context == null) return;
        try {
            BarcodeUtility.getInstance().closeKeyboardHelper(context);
        } catch (Exception e) {
            // ignore
        }
        try {
            BarcodeUtility.getInstance().close(context, BarcodeUtility.ModuleType.BARCODE_2D);
        } catch (Exception e) {
            // ignore
        }
        try {
            BarcodeUtility.getInstance().close(context, BarcodeUtility.ModuleType.BARCODE_1D);
        } catch (Exception e) {
            // ignore
        }
        Log.d(TAG, "disableLaser() - keyboard helper and barcode modules closed");
    }

    // ==================== SOUND ====================

    public boolean playSound() {
        MediaPlayer.create(context, R.raw.barcodebeep).start();
        return true;
    }

    public void playErrorSound() {
        MediaPlayer.create(context, R.raw.serror).start();
    }
}
