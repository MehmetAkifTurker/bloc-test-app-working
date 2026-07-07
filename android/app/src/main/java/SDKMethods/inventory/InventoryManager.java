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

import SDKMethods.core.EPC;
import SDKMethods.core.UHFManager;

/**
 * Inventory Manager - Handles tag scanning and inventory operations
 */
public class InventoryManager {
    private static final String TAG = "InventoryManager";
    
    private static InventoryManager instance;
    // ConcurrentHashMap: written from the main thread (handler / method channel)
    // and read by the background USER-fetch thread during scanning.
    private java.util.concurrent.ConcurrentHashMap<String, EPC> tagList;
    private volatile boolean isStart = false;
    private Handler handler;
    // Background USER completer (see startUserFetchThread): per-EPC attempt
    // counter so unreadable tags don't get hammered forever.
    private Thread userFetchThread;
    private final java.util.concurrent.ConcurrentHashMap<String, Integer> userFetchAttempts =
            new java.util.concurrent.ConcurrentHashMap<>();
    // Discovery-heat tracking: USER fetches pause the inventory, so they only
    // run when no NEW EPC has been seen for DISCOVERY_QUIET_MS (field is
    // "quiet"). While the operator sweeps new tags, discovery gets 100% of
    // the reader.
    private static final long DISCOVERY_QUIET_MS = 2000;
    private volatile long lastNewTagTime = 0;
    // Priority mode (user tapped "EPC only" in the count bar): fetch USER for
    // the tags already in the list NOW — skip the discovery-quiet wait and
    // re-try tags whose 3 attempts were already spent.
    private volatile boolean userFetchPriority = false;

