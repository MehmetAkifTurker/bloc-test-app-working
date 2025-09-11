package com.example.my_rfid_plugin;

import android.util.Log;
import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;

/**
 * Simplified UHF Helper based on official SDK documentation
 * Focus: Clean and simple reading experience without complications
 */
public class UHFHelperSimple {
    private static final String TAG = "UHFHelperSimple";
    private RFIDWithUHFUART mReader;
    private boolean isInventoryRunning = false;

    public UHFHelperSimple(RFIDWithUHFUART reader) {
        this.mReader = reader;
    }

    /**
     * Simple, reliable USER memory read for specific EPC
     * Based on official SDK documentation patterns
     */
    public synchronized String readUserMemoryForEpc(String epcHex) {
        if (mReader == null || epcHex == null || epcHex.isEmpty()) {
            return "";
        }

        Log.i(TAG, "Reading USER memory for: " + epcHex);

        try {
            // Stop any ongoing operations
            pauseInventoryIfNeeded();

            String accessPwd = "00000000";
            int epcBits = epcHex.length() * 4;

            // Method 1: Direct EPC-matched read (primary SDK approach)
            String result = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, 32,
                    epcHex, RFIDWithUHFUART.Bank_EPC, 32, epcBits);

            if (isValidUserMemory(result)) {
                Log.i(TAG, "SUCCESS: Direct read for " + epcHex);
                return result;
            }

            // Method 2: Filter-based read (fallback)
            if (setFilter(epcHex)) {
                Thread.sleep(50); // Allow filter to take effect
                result = mReader.readData(accessPwd, RFIDWithUHFUART.Bank_USER, 0, 32);
                clearFilter();

                if (isValidUserMemory(result)) {
                    Log.i(TAG, "SUCCESS: Filtered read for " + epcHex);
                    return result;
                }
            }

            Log.w(TAG, "USER memory read failed for: " + epcHex);
            return "";

        } catch (Exception e) {
            Log.e(TAG, "Error reading USER memory: " + e.getMessage());
            return "";
        } finally {
            // Always clean up
            clearFilter();
            resumeInventoryIfNeeded();
        }
    }

    /**
     * Simple single tag read
     */
    public String readSingleTagEpc() {
        if (mReader == null)
            return "";

        try {
            UHFTAGInfo info = mReader.inventorySingleTag();
            return info != null ? info.getEPC() : "";
        } catch (Exception e) {
            Log.e(TAG, "Single tag read error: " + e.getMessage());
            return "";
        }
    }

    // Helper methods for clean operation
    private void pauseInventoryIfNeeded() {
        try {
            if (mReader.isWorking()) {
                isInventoryRunning = true;
                mReader.stopInventory();
                Thread.sleep(30);
            }
        } catch (Exception e) {
            Log.w(TAG, "Pause inventory error: " + e.getMessage());
        }
    }

    private void resumeInventoryIfNeeded() {
        try {
            if (isInventoryRunning) {
                mReader.startInventoryTag();
                isInventoryRunning = false;
            }
        } catch (Exception e) {
            Log.w(TAG, "Resume inventory error: " + e.getMessage());
        }
    }

    private boolean setFilter(String epcHex) {
        try {
            int bits = epcHex.length() * 4;
            return mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 32, bits, epcHex);
        } catch (Exception e) {
            Log.w(TAG, "Set filter error: " + e.getMessage());
            return false;
        }
    }

    private void clearFilter() {
        try {
            mReader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
        } catch (Exception e) {
            Log.w(TAG, "Clear filter error: " + e.getMessage());
        }
    }

    private boolean isValidUserMemory(String hex) {
        return hex != null && hex.length() >= 16;
    }
}
