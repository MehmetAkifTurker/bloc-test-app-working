package SDKMethods.location;

import android.content.Context;
import android.media.AudioManager;
import android.media.ToneGenerator;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;
import com.rscja.deviceapi.interfaces.IUHFLocationCallback;

import io.flutter.plugin.common.EventChannel;

import SDKMethods.core.UHFManager;
import SDKMethods.inventory.InventoryManager;

/**
 * Location Manager - Handles tag location/finding feature
 * 
 * Uses polling-based RSSI reading for tag location.
 * Native SDK startLocation doesn't work reliably on C66P.
 * 
 * Features:
 * - Moving average smoothing (last 3 readings)
 * - Maximum change limiter (prevents jumps > 40)
 * - Native beep sound via ToneGenerator (STREAM_MUSIC for volume button control)
 */
public class LocationManager {
    private static final String TAG = "LocationManager";
    
    private static LocationManager instance;
    private static EventChannel.EventSink locationSink;
    private static Context appContext;
    
    // Polling fallback
    private volatile boolean isLocating = false;
    private Thread pollingThread;
    private String targetEpc;
    private Handler mainHandler;
    
    // Signal smoothing (moving average)
    private static final int SMOOTH_WINDOW = 3;
    private final int[] signalHistory = new int[SMOOTH_WINDOW];
    private int historyIndex = 0;
    private int historyCount = 0;
    private int lastSmoothedSignal = 50;
    
    // Maximum change per update (prevents wild jumps)
    private static final int MAX_CHANGE_PER_UPDATE = 40;
    
    // Sound - using ToneGenerator with STREAM_MUSIC for volume button control
    private ToneGenerator toneGenerator;
    private AudioManager audioManager;
    
    private volatile boolean soundEnabled = false;
    private volatile int currentSignalForBeep = 0;
    private volatile long lastTagReadTime = 0;
    private Thread beepThread;
    private volatile boolean beepThreadRunning = false;
    
    // Track last sent signal to Flutter (for "no signal" updates)
    private volatile int lastSentSignal = -1;
    
    // Native vs polling mode
    // NOTE: SDK native startLocation callback doesn't work on C66P device
    // It returns true but never calls getLocationValue callback
    // Disabled by default - using polling with 30 dBm power instead
    private boolean useNativeLocation = false; // Disabled - callback doesn't work on C66P
    private boolean nativeLocationActive = false;
    
    // Beep settings
    private static final int BEEP_DURATION_MS = 100;
    private static final long TAG_TIMEOUT_MS = 1500;
    private static final long SIGNAL_TIMEOUT_MS = 2000; // Send 0 signal if no tag for 2s

    private LocationManager() {
        mainHandler = new Handler(Looper.getMainLooper());
    }
    
    /**
     * Set app context for sound initialization
     */
    public static void setContext(Context context) {
        appContext = context.getApplicationContext();
        Log.d(TAG, "Context set for sound");
    }
    
    /**
     * Initialize sound systems - call after context is set
     */
    private void initSound() {
        if (toneGenerator != null) {
            Log.d(TAG, "Sound already initialized");
            return;
        }
        
        Log.d(TAG, "🔊 Initializing sound systems...");
        
        // Get AudioManager for volume info
        if (appContext != null) {
            audioManager = (AudioManager) appContext.getSystemService(Context.AUDIO_SERVICE);
            if (audioManager != null) {
                int vol = audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
                int maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
                Log.d(TAG, "🔊 AudioManager ready, MUSIC volume: " + vol + "/" + maxVol);
                
                if (vol == 0) {
                    Log.w(TAG, "⚠️ MUSIC volume is 0! Sound will not be audible. Use device volume buttons.");
                }
            }
        }
        
        // Initialize ToneGenerator with STREAM_MUSIC for volume button control
        try {
            // Use MAX_VOLUME (100) - actual volume controlled by system STREAM_MUSIC
            toneGenerator = new ToneGenerator(AudioManager.STREAM_MUSIC, ToneGenerator.MAX_VOLUME);
            Log.d(TAG, "✓ ToneGenerator initialized with STREAM_MUSIC (volume buttons work)");
        } catch (Exception e) {
            Log.e(TAG, "ToneGenerator init failed: " + e.getMessage());
        }
    }
    
