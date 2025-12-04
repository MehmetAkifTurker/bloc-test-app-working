package SDKMethods.core;

import android.content.Context;
import android.media.MediaPlayer;
import android.util.Log;

import com.example.water_boiler_rfid_labeler.R;
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

    private UHFManager() {}

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

    public boolean connect() {
        try {
            mReader = RFIDWithUHFUART.getInstance();
        } catch (Exception ex) {
            Log.e(TAG, "RFIDWithUHFUART getInstance failed", ex);
            if (uhfListener != null) uhfListener.onConnect(false, 0);
            return false;
        }

        if (mReader == null) {
            if (uhfListener != null) uhfListener.onConnect(false, 0);
            return false;
        }

        isConnect = mReader.init(context);
        if (uhfListener != null) uhfListener.onConnect(isConnect, 0);

        if (isConnect) {
            configureReader();
        }
        return isConnect;
    }

    private void configureReader() {
        try {
            // Configure EPC+TID+USER simultaneous reading (128 words)
            boolean allModeSet = mReader.setEPCAndTIDUserMode(0, 128);
            if (!allModeSet) {
                Log.w(TAG, "Failed to set EPC+TID+USER mode");
            }
            Thread.sleep(100);
        } catch (Exception e) {
            Log.e(TAG, "Failed to configure scanning mode: " + e.getMessage());
        }

        try {
            mReader.setTagFocus(true);
        } catch (Exception ignore) {}

        try {
            mReader.setFastID(false);
        } catch (Exception ignore) {}
    }

    public void close() {
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
            int pwr = Integer.parseInt(level);
            return mReader.setPower(pwr);
        }
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

    public synchronized boolean setEpcFilter(String epcHex) {
        if (mReader == null) return false;
        try {
            int bits = epcHex != null ? epcHex.length() * 4 : 0;
            if (bits <= 0) return false;
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, bits, epcHex);
        } catch (Exception e) {
            Log.e(TAG, "setEpcFilter error", e);
            return false;
        }
    }

    public synchronized boolean clearFilter() {
        if (mReader == null) return false;
        try {
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
        } catch (Exception e) {
            Log.e(TAG, "clearFilter error", e);
            return false;
        }
    }

    // ==================== BARCODE ====================
    
    private boolean barcodeEnabled = false;

    public boolean connectBarcode() {
        if (barcodeDecoder == null) {
            barcodeDecoder = BarcodeFactory.getInstance().getBarcodeDecoder();
        }
        if (barcodeDecoder != null) {
            Log.d(TAG, "Barcode open()");
            
            // Önce Keyboard Helper'ı aç (barkod tarama için gerekli)
            if (context != null) {
                try {
                    BarcodeUtility.getInstance().openKeyboardHelper(context);
                    BarcodeUtility.getInstance().open(context, BarcodeUtility.ModuleType.BARCODE_2D);
                } catch (Exception e) {
                    Log.w(TAG, "openKeyboardHelper error: " + e.getMessage());
                }
            }
            
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
            barcodeEnabled = true;
            return true;
        }
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

    public boolean closeScan() {
        Log.d(TAG, "closeScan() called");
        barcodeEnabled = false;
        
        // Sistem seviyesinde Keyboard Helper'ı kapat (tetik ile barkod taramayı engeller)
        if (context != null) {
            try {
                BarcodeUtility.getInstance().closeKeyboardHelper(context);
                BarcodeUtility.getInstance().close(context, BarcodeUtility.ModuleType.BARCODE_2D);
                Log.d(TAG, "Keyboard Helper closed");
            } catch (Exception e) {
                Log.w(TAG, "closeKeyboardHelper error: " + e.getMessage());
            }
        }
        
        if (barcodeDecoder != null) {
            try {
                barcodeDecoder.stopScan();
                barcodeDecoder.setDecodeCallback(null);
                barcodeDecoder.close();
            } catch (Exception e) {
                Log.e(TAG, "closeScan error: " + e.getMessage());
            }
            barcodeDecoder = null;
        }
        return true;
    }

    public String readBarcode() {
        return (scannedBarcode != null) ? scannedBarcode : "";
    }
    
    public boolean isBarcodeEnabled() {
        return barcodeEnabled;
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

