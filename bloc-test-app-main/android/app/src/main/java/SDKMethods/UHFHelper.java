package SDKMethods;

import android.content.Context;
import io.flutter.plugin.common.EventChannel;

import java.util.List;

import SDKMethods.core.UHFListener;
import SDKMethods.core.UHFManager;
import SDKMethods.inventory.InventoryManager;
import SDKMethods.location.LocationManager;
import SDKMethods.reader.MemoryReader;
import SDKMethods.writer.MemoryWriter;

/**
 * UHFHelper - Facade class that delegates to specialized managers
 * Maintains backward compatibility with existing code
 */
public class UHFHelper {
    private static UHFHelper instance;

    private UHFHelper() {}

    public static synchronized UHFHelper getInstance() {
        if (instance == null) {
            instance = new UHFHelper();
        }
        return instance;
    }

    // ==================== INITIALIZATION ====================

    public void init(Context context) {
        UHFManager.getInstance().init(context);
    }

    public void setUhfListener(UHFListener listener) {
        UHFManager.getInstance().setUhfListener(listener);
    }

    // ==================== CONNECTION ====================

    public boolean connect() {
        return UHFManager.getInstance().connect();
    }

    public void close() {
        InventoryManager.getInstance().stop();
        UHFManager.getInstance().close();
    }

    public boolean isConnected() {
        return UHFManager.getInstance().isConnected();
    }

    // ==================== INVENTORY ====================

    public boolean isStarted() {
        return InventoryManager.getInstance().isStarted();
    }

    public boolean isEmptyTags() {
        return InventoryManager.getInstance().isEmptyTags();
    }

    public void clearData() {
        InventoryManager.getInstance().clearData();
    }

    public boolean start(boolean isSingleRead) {
        return InventoryManager.getInstance().start(isSingleRead);
    }

    public boolean stop() {
        return InventoryManager.getInstance().stop();
    }

    public String readSingleTagEPC() {
        return InventoryManager.getInstance().readSingleTagEPC();
    }

    public String readSingleTagEPCWithRetry() {
        return InventoryManager.getInstance().readSingleTagEPC();
    }

    public String readSingleTagWithTid() {
        return InventoryManager.getInstance().readSingleTagMeta();
    }

    public String readSingleTagMeta() {
        return InventoryManager.getInstance().readSingleTagMeta();
    }

    public List<String> scanMultipleTags(int maxTags) {
        return InventoryManager.getInstance().scanMultipleTags(maxTags);
    }

    public String getCurrentTagsJson() {
        return InventoryManager.getInstance().getCurrentTagsJson();
    }

    // ==================== POWER & FREQUENCY ====================

    public boolean setPowerLevel(String level) {
        return UHFManager.getInstance().setPowerLevel(level);
    }

    public String getPowerLevel() {
        return UHFManager.getInstance().getPowerLevel();
    }

    public boolean setWorkArea(String area) {
        return UHFManager.getInstance().setWorkArea(area);
    }

    public String getFrequencyMode() {
        return UHFManager.getInstance().getFrequencyMode();
    }

    public String getTemperature() {
        return UHFManager.getInstance().getTemperature();
    }

    // ==================== BARCODE ====================

    public boolean connectBarcode() {
        return UHFManager.getInstance().connectBarcode();
    }

    public boolean scanBarcode() {
        return UHFManager.getInstance().scanBarcode();
    }

    public boolean stopScan() {
        return UHFManager.getInstance().stopScan();
    }

    public boolean closeScan() {
        return UHFManager.getInstance().closeScan();
    }

    public String readBarcode() {
        return UHFManager.getInstance().readBarcode();
    }

    public boolean playSound() {
        return UHFManager.getInstance().playSound();
    }

    // ==================== MEMORY READ ====================

    public String readUserMemory() {
        return MemoryReader.getInstance().readUserMemory();
    }

    public String readUserMemoryForEpcFull(String epcHex) {
        return MemoryReader.getInstance().readUserMemoryForEpcFull(epcHex);
    }

    public String readUserMemoryForTid(String tidHex) {
        return MemoryReader.getInstance().readUserMemoryForTid(tidHex);
    }

    public String readUserMemoryForEpcWithFilter(String epcHex) {
        return MemoryReader.getInstance().readUserMemoryForEpcWithFilter(epcHex);
    }

    public String readUserFieldsForEpc(String epcHex) {
        return MemoryReader.getInstance().readUserFieldsForEpc(epcHex);
    }

    public String diagnosticReadSingleTag() {
        return MemoryReader.getInstance().diagnosticReadSingleTag();
    }

    // ==================== MEMORY WRITE ====================

    public boolean prepareAtaChip(String recordType, int epcWords, int userWords,
            int permalockWords, boolean enablePermalock, boolean lockEpc,
            boolean lockUser, String accessPwdHex) {
        return MemoryWriter.getInstance().prepareAtaChip(recordType, epcWords, userWords,
                permalockWords, enablePermalock, lockEpc, lockUser, accessPwdHex);
    }

    public boolean writeTagADIConstruct2(String partNumber, String serialNumber) {
        return MemoryWriter.getInstance().writeTagADIConstruct2(partNumber, serialNumber);
    }

    public boolean programConstruct2Epc(String partNumber, String serialNumber,
            String manager6, String accessPwdHex, int filterValue) {
        return MemoryWriter.getInstance().programConstruct2Epc(partNumber, serialNumber,
                manager6, accessPwdHex, filterValue);
    }

    public boolean writeAtaUserMemoryWithPayload(String manufacturer, String productName,
            String partNumber, String serialNumber, String manufactureDate, String expireDate) {
        return MemoryWriter.getInstance().writeAtaUserMemoryWithPayload(manufacturer, productName,
                partNumber, serialNumber, manufactureDate, expireDate);
    }

    public boolean updateLifecycleRecord(String epcHex, String currentPartNumber,
            String partModLevel, String expirationDate, String certificateNumber,
            String lastOverhaulDate) {
        return MemoryWriter.getInstance().updateLifecycleRecord(epcHex, currentPartNumber,
                partModLevel, expirationDate, certificateNumber, lastOverhaulDate);
    }
    
    // ==================== MEMORY LOCKING ====================
    
    public boolean lockUserMemory(String accessPwdHex, boolean permanentLock) {
        return MemoryWriter.getInstance().lockUserMemory(accessPwdHex, permanentLock);
    }
    
    public boolean lockEpcMemory(String accessPwdHex, boolean permanentLock) {
        return MemoryWriter.getInstance().lockEpcMemory(accessPwdHex, permanentLock);
    }
    
    public boolean permalockUserBlocks(String accessPwdHex, int startWord, int wordCount) {
        return MemoryWriter.getInstance().permalockUserBlocks(accessPwdHex, startWord, wordCount);
    }

    // ==================== LOCATION ====================

    public static void setLocationSink(EventChannel.EventSink sink) {
        LocationManager.setLocationSink(sink);
    }

    public boolean startLocation(Context context, String label, int bank, int ptr) {
        return LocationManager.getInstance().startLocation(context, label, bank, ptr);
    }

    public boolean stopLocation() {
        return LocationManager.getInstance().stopLocation();
    }
}