    /**
     * Play a beep sound
     * Uses ToneGenerator with STREAM_MUSIC for volume button control
     * Volume is controlled by device's media volume buttons
     */
    private void playBeep() {
        // Ensure ToneGenerator is initialized
        if (toneGenerator == null) {
            initSound();
        }
        
        if (toneGenerator == null) {
            Log.e(TAG, "ToneGenerator is null, cannot play beep");
            return;
        }
        
        // Try different tones for device compatibility
        // TONE_PROP_BEEP is the most common, TONE_DTMF_1 is a fallback
        int[] tonesToTry = {
            ToneGenerator.TONE_PROP_BEEP,          // Standard proprietary beep
            ToneGenerator.TONE_CDMA_ALERT_CALL_GUARD, // CDMA alert
            ToneGenerator.TONE_DTMF_1,              // DTMF 1 (always works)
        };
        
        for (int tone : tonesToTry) {
            try {
                toneGenerator.startTone(tone, BEEP_DURATION_MS);
                return; // Success - exit
            } catch (Exception e) {
                // Try next tone type
            }
        }
        
        // If all failed, try to reinitialize
        try {
            toneGenerator.release();
            toneGenerator = new ToneGenerator(AudioManager.STREAM_MUSIC, ToneGenerator.MAX_VOLUME);
            toneGenerator.startTone(ToneGenerator.TONE_DTMF_1, BEEP_DURATION_MS);
            Log.d(TAG, "Reinitialized ToneGenerator");
        } catch (Exception e) {
            Log.e(TAG, "All beep attempts failed: " + e.getMessage());
        }
    }

    public static synchronized LocationManager getInstance() {
        if (instance == null) {
            instance = new LocationManager();
        }
        return instance;
    }

    public static void setLocationSink(EventChannel.EventSink sink) {
        locationSink = sink;
    }
    
    /**
     * Enable/disable sound during location
     */
    public void setSoundEnabled(boolean enabled) {
        Log.d(TAG, "🔊 setSoundEnabled(" + enabled + ") called, isLocating=" + isLocating);
        this.soundEnabled = enabled;
        
        if (enabled) {
            // Initialize sound systems if not done yet
            initSound();
            
            // Play a test beep immediately to confirm sound is working
            Log.d(TAG, "🔊 Playing test beep to confirm sound works...");
            playBeep();
            
            if (isLocating) {
                Log.d(TAG, "🔊 Sound enabled while locating - starting beep thread");
                startBeepThread();
            } else {
                Log.d(TAG, "🔊 Sound enabled but not locating yet - will start when location starts");
            }
        } else {
            Log.d(TAG, "🔇 Sound disabled - stopping beep thread");
            stopBeepThread();
        }
    }
    
    /**
     * Start the continuous beep thread
     * Beeps at interval based on signal strength (closer = faster beeps)
     * Only beeps when a tag was recently read (within TAG_TIMEOUT_MS)
     */
    private void startBeepThread() {
        if (beepThreadRunning) {
            Log.d(TAG, "Beep thread already running");
            return;
        }
        
        // Initialize sound if needed
        initSound();
        
        beepThreadRunning = true;
        
        beepThread = new Thread(() -> {
            Log.d(TAG, "🔊 Beep thread STARTED (soundEnabled=" + soundEnabled + ", isLocating=" + isLocating + ")");
            int beepCount = 0;
            int lastLoggedSignal = -1;
            boolean wasBeeping = false;
            
            // Play initial beep to confirm sound is working
            Log.d(TAG, "🔊 Playing initial confirmation beep...");
            playBeep();
            beepCount++;
            
            while (beepThreadRunning && soundEnabled && isLocating) {
                try {
                    long timeSinceLastRead = System.currentTimeMillis() - lastTagReadTime;
                    int signal = currentSignalForBeep;
                    
                    // Only beep if we've seen a tag recently
                    if (timeSinceLastRead < TAG_TIMEOUT_MS && signal > 0) {
                        beepCount++;
                        
                        // Play beep
                        playBeep();
                        
                        // Log when signal changes significantly or on first beep
                        if (Math.abs(signal - lastLoggedSignal) >= 5 || !wasBeeping) {
                            Log.d(TAG, "🔊 Beep #" + beepCount + " signal=" + signal + " interval=" + calculateInterval(signal) + "ms");
                            lastLoggedSignal = signal;
                        }
                        wasBeeping = true;
                        
                        // Wait based on signal strength (closer = faster beeps)
                        int interval = calculateInterval(signal);
                        Thread.sleep(interval);
                    } else {
                        // No tag seen recently - don't beep, just wait
                        if (wasBeeping) {
                            Log.d(TAG, "🔇 No tag detected (timeout=" + timeSinceLastRead + "ms) - pausing beep");
                            wasBeeping = false;
                            lastLoggedSignal = -1;
                        }
                        Thread.sleep(200); // Check again in 200ms
                    }
                    
                } catch (InterruptedException e) {
                    Log.d(TAG, "Beep thread interrupted");
                    break;
                } catch (Exception e) {
                    Log.w(TAG, "Beep error: " + e.getMessage());
                    try { Thread.sleep(500); } catch (Exception ignored) {}
                }
            }
            Log.d(TAG, "🔊 Beep thread STOPPED (total beeps: " + beepCount + ", soundEnabled=" + soundEnabled + ", isLocating=" + isLocating + ")");
            beepThreadRunning = false;
        });
        beepThread.setName("LocationBeepThread");
        beepThread.start();
    }
    