    private InventoryManager() {
        tagList = new java.util.concurrent.ConcurrentHashMap<>();
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
                // Runs on the main thread; safe to mutate tagList here.
                if (msg.obj instanceof UHFTAGInfo) {
                    UHFTAGInfo info = (UHFTAGInfo) msg.obj;
                    addEPCToList(info.getEPC(), info.getTid(), info.getUser(), info.getRssi());
                }
            }
        };
    }

    public boolean isStarted() {
        return isStart;
    }

    /**
     * "EPC only" segment tapped: focus the reader on filling USER memory of
     * already-listed tags (no waiting for discovery to go quiet, spent
     * attempt counters reset so failed tags get retried). "Total" tapped:
     * back to normal discovery-first scanning.
     */
    public void setUserFetchPriority(boolean priority) {
        if (priority && !userFetchPriority) {
            userFetchAttempts.clear(); // give exhausted tags a fresh chance
        }
        userFetchPriority = priority;
        Log.i(TAG, "USER-fetch priority => " + (priority ? "ON" : "OFF"));
    }

    public boolean isEmptyTags() {
        return tagList == null || tagList.isEmpty();
    }

    public void clearData() {
        if (tagList != null) {
            tagList.clear();
        }
        userFetchAttempts.clear();
    }

    // ==================== INVENTORY OPERATIONS ====================

    public boolean start(boolean isSingleRead) {
        RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
        if (reader == null) {
            Log.e(TAG, "start(" + (isSingleRead ? "single" : "continuous")
                    + ") FAILED: reader is null (not connected yet?)");
            return false;
        }

        if (!isStart) {
            if (isSingleRead) {
                UHFTAGInfo info = reader.inventorySingleTag();
                if (info != null) {
                    addEPCToList(info.getEPC(), info.getTid(), info.getUser(), info.getRssi());
                    return true;
                }
                return false;
            } else {
                boolean ok = reader.startInventoryTag();
                Log.i(TAG, "startInventoryTag => " + (ok ? "OK" : "FAILED"));
                if (ok) {
                    isStart = true;
                    new TagThread().start();
                    userFetchAttempts.clear();
                    lastNewTagTime = System.currentTimeMillis(); // treat scan start as "hot"
                    startUserFetchThread();
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

    // ==================== BACKGROUND USER FETCH (during scanning) ====================

    /**
     * The combined EPC+TID+USER inventory mode does NOT deliver USER data on
     * this reader/tag combination (buffer entries always carry USER=0 words),
     * so USER used to be read only when the detail screen opened. This thread
     * fills USER memory IN THE BACKGROUND while continuous inventory runs:
     * it picks one tag at a time that has no USER yet and reads it with an
     * EPC-filtered chunked read (readUserMemoryForEpcFull pauses/resumes the
     * inventory internally), then stores the hex on the tag entry so the
     * Flutter poll picks it up. 3 attempts per tag so unreadable ones don't
     * loop forever.
     *
     * Each fetch stops the inventory for ~0.3-0.7s, so fetching while the
     * operator is still discovering tags collapses EPC throughput (measured:
     * 170 EPCs -> 61 in the same sweep). Fetches therefore wait until the
     * field is quiet (no new EPC for DISCOVERY_QUIET_MS); once quiet they run
     * back-to-back with only a short breather.
     */
    private void startUserFetchThread() {
        if (userFetchThread != null && userFetchThread.isAlive()) return;
        userFetchThread = new Thread(() -> {
            Log.i(TAG, "USER-fetch thread started");
            boolean loggedWaiting = false;
            while (isStart) {
                try {
                    long sinceNewTag = System.currentTimeMillis() - lastNewTagTime;
                    if (!userFetchPriority && sinceNewTag < DISCOVERY_QUIET_MS) {
                        // Discovery is hot: give the reader fully to the inventory.
                        if (!loggedWaiting) {
                            Log.i(TAG, "USER-fetch waiting (discovery hot)");
                            loggedWaiting = true;
                        }
                        Thread.sleep(100);
                        continue;
                    }
                    loggedWaiting = false;

                    EPC pending = null;
                    for (EPC t : tagList.values()) {
                        String u = t.getUser();
                        String epcKey = t.getEpc();
                        if ((u == null || u.isEmpty()) && epcKey != null && !epcKey.isEmpty()) {
                            Integer tries = userFetchAttempts.get(epcKey);
                            if (tries == null || tries < 3) {
                                pending = t;
                                break;
                            }
                        }
                    }
                    if (pending == null) {
                        Thread.sleep(500);
                        continue;
                    }

                    String epc = pending.getEpc();
                    Integer prev = userFetchAttempts.get(epc);
                    userFetchAttempts.put(epc, prev == null ? 1 : prev + 1);

                    String hex = SDKMethods.reader.MemoryReader.getInstance()
                            .readUserMemoryForEpcFull(epc);

                    if (!isStart) {
                        // User pressed Stop mid-fetch; the fetch restored the
                        // inventory it had paused — make sure it is stopped.
                        try {
                            RFIDWithUHFUART r = UHFManager.getInstance().getReader();
                            if (r != null) r.stopInventory();
                        } catch (Exception ignore) {
                        }
                        break;
                    }

                    if (hex != null && hex.length() >= 16) {
                        EPC cur = tagList.get(epc);
                        if (cur != null) cur.setUser(hex);
                        Log.i(TAG, "USER fetched: EPC="
                                + epc.substring(0, Math.min(16, epc.length()))
                                + "... words=" + (hex.length() / 4));
                    }
                    Thread.sleep(50); // field is quiet — short breather, fetch fast
                } catch (InterruptedException e) {
                    break;
                } catch (Exception e) {
                    Log.w(TAG, "USER-fetch error: " + e.getMessage());
                    try {
                        Thread.sleep(400);
                    } catch (InterruptedException ie) {
                        break;
                    }
                }
            }
            Log.i(TAG, "USER-fetch thread stopped");
        });
        userFetchThread.setName("UserFetchThread");
        userFetchThread.start();
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

    private void addEPCToList(String epc, String tid, String user, String rssi) {
        if (TextUtils.isEmpty(epc)) return;

        // Validate USER: the SDK occasionally returns the TID bytes in the USER field.
        // Valid ATA USER memory starts with DSFID 0x1E00; TIDs usually start E0/E2.
        if (user != null && user.length() >= 4) {
            String prefix = user.substring(0, 4).toUpperCase();
            boolean looksLikeTid = prefix.startsWith("E2") || prefix.startsWith("E0")
                    || (tid != null && tid.length() >= 4 && prefix.equalsIgnoreCase(tid.substring(0, 4)));
            if (looksLikeTid && !prefix.equals("1E00")) {
                user = ""; // drop bogus USER
            }
        }
        if (user == null) user = "";

        EPC existing = tagList.get(epc);
        EPC tag = existing != null ? existing : new EPC();
        tag.setId("");
        tag.setEpc(epc);
        tag.setRssi(rssi);

        // Keep the richest data seen across inventory cycles (a re-read may be empty).
        String bestTid = tag.getTid();
        if (isTidValid(tid)) bestTid = tid;          // a fresh valid TID always wins
        else if (bestTid == null) bestTid = tid;      // otherwise fill if we had none
        tag.setTid(bestTid);
        tag.setValidTid(isTidValid(bestTid));

        if (!user.isEmpty()) {
            // Log the first time USER data arrives for a tag (combined-mode capture).
            boolean hadUser = existing != null && existing.getUser() != null
                    && !existing.getUser().isEmpty();
            if (!hadUser) {
                Log.i(TAG, "USER captured: EPC=" + epc.substring(0, Math.min(16, epc.length()))
                        + "... words=" + (user.length() / 4));
            }
            tag.setUser(user);                        // else keep previously captured USER
        }

        int oldCount = 0;
        if (existing != null && existing.getCount() != null) {
            try { oldCount = Integer.parseInt(existing.getCount()); } catch (Exception ignore) {}
        }
        tag.setCount(String.valueOf(oldCount + 1));

        if (existing == null) {
            // New EPC: discovery is still hot — postpone USER fetching (see
            // startUserFetchThread). Re-reads of known tags don't count.
            lastNewTagTime = System.currentTimeMillis();
            // First sighting only (no per-read spam): confirms tags reach the native list.
            Log.i(TAG, "NEW TAG: EPC=" + epc + " USER=" + (user.length() / 4) + "w");
        }
        tagList.put(epc, tag);
        // NOTE: no per-tag push here — Flutter polls getCurrentTags() at UI rate,
        // decoupling the fast hardware buffer drain from UI updates (dense fields).
    }

    public String getCurrentTagsJson() {
        try {
            JSONArray arr = new JSONArray();
            if (tagList != null) {
                for (EPC t : tagList.values()) {
                    JSONObject j = new JSONObject();
                    // Same keys as readSingleTagMeta() so Flutter handles both uniformly.
                    j.put("epc", t.getEpc() != null ? t.getEpc() : "");
                    j.put("tid", t.getTid() != null ? t.getTid() : "");
                    j.put("rssi", t.getRssi() != null ? t.getRssi() : "");
                    j.put("validTid", t.isValidTid());
                    j.put("userMemory", t.getUser() != null ? t.getUser() : "");
                    j.put("count", t.getCount() != null ? t.getCount() : "1");
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
        // Use whatever TID came from inventorySingleTag() as-is (EPC+TID+USER come
        // from the same tag). We deliberately do NOT do an extra unfiltered TID read
        // here: that could read a different tag's TID in a multi-tag environment.
        // Validity is left for the caller to decide.
        return tid;
    }

    // ==================== TAG THREAD ====================

    class TagThread extends Thread {
        @Override
        public void run() {
            RFIDWithUHFUART reader = UHFManager.getInstance().getReader();
            while (isStart && reader != null) {
                UHFTAGInfo info = reader.readTagFromBuffer();
                if (info != null && info.getEPC() != null) {
                    // Pass the full tag (EPC + TID + USER + RSSI) to the main thread.
                    Message msg = handler.obtainMessage();
                    msg.obj = info;
                    handler.sendMessage(msg);
                } else {
                    // Buffer empty: brief pause to avoid busy-spinning the CPU.
                    try { Thread.sleep(5); } catch (InterruptedException e) { break; }
                }
            }
        }
    }
}

