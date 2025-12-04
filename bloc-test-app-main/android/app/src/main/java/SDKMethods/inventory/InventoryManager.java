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

    public synchronized String readSingleTagMeta() {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) return "";
        
        try {
            UHFTAGInfo info = reader.inventorySingleTag();
            if (info == null) return "";
            
            String epcHex = info.getEPC();
            String tid = normalizeTid(info.getTid());
            String rssi = info.getRssi();
            boolean validTid = isTidValid(tid);
            
            String userMemory = info.getUser();
            if (userMemory == null) userMemory = "";
            
            Log.i(TAG, "META-READ: EPC=" + epcHex + ", TID=" + (tid != null ? tid.substring(0, Math.min(16, tid.length())) : "null"));
            
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
        return tid != null && !tid.isEmpty()
                && !tid.equals("000000000000000000000000")
                && !tid.equals("00000000000000000000000000000000");
    }

    private String normalizeTid(String tid) {
        if (isTidValid(tid)) return tid;
        
        try {
            RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
            if (reader != null) {
                String tidDirect = reader.readData("00000000", RFIDWithUHFUART.Bank_TID, 0, 6);
                if (isTidValid(tidDirect)) return tidDirect;
            }
        } catch (Exception e) {
            Log.w(TAG, "DIRECT-TID Failed: " + e.getMessage());
        }
        return tid;
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