    /**
     * Calculate beep interval based on signal strength
     * Signal 100 (very close) -> 100ms (very fast)
     * Signal 50 (medium)      -> 550ms 
     * Signal 0 (far)          -> 1000ms (slow)
     */
    private int calculateInterval(int signal) {
        // Linear mapping: signal 0->1000ms, signal 100->100ms
        int interval = 1000 - (signal * 9);
        return Math.max(100, Math.min(1000, interval));
    }
    
    /**
     * Stop the beep thread
     */
    private void stopBeepThread() {
        beepThreadRunning = false;
        if (beepThread != null) {
            beepThread.interrupt();
            try {
                beepThread.join(300);
            } catch (InterruptedException ignored) {}
            beepThread = null;
        }
    }
    
    /**
     * Reset smoothing history (call when starting new location)
     */
    private void resetSmoothing() {
        historyIndex = 0;
        historyCount = 0;
        lastSmoothedSignal = 50;
        for (int i = 0; i < SMOOTH_WINDOW; i++) {
            signalHistory[i] = 0;
        }
    }
    
    /**
     * Add value to history and return smoothed (averaged) signal
     */
    private int smoothSignal(int rawSignal) {
        // Add to circular buffer
        signalHistory[historyIndex] = rawSignal;
        historyIndex = (historyIndex + 1) % SMOOTH_WINDOW;
        if (historyCount < SMOOTH_WINDOW) historyCount++;
        
        // Calculate average
        int sum = 0;
        for (int i = 0; i < historyCount; i++) {
            sum += signalHistory[i];
        }
        int averaged = sum / historyCount;
        
        // Limit maximum change per update (prevents wild jumps)
        int delta = averaged - lastSmoothedSignal;
        if (Math.abs(delta) > MAX_CHANGE_PER_UPDATE) {
            averaged = lastSmoothedSignal + (delta > 0 ? MAX_CHANGE_PER_UPDATE : -MAX_CHANGE_PER_UPDATE);
        }
        
        lastSmoothedSignal = averaged;
        return averaged;
    }
    
    /**
     * Update the signal value used by beep thread
     * This controls the beep interval (higher signal = faster beeps)
     * Also updates the timestamp so beep thread knows we have a recent reading
     */
    private void updateBeepSignal(int signal) {
        currentSignalForBeep = signal;
        lastTagReadTime = System.currentTimeMillis();
    }

    /**
     * Remove trailing zeros from EPC (padding)
     */
    private String cleanEpc(String epc) {
        if (epc == null) return "";
        // Remove trailing "0000" padding (ATA EPC padding)
        String cleaned = epc.toUpperCase();
        while (cleaned.endsWith("0000") && cleaned.length() > 8) {
            cleaned = cleaned.substring(0, cleaned.length() - 4);
        }
        return cleaned;
    }

    // Store original power to restore when location stops
    private int originalPower = -1;
    private static final int LOCATION_POWER = 30; // Maximum power for location (30 dBm)
    
