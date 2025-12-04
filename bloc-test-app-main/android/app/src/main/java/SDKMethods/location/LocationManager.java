package SDKMethods.location;

import android.content.Context;
import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.interfaces.IUHFLocationCallback;

import io.flutter.plugin.common.EventChannel;

import SDKMethods.core.UHFManager;
import SDKMethods.inventory.InventoryManager;

/**
 * Location Manager - Handles tag location/finding feature
 */
public class LocationManager {
    private static final String TAG = "LocationManager";
    
    private static LocationManager instance;
    private static EventChannel.EventSink locationSink;
    private int lastPowerLevel = 5;

    private LocationManager() {}

    public static synchronized LocationManager getInstance() {
        if (instance == null) {
            instance = new LocationManager();
        }
        return instance;
    }

    public static void setLocationSink(EventChannel.EventSink sink) {
        locationSink = sink;
    }

    public boolean startLocation(Context context, String label, int bank, int ptr) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "mReader is null; cannot start location!");
            return false;
        }
        
        try {
            // Stop any ongoing inventory
            if (InventoryManager.getInstance().isStarted()) {
                reader.stopInventory();
            }

            // Clear filters
            try {
                UHFManager.getInstance().clearFilter();
                Thread.sleep(100);
            } catch (Exception e) {
                Log.w(TAG, "Failed to clear filter: " + e.getMessage());
            }

            // Increase power for better location
            lastPowerLevel = reader.getPower();
            reader.setPower(30);

            Log.i(TAG, "Starting location for EPC: " + label + " at bank=" + bank + " ptr=" + ptr);
            
            return reader.startLocation(context, label, bank, ptr, new IUHFLocationCallback() {
                @Override
                public void getLocationValue(int value) {
                    Log.i(TAG, "Location signal strength: " + value);
                    if (locationSink != null) {
                        locationSink.success(value);
                    }
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "Error starting location: " + e.getMessage(), e);
            return false;
        }
    }

    public boolean stopLocation() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "mReader is null; cannot stop location!");
            return false;
        }
        
        try {
            // Restore original power level
            reader.setPower(lastPowerLevel);
            return reader.stopLocation();
        } catch (Exception e) {
            Log.e(TAG, "Error stopping location: " + e.getMessage(), e);
            return false;
        }
    }

    public interface TagLocateListener {
        void onLocateValue(int value);
    }
}

