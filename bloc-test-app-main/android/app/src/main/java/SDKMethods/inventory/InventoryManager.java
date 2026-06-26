package SDKMethods.inventory;

import android.os.Handler;
import android.os.Message;
import android.text.TextUtils;
import android.util.Log;

import com.rscja.deviceapi.RFIDWithUHFUART;
import com.rscja.deviceapi.entity.UHFTAGInfo;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Objects;

import SDKMethods.core.EPC;
import SDKMethods.core.TagKey;
import SDKMethods.core.UHFListener;
import SDKMethods.core.UHFManager;

/**
 * Inventory Manager - Handles tag scanning and inventory operations
 */
public class InventoryManager {
    private static final String TAG = "InventoryManager";
    
    private static InventoryManager instance;
    private HashMap<String, EPC> tagList;
    private boolean isStart = false;
    private Handler handler;

    private InventoryManager() {
        tagList = new HashMap<>();
        initHandler();
    }

    public static synchronized InventoryManager getInstance() {
        if (instance == null) {
            instance = new InventoryManager();
        }
        return instance;
    }

    private void initHandler() {
        handler = new Handler() {
            @Override
            public void handleMessage(Message msg) {
                String result = (String) msg.obj;
                String[] strs = result.split("@");
                if (strs.length == 2) {
                    String cleanEpc = strs[0].replace("EPC:", "").trim();
                    int idx = cleanEpc.indexOf('\n');
                    if (idx >= 0) cleanEpc = cleanEpc.substring(idx + 1).trim();
                    addEPCToList(cleanEpc, strs[1]);
                    Log.d(TAG, "✅ Tag added: " + cleanEpc);
                }
            }
        };
    }

    public boolean isStarted() {
        return isStart;
    }

    public boolean isEmptyTags() {
        return tagList == null || tagList.isEmpty();
    }

    public void clearData() {
        if (tagList != null) {
            tagList.clear();
        }
    }

    // ==================== INVENTORY OPERATIONS ====================

    public boolean start(boolean isSingleRead) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return false;
        