    public boolean startLocation(Context context, String label, int bank, int ptr) {
        Log.d(TAG, "startLocation called, soundEnabled=" + soundEnabled);
        
        // Save context for sound initialization
        if (context != null && appContext == null) {
            setContext(context);
        }
        
        // Initialize sound systems
        initSound();
        
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "mReader is null; cannot start location!");
            return false;
        }
        
        // Clean EPC - remove trailing zeros
        String cleanedLabel = cleanEpc(label);
        targetEpc = cleanedLabel;
        
        try {
            // Stop any ongoing inventory first
            if (InventoryManager.getInstance().isStarted()) {
                reader.stopInventory();
                Thread.sleep(100);
            }

            // Set power to maximum for better location range.
            // Capture the ORIGINAL power only once (originalPower == -1); a re-entry
            // while already at LOCATION_POWER must not overwrite the real value, or
            // stopLocation would "restore" to 30 dBm and lose the user's setting.
            try {
                if (originalPower == -1) {
                    originalPower = reader.getPower();
                    Log.d(TAG, "📡 Original power: " + originalPower + " dBm");
                }
                if (reader.getPower() != LOCATION_POWER) {
                    boolean powerSet = reader.setPower(LOCATION_POWER);
                    Log.i(TAG, "📡 Set power to " + LOCATION_POWER + " dBm for location: " + (powerSet ? "SUCCESS" : "FAILED"));
                }
            } catch (Exception e) {
                Log.w(TAG, "Failed to set power: " + e.getMessage());
            }

            // Clear filters for location search
            try {
                reader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
                Thread.sleep(50);
            } catch (Exception e) {
                Log.w(TAG, "Failed to clear filter: " + e.getMessage());
            }

            Log.i(TAG, "Starting location for EPC: " + cleanedLabel + " (original: " + label + "), bank=" + bank + ", ptr=" + ptr);
            
            // Reset smoothing for new location session
            resetSmoothing();
            currentSignalForBeep = 0;   // Start with no signal (will only beep when tag is read)
            lastTagReadTime = 0;        // No tag read yet
            lastSentSignal = -1;        // Reset last sent signal
            nativeLocationActive = false;
            
            // Try SDK's native startLocation first (better power management)
            if (useNativeLocation) {
                try {
                    Log.d(TAG, "📡 Trying SDK native startLocation...");
                    boolean nativeStarted = reader.startLocation(context, cleanedLabel, bank, ptr, 
                        new IUHFLocationCallback() {
                            @Override
                            public void getLocationValue(int value) {
                                // Native SDK returns 0-100 signal value
                                Log.d(TAG, "📡 Native location callback: " + value);
                                
                                // Apply smoothing
                                int smoothedSignal = smoothSignal(value);
                                
                                // Update beep thread
                                updateBeepSignal(smoothedSignal);
                                
                                // Send to Flutter
                                sendSignal(smoothedSignal);
                            }
                        });
                    
                    if (nativeStarted) {
                        Log.i(TAG, "✓ SDK native location STARTED successfully");
                        nativeLocationActive = true;
                        isLocating = true;
                        
                        // Start timeout monitor thread for "no signal" updates
                        startTimeoutMonitor();
                    } else {
                        Log.w(TAG, "SDK native location returned false, falling back to polling");
                    }
                } catch (Exception e) {
                    Log.w(TAG, "SDK native location failed: " + e.getMessage() + ", falling back to polling");
                }
            }
            
            // Fall back to polling if native didn't work
            if (!nativeLocationActive) {
                Log.d(TAG, "📡 Using polling-based location...");
                startPollingFallback(reader);
            }
            
            // Start beep thread if sound is enabled
            Log.d(TAG, "🔊 Location started, soundEnabled=" + soundEnabled + ", isLocating=" + isLocating + ", native=" + nativeLocationActive);
            if (soundEnabled) {
                Log.d(TAG, "🔊 Starting beep thread...");
                // Play confirmation beep that location started
                playBeep();
                startBeepThread();
            } else {
                Log.d(TAG, "🔇 Sound not enabled, skipping beep thread");
            }
            
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error starting location: " + e.getMessage(), e);
            // Start failed: stopLocation won't be called by the UI, so restore the
            // power here, otherwise the reader stays stuck at LOCATION_POWER (30 dBm)
            // and subsequent scanning runs at the wrong power.
            try {
                if (originalPower > 0) {
                    reader.setPower(originalPower);
                    Log.d(TAG, "📡 Restored power to " + originalPower + " dBm after failed start");
                    originalPower = -1;
                }
            } catch (Exception ignored) {}
            isLocating = false;
            return false;
        }
    }
    
    /**
     * Timeout monitor for native location mode
     * Sends 0 signal when no tag detected for a while
     */
    private Thread timeoutMonitorThread;
    
    private void startTimeoutMonitor() {
        if (timeoutMonitorThread != null && timeoutMonitorThread.isAlive()) {
            return;
        }
        
        timeoutMonitorThread = new Thread(() -> {
            Log.d(TAG, "📡 Timeout monitor started");
            while (isLocating && nativeLocationActive) {
                try {
                    Thread.sleep(500); // Check every 500ms
                    
                    long timeSinceLastRead = System.currentTimeMillis() - lastTagReadTime;
                    if (lastTagReadTime > 0 && timeSinceLastRead > SIGNAL_TIMEOUT_MS) {
                        if (lastSentSignal != 0) {
                            Log.d(TAG, "📡 Tag out of range (native) for " + timeSinceLastRead + "ms - sending signal 0");
                            sendSignal(0);
                            currentSignalForBeep = 0;
                        }
                    }
                } catch (InterruptedException e) {
                    break;
                }
            }
            Log.d(TAG, "📡 Timeout monitor stopped");
        });
        timeoutMonitorThread.setName("LocationTimeoutMonitor");
        timeoutMonitorThread.start();
    }
    
    /**
     * Polling-based location using RSSI
     * Uses EPC filter for focused detection of target tag
     */
    private void startPollingFallback(RFIDWithUHFUART reader) {
        if (isLocating) {
            Log.d(TAG, "Already locating, skipping");
            return;
        }
        isLocating = true;
        
        // Set filter for target EPC to improve detection
        // Filter on EPC bank (1), starting at bit 32 (after PC), for the EPC length
        try {
            int filterBits = targetEpc.length() * 4; // Each hex char = 4 bits
            boolean filterSet = reader.setFilter(
                RFIDWithUHFUART.Bank_EPC,  // Filter on EPC bank
                32,                         // Start after PC (2 words = 32 bits)
                filterBits,                 // Filter length in bits
                targetEpc                   // EPC data to filter
            );
            Log.d(TAG, "📡 EPC filter set: " + (filterSet ? "SUCCESS" : "FAILED") + 
                       " (EPC=" + targetEpc.substring(0, Math.min(16, targetEpc.length())) + "..., bits=" + filterBits + ")");
        } catch (Exception e) {
            Log.w(TAG, "Failed to set EPC filter: " + e.getMessage());
        }
        
        pollingThread = new Thread(() -> {
            Log.d(TAG, "📡 Polling started for EPC: " + targetEpc + " (with filter, power=30dBm)");
            int readCount = 0;
            int matchCount = 0;
            
            while (isLocating) {
                try {
                    // Read a single tag (filter already set for target EPC)
                    UHFTAGInfo tagInfo = reader.inventorySingleTag();
                    readCount++;
                    
                    if (tagInfo != null && tagInfo.getEPC() != null) {
                        String readEpc = cleanEpc(tagInfo.getEPC());
                        
                        // Log every 10th read for debugging
                        if (readCount % 10 == 1) {
                            Log.d(TAG, "Read #" + readCount + ": " + readEpc.substring(0, Math.min(16, readEpc.length())) + "...");
                        }
                        
                        // Check if this is our target tag using prefix matching
                        // Compare first 8 chars (4 bytes) as minimum identifier
                        boolean isMatch = false;
                        int minLen = Math.min(8, Math.min(targetEpc.length(), readEpc.length()));
                        if (minLen >= 4) {
                            String targetPrefix = targetEpc.substring(0, minLen);
                            String readPrefix = readEpc.substring(0, minLen);
                            isMatch = targetPrefix.equalsIgnoreCase(readPrefix);
                        }
                        
                        // Also check longer prefixes if available
                        if (!isMatch && targetEpc.length() >= 16 && readEpc.length() >= 16) {
                            String targetPrefix = targetEpc.substring(0, 16);
                            String readPrefix = readEpc.substring(0, 16);
                            isMatch = targetPrefix.equalsIgnoreCase(readPrefix);
                        }
                        
                        if (isMatch) {
                            matchCount++;
                            
                            // Get RSSI and convert to 0-100 scale
                            String rssiStr = tagInfo.getRssi();
                            double rssiValue = 50.0; // Default
                            try {
                                // RSSI can be "-28.40" or "-67.00" - parse as double
                                rssiValue = Math.abs(Double.parseDouble(rssiStr));
                            } catch (Exception e) {
                                // Fallback: try to extract number
                                try {
                                    String cleaned = rssiStr.replaceAll("[^0-9.]", "");
                                    rssiValue = Double.parseDouble(cleaned);
                                } catch (Exception e2) {
                                    // Skip this reading if RSSI can't be parsed
                                    continue;
                                }
                            }
                            
                            // Convert RSSI to signal strength (0-100)
                            // RSSI typically ranges from -25 (very strong) to -70 (weak)
                            // We map: rssi 25 -> signal 100, rssi 70 -> signal 0
                            int rawSignal = (int) Math.max(0, Math.min(100, (70 - rssiValue) * 100 / 45));
                            
                            // Apply smoothing (moving average + change limiter)
                            int smoothedSignal = smoothSignal(rawSignal);
                            
                            // Update beep thread's signal (controls beep speed)
                            updateBeepSignal(smoothedSignal);
                            
                            // Log every 5th match
                            if (matchCount % 5 == 1) {
                                Log.d(TAG, "📍 #" + matchCount + " Raw:" + rawSignal + " Smooth:" + smoothedSignal + " (RSSI:" + rssiStr + ")");
                            }
                            
                            sendSignal(smoothedSignal);
                        }
                    }
                    
                    // Check if tag has been out of range - send 0 signal to update UI
                    long timeSinceLastRead = System.currentTimeMillis() - lastTagReadTime;
                    if (lastTagReadTime > 0 && timeSinceLastRead > SIGNAL_TIMEOUT_MS) {
                        // Tag is out of range - send 0 signal if we haven't already
                        if (lastSentSignal != 0) {
                            Log.d(TAG, "📡 Tag out of range for " + timeSinceLastRead + "ms - sending signal 0");
                            sendSignal(0);
                            currentSignalForBeep = 0; // Also update beep thread
                        }
                    }
                    
                    Thread.sleep(80); // Poll every 80ms (faster updates!)
                } catch (InterruptedException e) {
                    Log.d(TAG, "Polling interrupted");
                    break;
                } catch (Exception e) {
                    Log.w(TAG, "Polling error: " + e.getMessage());
                    try { Thread.sleep(300); } catch (Exception ignored) {}
                }
            }
            
            Log.d(TAG, "📡 Polling stopped (reads: " + readCount + ", matches: " + matchCount + ")");
        });
        pollingThread.start();
    }
    
    private void sendSignal(int value) {
        lastSentSignal = value; // Track last sent signal
        mainHandler.post(() -> {
            if (locationSink != null) {
                locationSink.success(value);
            }
        });
    }

    public boolean stopLocation() {
        Log.d(TAG, "Stopping location (native=" + nativeLocationActive + ")...");
        isLocating = false;
        soundEnabled = false;
        
        // Stop beep thread first
        stopBeepThread();
        
        // Stop timeout monitor thread
        if (timeoutMonitorThread != null) {
            timeoutMonitorThread.interrupt();
            try {
                timeoutMonitorThread.join(300);
            } catch (InterruptedException ignored) {}
            timeoutMonitorThread = null;
        }
        
        // Stop native SDK location if active
        if (nativeLocationActive) {
            try {
                RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
                if (reader != null) {
                    boolean stopped = reader.stopLocation();
                    Log.d(TAG, "📡 SDK stopLocation: " + (stopped ? "SUCCESS" : "FAILED"));
                }
            } catch (Exception e) {
                Log.w(TAG, "SDK stopLocation error: " + e.getMessage());
            }
            nativeLocationActive = false;
        }
        
        // Stop polling thread
        if (pollingThread != null) {
            pollingThread.interrupt();
            try {
                pollingThread.join(500); // Wait max 500ms for thread to stop
            } catch (InterruptedException ignored) {}
            pollingThread = null;
        }
        
        // Clear EPC filter and restore original power level
        try {
            RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
            if (reader != null) {
                // Clear filter
                try {
                    reader.setFilter(RFIDWithUHFUART.Bank_EPC, 0, 0, "");
                    Log.d(TAG, "📡 EPC filter cleared");
                } catch (Exception e) {
                    Log.w(TAG, "Failed to clear filter: " + e.getMessage());
                }
                
                // Restore power
                if (originalPower > 0) {
                    boolean restored = reader.setPower(originalPower);
                    Log.d(TAG, "📡 Restored power to " + originalPower + " dBm: " + (restored ? "SUCCESS" : "FAILED"));
                    originalPower = -1;
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Cleanup error: " + e.getMessage());
        }
        
        Log.d(TAG, "Location stopped");
        return true;
    }
    
    /**
     * Cleanup resources
     */
    public void dispose() {
        Log.d(TAG, "dispose() called");
        stopLocation();
        stopBeepThread();
        
        if (toneGenerator != null) {
            try {
                toneGenerator.release();
            } catch (Exception ignored) {}
            toneGenerator = null;
        }
    }

    public interface TagLocateListener {
        void onLocateValue(int value);
    }
}