        if (!isStart) {
            if (isSingleRead) {
                UHFTAGInfo info = reader.inventorySingleTag();
                if (info != null) {
                    addEPCToList(info.getEPC(), info.getRssi());
                    return true;
                }
                return false;
            } else {
                if (reader.startInventoryTag()) {
                    isStart = true;
                    new TagThread().start();
                    return true;
                }
                return false;
            }
        }
        return true;
    }

    public boolean stop() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (isStart && reader != null) {
            isStart = false;
            return reader.stopInventory();
        }
        isStart = false;
        clearData();
        return false;
    }

    // ==================== SINGLE TAG READ ====================

    public synchronized String readSingleTagEPC() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "mReader is null");
            return "";
        }

        try {
            UHFTAGInfo info = reader.inventorySingleTag();
            if (info != null) {
                String epcHex = info.getEPC();
                Log.i(TAG, "Read single tag: EPC=" + epcHex);
                return epcHex;
            }
            return "";
        } catch (Exception e) {
            Log.e(TAG, "Exception in readSingleTagEPC: " + e.getMessage());
            return "";
        }
    }

    /**
     * Fallback inventory: resets the EPC+TID+USER mode (toggle off→on) to
     * recover from stuck reader state, then reads with the restored mode.
     */
    public synchronized String readSingleTagBasicJson() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return "";

        try {
            // Toggle combined mode OFF then ON (same as "reset" in demo app)
            try { reader.setEPCAndTIDMode(); } catch (Exception ignore) {}
            try { Thread.sleep(15); } catch (Exception ignore) {}
            try { reader.setEPCAndTIDUserMode(10, 64); } catch (Exception ignore) {}
            
            UHFTAGInfo info = reader.inventorySingleTag();
            if (info == null) return "";

            String epcHex = info.getEPC();
            if (epcHex == null || epcHex.isEmpty()) return "";

            String tid = info.getTid();
            String rssi = info.getRssi();
            boolean validTid = tid != null && !tid.isEmpty() && isTidValid(tid);
            String userMemory = info.getUser();
            if (userMemory == null) userMemory = "";
            
            Log.i(TAG, "RESET-READ: EPC=" + epcHex + 
                    (validTid ? " TID=" + tid.substring(0, Math.min(24, tid.length())) : "") +
                    " USER=" + (userMemory.length() / 4) + "w");

            return "{\"epc\":\"" + epcHex + "\",\"tid\":\"" + (tid != null ? tid : "") +
                    "\",\"rssi\":\"" + (rssi != null ? rssi : "") + 
                    "\",\"validTid\":" + validTid + 
                    ",\"userMemory\":\"" + userMemory + "\"}";
        } catch (Exception e) {
            Log.e(TAG, "Error in readSingleTagBasicJson: " + e.getMessage());
            try { reader.setEPCAndTIDUserMode(10, 64); } catch (Exception ignore) {}
            return "";
        }
    }

    private int metaReadAttempts = 0;
    private int metaReadSuccess = 0;
    
    public synchronized String readSingleTagMeta() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return "";
        
        try {
            metaReadAttempts++;
            UHFTAGInfo info = reader.inventorySingleTag();
            if (info == null) {
                // Log every 20th failure to avoid spam
                if (metaReadAttempts % 20 == 0) {
                    Log.d(TAG, "META-READ: " + metaReadAttempts + " attempts, " + metaReadSuccess + " success");
                }
                return "";
            }
            metaReadSuccess++;
            
            String epcHex = info.getEPC();
            String tid = normalizeTid(info.getTid());
            String rssi = info.getRssi();
            boolean validTid = isTidValid(tid);
            
            String userMemory = info.getUser();
            if (userMemory == null) userMemory = "";
            
            // NOTE: Don't do fallback read here - it blocks inventory and causes freezing
            // Enrichment will handle tags with missing user memory asynchronously
            
            // CRITICAL: Validate user memory - SDK sometimes returns TID as USER!
            // Valid ATA user memory starts with DSFID 0x1E00
            // TID typically starts with E2 (Impinj), E0 (NXP), E280, etc.
            if (userMemory.length() >= 4) {
                String userPrefix = userMemory.substring(0, 4).toUpperCase();
                boolean looksLikeTid = userPrefix.startsWith("E2") || 
                                       userPrefix.startsWith("E0") ||
                                       (tid != null && tid.length() >= 4 && 
                                        userPrefix.equalsIgnoreCase(tid.substring(0, 4)));
                boolean isValidDsfid = userPrefix.equals("1E00");
                
                if (looksLikeTid && !isValidDsfid) {
                    Log.w(TAG, "⚠️ TID returned as USER - ignoring: " + userPrefix + "...");
                    userMemory = ""; // Clear invalid user memory
                }
            }
            
            // Log what SDK actually returns - TID length varies by tag manufacturer
            int userWords = userMemory.length() / 4; // 4 hex chars = 1 word
            int tidLen = tid != null ? tid.length() : 0;
            String tidPreview;
            if (tid == null) {
                tidPreview = "null";
            } else if (tid.length() > 24) {
                // Show first 20 + separator + next portion for debugging uniqueness
                tidPreview = tid.substring(0, 20) + "|" + 
                    tid.substring(20, Math.min(tid.length(), 32)) + 
                    (tid.length() > 32 ? "..." : "");
            } else {
                tidPreview = tid;
            }
            // Show first 8 + last 4 chars of EPC to see differences between similar tags
            String epcPreview = epcHex.length() > 16 
                ? epcHex.substring(0, 8) + "..." + epcHex.substring(epcHex.length() - 4) 
                : epcHex;
            Log.i(TAG, "META-READ: EPC=" + epcPreview + 
                    " TID[" + tidLen + "c]=" + tidPreview +
                    " USER=" + userWords + "w");
            
            return "{\"epc\":\"" + epcHex + "\",\"tid\":\"" + (tid != null ? tid : "") +
                    "\",\"rssi\":\"" + rssi + "\",\"validTid\":" + validTid +
                    ",\"userMemory\":\"" + userMemory + "\"}";
        } catch (Exception e) {
            Log.e(TAG, "Error in readSingleTagMeta: " + e.getMessage());
            return "";
        }
    }

    public List<String> scanMultipleTags(int maxTags) {
        List<String> foundTags = new ArrayList<>();
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return foundTags;

        UHFManager.getInstance().clearFilter();

        try {
            if (reader.startInventoryTag()) {
                Thread.sleep(500);

                for (int i = 0; i < maxTags; i++) {
                    UHFTAGInfo info = reader.readTagFromBuffer();
                    if (info != null) {
                        String epcHex = info.getEPC();
                        if (epcHex != null && !epcHex.isEmpty() && !foundTags.contains(epcHex)) {
                            foundTags.add(epcHex);
                        }
                    } else {
                        break;
                    }
                }
                reader.stopInventory();
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in scanMultipleTags: " + e.getMessage());
            try { reader.stopInventory(); } catch (Exception ignored) {}
        }

        return foundTags;
    }

    // ==================== TAG LIST MANAGEMENT ====================

    private void addEPCToList(String epc, String rssi) {
        if (!TextUtils.isEmpty(epc)) {
            EPC tag = new EPC();
            tag.setId("");
            tag.setEpc(epc);
            tag.setCount("1");
            tag.setRssi(rssi);
            
            if (tagList.containsKey(epc)) {
                int oldCount = Integer.parseInt(Objects.requireNonNull(tagList.get(epc)).getCount());
                tag.setCount(String.valueOf(oldCount + 1));
            }
            tagList.put(epc, tag);
            
            notifyTagsChanged();
        }
    }

    private void notifyTagsChanged() {
        UHFListener listener = UHFManager.getInstance().getUhfListener();
        if (listener != null) {
            listener.onRead(getCurrentTagsJson());
        }
    }

    public String getCurrentTagsJson() {
        try {
            JSONArray arr = new JSONArray();
            if (tagList != null) {
                for (EPC t : tagList.values()) {
                    JSONObject j = new JSONObject();
                    j.put(TagKey.ID, t.getId());
                    j.put(TagKey.EPC, t.getEpc());
                    j.put(TagKey.RSSI, t.getRssi());
                    j.put(TagKey.COUNT, t.getCount());
                    arr.put(j);
                }
            }
            return arr.toString();
        } catch (JSONException e) {
            Log.e(TAG, "getCurrentTagsJson error", e);
            return "[]";
        }
    }

    // ==================== HELPERS ====================

    private boolean isTidValid(String tid) {
        // Accept TIDs of various lengths - different tags have different TID sizes
        // Minimum 12 chars (3 words) for basic manufacturer info
        if (tid == null || tid.length() < 12) return false;
        
        // Check for all-zeros patterns (invalid)
        return !tid.matches("^0+$");
    }

    private String normalizeTid(String tid) {
        // CRITICAL: Don't do additional TID reads here!
        // readData without filter can read TID from ANY tag in range,
        // causing EPC/TID mismatch in multi-tag environment.
        // 
        // Just use whatever TID came from inventorySingleTag().
        // The SDK's inventorySingleTag returns EPC+TID+USER together,
        // which should be from the same tag (mostly).
        
        if (tid != null && isTidValid(tid)) {
            return tid;
        }
        return tid; // Return as-is, even if invalid - let caller decide
    }

    // ==================== TAG THREAD ====================

    class TagThread extends Thread {
        @Override
        public void run() {
            RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
            while (isStart && reader != null) {
                UHFTAGInfo info = reader.readTagFromBuffer();
                if (info != null) {
                    String epcHex = info.getEPC();
                    String rssiStr = info.getRssi();
                    Message msg = handler.obtainMessage();
                    msg.obj = epcHex + "@" + rssiStr;
                    handler.sendMessage(msg);
                }
            }
        }
    }
}

